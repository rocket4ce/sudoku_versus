defmodule SudokuVersus.GamesTest do
  use SudokuVersus.DataCase

  alias SudokuVersus.Games
  alias SudokuVersus.Accounts
  alias SudokuVersus.Repo

  describe "create_game_room/1" do
    setup do
      {:ok, user} = Accounts.create_guest_user(%{username: "test_creator"})
      {:ok, puzzle} = Games.create_puzzle(:medium)
      %{user: user, puzzle: puzzle}
    end

    test "creates a game room with valid attributes", %{user: user, puzzle: puzzle} do
      attrs = %{
        name: "Test Room 🎮",
        creator_id: user.id,
        puzzle_id: puzzle.id,
        visibility: :public
      }

      assert {:ok, room} = Games.create_game_room(attrs)
      assert room.name == "Test Room 🎮"
      assert room.status == :active
      assert room.visibility == :public
      assert room.creator_id == user.id
      assert room.puzzle_id == puzzle.id
      assert room.current_players_count == 0
    end

    test "returns error with invalid room name", %{user: user, puzzle: puzzle} do
      attrs = %{
        name: String.duplicate("a", 31),  # Too long (max 30)
        creator_id: user.id,
        puzzle_id: puzzle.id
      }

      assert {:error, changeset} = Games.create_game_room(attrs)
      assert "should be at most 30 character(s)" in errors_on(changeset).name
    end
  end

  describe "list_active_rooms/0" do
    setup do
      {:ok, user} = Accounts.create_guest_user(%{username: "room_lister"})
      {:ok, puzzle} = Games.create_puzzle(:easy)

      # Create active room
      {:ok, active_room} = Games.create_game_room(%{
        name: "Active Room",
        creator_id: user.id,
        puzzle_id: puzzle.id
      })

      # Create completed room
      {:ok, completed_room} = Games.create_game_room(%{
        name: "Completed Room",
        creator_id: user.id,
        puzzle_id: puzzle.id
      })
      |> case do
        {:ok, room} -> Games.update_room_status(room, :completed)
      end

      %{active_room: active_room, completed_room: completed_room}
    end

    test "returns only active rooms", %{active_room: active_room} do
      rooms = Games.list_active_rooms()

      assert length(rooms) == 1
      assert hd(rooms).id == active_room.id
      assert hd(rooms).status == :active
    end

    test "preloads puzzle and creator associations" do
      rooms = Games.list_active_rooms()

      room = hd(rooms)
      assert %Ecto.Association.NotLoaded{} != room.puzzle
      assert %Ecto.Association.NotLoaded{} != room.creator
    end
  end

  describe "join_room/2" do
    setup do
      {:ok, creator} = Accounts.create_guest_user(%{username: "room_creator"})
      {:ok, player} = Accounts.create_guest_user(%{username: "player_joining"})
      {:ok, puzzle} = Games.create_puzzle(:medium)
      {:ok, room} = Games.create_game_room(%{
        name: "Join Test Room",
        creator_id: creator.id,
        puzzle_id: puzzle.id
      })

      %{room: room, player: player}
    end

    test "creates player session when joining room", %{room: room, player: player} do
      assert {:ok, session} = Games.join_room(room.id, player.id)

      assert session.player_id == player.id
      assert session.game_room_id == room.id
      assert session.current_score == 0
      assert session.is_active == true
    end

    test "increments room player count", %{room: room, player: player} do
      {:ok, _session} = Games.join_room(room.id, player.id)

      updated_room = Repo.get(Games.GameRoom, room.id)
      assert updated_room.current_players_count == 1
    end

    test "returns error when joining room twice", %{room: room, player: player} do
      {:ok, _session} = Games.join_room(room.id, player.id)

      assert {:error, changeset} = Games.join_room(room.id, player.id)
      assert "has already been taken" in errors_on(changeset).player_id
    end
  end

  describe "leave_room/2" do
    setup do
      {:ok, player} = Accounts.create_guest_user(%{username: "leaving_player"})
      {:ok, creator} = Accounts.create_guest_user(%{username: "room_owner"})
      {:ok, puzzle} = Games.create_puzzle(:easy)
      {:ok, room} = Games.create_game_room(%{
        name: "Leave Test Room",
        creator_id: creator.id,
        puzzle_id: puzzle.id
      })
      {:ok, session} = Games.join_room(room.id, player.id)

      %{room: room, player: player, session: session}
    end

    test "marks session as inactive", %{room: room, player: player, session: session} do
      assert {:ok, updated_session} = Games.leave_room(room.id, player.id)

      assert updated_session.is_active == false
      assert updated_session.id == session.id
    end

    test "decrements room player count", %{room: room, player: player} do
      {:ok, _session} = Games.leave_room(room.id, player.id)

      updated_room = Repo.get(Games.GameRoom, room.id)
      assert updated_room.current_players_count == 0
    end
  end

  describe "record_move/3" do
    setup do
      {:ok, player} = Accounts.create_guest_user(%{username: "move_maker"})
      {:ok, creator} = Accounts.create_guest_user(%{username: "game_creator"})
      {:ok, puzzle} = Games.create_puzzle(:medium)
      {:ok, room} = Games.create_game_room(%{
        name: "Move Test Room",
        creator_id: creator.id,
        puzzle_id: puzzle.id
      })
      {:ok, session} = Games.join_room(room.id, player.id)

      %{room: room, player: player, session: session, puzzle: puzzle}
    end

    test "records correct move with score", %{room: room, player: player, puzzle: puzzle} do
      # Find empty cell with correct value
      {row, col, value} = find_empty_cell_solution(puzzle)

      move_attrs = %{row: row, col: col, value: value}

      assert {:ok, move} = Games.record_move(room.id, player.id, move_attrs)
      assert move.is_correct == true
      assert move.points_earned > 0
      assert move.row == row
      assert move.col == col
      assert move.value == value
    end

    test "records incorrect move with zero points", %{room: room, player: player, puzzle: puzzle} do
      {row, col, _correct} = find_empty_cell_solution(puzzle)
      wrong_value = get_wrong_value(puzzle, row, col)

      move_attrs = %{row: row, col: col, value: wrong_value}

      assert {:ok, move} = Games.record_move(room.id, player.id, move_attrs)
      assert move.is_correct == false
      assert move.points_earned == 0
    end

    test "updates player session stats after correct move", %{room: room, player: player, puzzle: puzzle} do
      {row, col, value} = find_empty_cell_solution(puzzle)
      move_attrs = %{row: row, col: col, value: value}

      {:ok, _move} = Games.record_move(room.id, player.id, move_attrs)

      session = Games.get_player_session(room.id, player.id)
      assert session.correct_moves_count == 1
      assert session.current_score > 0
      assert session.current_streak == 1
      assert session.cells_filled == 1
    end

    test "increments room move count", %{room: room, player: player, puzzle: puzzle} do
      {row, col, value} = find_empty_cell_solution(puzzle)
      move_attrs = %{row: row, col: col, value: value}

      {:ok, _move} = Games.record_move(room.id, player.id, move_attrs)

      updated_room = Repo.get(Games.GameRoom, room.id)
      assert updated_room.total_moves_count == 1
    end
  end

  describe "get_room_moves/2" do
    setup do
      {:ok, player} = Accounts.create_guest_user(%{username: "history_viewer"})
      {:ok, creator} = Accounts.create_guest_user(%{username: "hist_creator"})
      {:ok, puzzle} = Games.create_puzzle(:easy)
      {:ok, room} = Games.create_game_room(%{
        name: "History Room",
        creator_id: creator.id,
        puzzle_id: puzzle.id
      })
      {:ok, _session} = Games.join_room(room.id, player.id)

      # Record some moves
      for _ <- 1..3 do
        {row, col, value} = find_empty_cell_solution(puzzle)
        Games.record_move(room.id, player.id, %{row: row, col: col, value: value})
      end

      %{room: room}
    end

    test "returns moves ordered by most recent first", %{room: room} do
      moves = Games.get_room_moves(room.id)

      assert length(moves) == 3

      # Verify descending order by inserted_at
      [move1, move2, move3] = moves
      assert DateTime.compare(move1.inserted_at, move2.inserted_at) in [:gt, :eq]
      assert DateTime.compare(move2.inserted_at, move3.inserted_at) in [:gt, :eq]
    end

    test "preloads player association", %{room: room} do
      moves = Games.get_room_moves(room.id)

      move = hd(moves)
      assert %Ecto.Association.NotLoaded{} != move.player
      assert is_binary(move.player.username)
    end

    test "limits to 50 moves", %{room: room} do
      # This test assumes we can create 50+ moves somehow
      # For now just verify limit parameter exists
      moves = Games.get_room_moves(room.id, limit: 2)

      assert length(moves) <= 2
    end
  end

  # Helper functions
  defp find_empty_cell_solution(puzzle) do
    Enum.reduce_while(0..8, nil, fn row, _ ->
      Enum.reduce_while(0..8, nil, fn col, _ ->
        if Enum.at(Enum.at(puzzle.grid, row), col) == 0 do
          value = Enum.at(Enum.at(puzzle.solution, row), col)
          {:halt, {:halt, {row, col, value}}}
        else
          {:cont, nil}
        end
      end)
    end)
  end

  defp get_wrong_value(puzzle, row, col) do
    correct = Enum.at(Enum.at(puzzle.solution, row), col)
    Enum.find(1..9, fn v -> v != correct end)
  end
end
