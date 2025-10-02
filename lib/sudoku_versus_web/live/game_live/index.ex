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
      |> assign(:creating_room, false)
      |> assign(:form, to_form(changeset))
      |> stream(:rooms, rooms)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_room", %{"room" => room_params}, socket) do
    handle_event("create_room", %{"game_room" => room_params}, socket)
  end

  def handle_event("create_room", %{"game_room" => room_params}, socket) do
    # Set loading state
    socket = assign(socket, :creating_room, true)

    # Extract room parameters
    name = Map.get(room_params, "name", "New Room")
    difficulty = Map.get(room_params, "difficulty", "medium") |> String.to_existing_atom()
    size = Map.get(room_params, "grid_size", "9") |> String.to_integer()

    # Prepare attributes for room creation
    attrs = %{
      name: name,
      creator_id: socket.assigns.current_user_id,
      difficulty: difficulty,
      size: size,
      max_players: 100
    }

    # Use new create_room/1 which generates puzzle and creates room
    case Games.create_room(attrs) do
      {:ok, room} ->
        {:noreply,
         socket
         |> assign(:creating_room, false)
         |> put_flash(:info, "Room \"#{room.name}\" created successfully!")
         |> push_navigate(to: ~p"/game/#{room.id}")}

      {:error, reason} when is_binary(reason) ->
        {:noreply,
         socket
         |> assign(:creating_room, false)
         |> put_flash(:error, reason)
         |> assign(:form, to_form(GameRoom.changeset(%GameRoom{}, %{})))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:creating_room, false)
         |> assign(:form, to_form(changeset))}
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
end
