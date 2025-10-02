defmodule SudokuVersusWeb.GameLive.Index do
  use SudokuVersusWeb, :live_view

  alias SudokuVersus.Games
  alias SudokuVersus.Games.GameRoom

  @impl true
  def mount(_params, session, socket) do
    user_id = Map.get(session, "user_id")

    if connected?(socket) do
      # Subscribe to game room updates if needed
      Phoenix.PubSub.subscribe(SudokuVersus.PubSub, "game_rooms")
    end

    rooms = Games.list_active_rooms()
    changeset = GameRoom.changeset(%GameRoom{}, %{})

    socket =
      socket
      |> assign(:page_title, "Game Lobby")
      |> assign(:current_user_id, user_id)
      |> assign(:filter_difficulty, nil)
      |> assign(:rooms_count, length(rooms))
      |> assign(:form, to_form(changeset))
      |> stream(:rooms, rooms)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_room", %{"room" => room_params}, socket) do
    # Add required fields
    attrs =
      room_params
      |> Map.put("creator_id", socket.assigns.current_user_id)
      |> Map.put("visibility", Map.get(room_params, "visibility", "public"))
      |> ensure_puzzle_id()

    case Games.create_game_room(attrs) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room \"#{room.name}\" created successfully!")
         |> push_navigate(to: ~p"/game/#{room.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("filter", %{"difficulty" => difficulty}, socket) do
    filter = if difficulty == "", do: nil, else: String.to_existing_atom(difficulty)

    rooms =
      if filter do
        Games.list_active_rooms()
        |> Enum.filter(fn room -> room.puzzle.difficulty == filter end)
      else
        Games.list_active_rooms()
      end

    socket =
      socket
      |> assign(:filter_difficulty, filter)
      |> assign(:rooms_count, length(rooms))
      |> stream(:rooms, rooms, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:room_created, room}, socket) do
    # Add new room to stream
    socket =
      socket
      |> update(:rooms_count, &(&1 + 1))
      |> stream_insert(:rooms, room, at: 0)

    {:noreply, socket}
  end

  # Helper functions

  defp ensure_puzzle_id(attrs) do
    case Map.get(attrs, "puzzle_id") do
      nil ->
        # Create a puzzle if not provided
        difficulty = Map.get(attrs, "difficulty", "medium") |> String.to_existing_atom()
        {:ok, puzzle} = Games.create_puzzle(difficulty)
        Map.put(attrs, "puzzle_id", puzzle.id)

      _ ->
        attrs
    end
  end
end
