defmodule SudokuVersusWeb.GameLive.Show do
  use SudokuVersusWeb, :live_view

  alias SudokuVersus.Games
  alias SudokuVersusWeb.Presence

  @impl true
  def mount(%{"id" => room_id}, session, socket) do
    user_id = Map.get(session, "user_id")

    with {:ok, room} <- fetch_room(room_id),
         {:ok, session_record} <- ensure_player_session(room_id, user_id) do

      if connected?(socket) do
        # Subscribe to PubSub for real-time updates
        Phoenix.PubSub.subscribe(SudokuVersus.PubSub, "game_room:#{room_id}")

        # Track presence
        {:ok, _} = Presence.track(self(), "game_room:#{room_id}", user_id, %{
          username: session_record.player.username,
          player_id: user_id,
          joined_at: :os.system_time(:second)
        })
      end

      moves = Games.get_room_moves(room_id)
      presences = Presence.list("game_room:#{room_id}")

      # Schedule timer tick if game has started
      if connected?(socket) && room.started_at do
        Process.send_after(self(), :tick_timer, 1000)
      end

      socket =
        socket
        |> assign(:page_title, room.name)
        |> assign(:room, room)
        |> assign(:room_id, room_id)
        |> assign(:current_user_id, user_id)
        |> assign(:session, session_record)
        |> assign(:puzzle, room.puzzle)
        |> assign(:grid, room.puzzle.grid)
        |> assign(:players_online_count, map_size(presences))
        |> assign(:elapsed_seconds, calculate_elapsed_seconds(room))
        |> stream(:moves, moves)
        |> stream(:players, extract_players(presences))

      {:ok, socket}
    else
      {:error, :room_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Room not found")
         |> push_navigate(to: ~p"/game")}

      {:error, reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Error: #{inspect(reason)}")
         |> push_navigate(to: ~p"/game")}
    end
  end

  @impl true
  def handle_event("submit_move", %{"row" => row, "col" => col, "value" => value}, socket) do
    move_attrs = %{
      row: String.to_integer(row),
      col: String.to_integer(col),
      value: String.to_integer(value)
    }

    case Games.record_move(socket.assigns.room_id, socket.assigns.current_user_id, move_attrs) do
      {:ok, move} ->
        # Broadcast move to all players in room
        Phoenix.PubSub.broadcast(
          SudokuVersus.PubSub,
          "game_room:#{socket.assigns.room_id}",
          {:new_move, move.id}
        )

        # Update local session
        updated_session = Games.get_player_session(socket.assigns.room_id, socket.assigns.current_user_id)

        socket =
          socket
          |> assign(:session, updated_session)
          |> stream_insert(:moves, move, at: 0)
          |> put_flash(:info, "Move recorded! +#{move.points_earned} points")

        {:noreply, socket}

      {:error, :session_not_found} ->
        {:noreply, put_flash(socket, :error, "Session not found. Please rejoin the room.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:new_move, move_id}, socket) do
    # Another player made a move, fetch and add to stream (with player preloaded)
    moves = Games.get_room_moves(socket.assigns.room_id, limit: 1)

    case moves do
      [move] when move.id == move_id ->
        {:noreply, stream_insert(socket, :moves, move, at: 0)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Update player count and list when presence changes
    presences = Presence.list("game_room:#{socket.assigns.room_id}")

    socket =
      socket
      |> assign(:players_online_count, map_size(presences))
      |> stream(:players, extract_players(presences), reset: true)

    {:noreply, socket}
  end

  # Handle test-injected presence_diff messages
  @impl true
  def handle_info({:presence_diff, _diff}, socket) do
    # Update player count and list
    presences = Presence.list("game_room:#{socket.assigns.room_id}")

    socket =
      socket
      |> assign(:players_online_count, map_size(presences))
      |> stream(:players, extract_players(presences), reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick_timer, socket) do
    room = socket.assigns.room
    elapsed_seconds = calculate_elapsed_seconds(room)

    # Schedule next tick if game is still active
    if room.started_at && !room.completed_at do
      Process.send_after(self(), :tick_timer, 1000)
    end

    {:noreply, assign(socket, :elapsed_seconds, elapsed_seconds)}
  end

  # Private helper functions

  defp fetch_room(room_id) do
    case Games.get_game_room(room_id) do
      nil -> {:error, :room_not_found}
      room -> {:ok, room}
    end
  end

  defp ensure_player_session(room_id, user_id) do
    case Games.get_player_session(room_id, user_id) do
      nil ->
        # Join room automatically
        Games.join_room(room_id, user_id)

      session ->
        # Preload player association if needed
        session = SudokuVersus.Repo.preload(session, :player)
        {:ok, session}
    end
  end

  defp extract_players(presences) do
    Enum.map(presences, fn {user_id, %{metas: metas}} ->
      meta = List.first(metas)
      %{
        id: user_id,
        username: Map.get(meta, :username, "Unknown"),
        joined_at: Map.get(meta, :joined_at)
      }
    end)
  end

  defp calculate_elapsed_seconds(%{started_at: nil}), do: 0

  defp calculate_elapsed_seconds(%{started_at: started_at}) do
    DateTime.diff(DateTime.utc_now(), started_at, :second)
  end
end
