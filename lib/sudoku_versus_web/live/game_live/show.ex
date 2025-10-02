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
        {:ok, _} =
          Presence.track(self(), "game_room:#{room_id}", user_id, %{
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

      # Reconstruct current grid state by applying all correct moves
      current_grid = apply_moves_to_grid(room.puzzle.grid, moves)

      socket =
        socket
        |> assign(:page_title, room.name)
        |> assign(:room, room)
        |> assign(:room_id, room_id)
        |> assign(:current_user_id, user_id)
        |> assign(:session, session_record)
        |> assign(:puzzle, room.puzzle)
        |> assign(:grid, current_grid)
        |> assign(:players_online_count, map_size(presences))
        |> assign(:moves_count, length(moves))
        |> assign(:elapsed_seconds, calculate_elapsed_seconds(room))
        |> assign(:penalty_until, nil)
        |> assign(:penalty_remaining, 0)
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
    # Check if player is currently penalized
    if penalty_active?(socket) do
      remaining = socket.assigns.penalty_remaining

      {:noreply,
       put_flash(
         socket,
         :error,
         "Penalty active! Wait #{remaining} seconds before submitting again."
       )}
    else
      move_attrs = %{
        row: String.to_integer(row),
        col: String.to_integer(col),
        value: String.to_integer(value)
      }

      case Games.record_move(socket.assigns.room_id, socket.assigns.current_user_id, move_attrs) do
        {:ok, move} ->
          # Broadcast move to all players in room with full details
          Phoenix.PubSub.broadcast(
            SudokuVersus.PubSub,
            "game_room:#{socket.assigns.room_id}",
            {:new_move,
             %{
               id: move.id,
               row: move.row,
               col: move.col,
               value: move.value,
               is_correct: move.is_correct
             }}
          )

          # Update local session
          updated_session =
            Games.get_player_session(socket.assigns.room_id, socket.assigns.current_user_id)

          socket =
            socket
            |> assign(:session, updated_session)
            |> assign(:moves_count, socket.assigns.moves_count + 1)
            |> stream_insert(:moves, move, at: 0)

          # Update grid if move was correct
          socket =
            if move.is_correct do
              socket
              |> assign(:grid, update_grid(socket.assigns.grid, move.row, move.col, move.value))
              |> put_flash(:info, "Correct! +#{move.points_earned} points")
            else
              apply_penalty(socket)
            end

          {:noreply, socket}

        {:error, :session_not_found} ->
          {:noreply, put_flash(socket, :error, "Session not found. Please rejoin the room.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
      end
    end
  end

  @impl true
  def handle_info({:new_move, move_data}, socket) do
    # Another player made a move, fetch and add to stream (with player preloaded)
    moves = Games.get_room_moves(socket.assigns.room_id, limit: 1)

    case moves do
      [move] when move.id == move_data.id ->
        socket =
          socket
          |> assign(:moves_count, socket.assigns.moves_count + 1)
          |> stream_insert(:moves, move, at: 0)

        # Update grid if move was correct
        socket =
          if move_data.is_correct do
            assign(
              socket,
              :grid,
              update_grid(socket.assigns.grid, move_data.row, move_data.col, move_data.value)
            )
          else
            socket
          end

        {:noreply, socket}

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

  @impl true
  def handle_info(:penalty_tick, socket) do
    if penalty_active?(socket) do
      remaining = DateTime.diff(socket.assigns.penalty_until, DateTime.utc_now(), :second)

      if remaining > 0 do
        # Schedule next tick
        Process.send_after(self(), :penalty_tick, 1000)
        {:noreply, assign(socket, :penalty_remaining, remaining)}
      else
        # Penalty expired - clear the penalty state
        {:noreply,
         socket
         |> assign(:penalty_until, nil)
         |> assign(:penalty_remaining, 0)
         |> clear_flash()}
      end
    else
      {:noreply, socket}
    end
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
        # Session already has player preloaded from get_player_session
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

  defp penalty_active?(socket) do
    case socket.assigns.penalty_until do
      nil -> false
      penalty_until -> DateTime.compare(DateTime.utc_now(), penalty_until) == :lt
    end
  end

  defp apply_penalty(socket) do
    penalty_until = DateTime.add(DateTime.utc_now(), 10, :second)

    # Schedule countdown ticks
    Process.send_after(self(), :penalty_tick, 1000)

    socket
    |> assign(:penalty_until, penalty_until)
    |> assign(:penalty_remaining, 10)
    |> put_flash(:error, "Incorrect move! Wait 10 seconds before trying again.")
  end

  defp update_grid(grid, row, col, value) do
    # Update the grid immutably at the given row and column
    List.update_at(grid, row, fn row_list ->
      List.update_at(row_list, col, fn _ -> value end)
    end)
  end

  defp apply_moves_to_grid(grid, moves) do
    # Apply all correct moves to the grid to reconstruct current state
    # Moves are ordered by inserted_at DESC, so we need to reverse to apply oldest first
    moves
    |> Enum.reverse()
    |> Enum.filter(& &1.is_correct)
    |> Enum.reduce(grid, fn move, acc_grid ->
      update_grid(acc_grid, move.row, move.col, move.value)
    end)
  end
end
