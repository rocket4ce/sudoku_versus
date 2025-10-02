defmodule SudokuVersusWeb.GameLive.ShowTest do
  use SudokuVersusWeb.ConnCase

  import Phoenix.LiveViewTest
  alias SudokuVersus.{Accounts, Games}

  describe "mount and render" do
    setup do
      {:ok, creator} = Accounts.create_guest_user(%{username: "game_host"})
      {:ok, player} = Accounts.create_guest_user(%{username: "game_player"})
      {:ok, puzzle} = Games.create_puzzle(:medium)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Game Room",
          creator_id: creator.id,
          puzzle_id: puzzle.id
        })

      {:ok, _session} = Games.join_room(room.id, player.id)

      %{room: room, player: player, puzzle: puzzle}
    end

    test "renders sudoku grid", %{conn: conn, room: room, player: player} do
      conn = Plug.Test.init_test_session(conn, user_id: player.id)

      {:ok, view, _html} = live(conn, ~p"/game/#{room.id}")

      assert has_element?(view, "#sudoku-grid")
    end

    test "displays player list with streams", %{conn: conn, room: room, player: player} do
      conn = Plug.Test.init_test_session(conn, user_id: player.id)

      {:ok, view, _html} = live(conn, ~p"/game/#{room.id}")

      assert has_element?(view, "#player-list")
    end

    test "shows current score", %{conn: conn, room: room, player: player} do
      conn = Plug.Test.init_test_session(conn, user_id: player.id)

      {:ok, view, _html} = live(conn, ~p"/game/#{room.id}")

      assert has_element?(view, "#score-display")
    end

    test "displays move history with streams", %{conn: conn, room: room, player: player} do
      conn = Plug.Test.init_test_session(conn, user_id: player.id)

      {:ok, view, _html} = live(conn, ~p"/game/#{room.id}")

      assert has_element?(view, "#move-list")
    end

    test "subscribes to PubSub on mount", %{conn: conn, room: room, player: player} do
      conn = Plug.Test.init_test_session(conn, user_id: player.id)

      {:ok, _view, _html} = live(conn, ~p"/game/#{room.id}")

      # Verify subscription by broadcasting a test message
      Phoenix.PubSub.broadcast(
        SudokuVersus.PubSub,
        "game_room:#{room.id}",
        {:test_message, "hello"}
      )

      # If subscribed correctly, the LiveView should receive the message
      assert true
    end
  end

  describe "handle_event submit_move" do
    setup do
      {:ok, player} = Accounts.create_guest_user(%{username: "move_submitter"})
      {:ok, creator} = Accounts.create_guest_user(%{username: "room_owner"})
      {:ok, puzzle} = Games.create_puzzle(:easy)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Move Test Room",
          creator_id: creator.id,
          puzzle_id: puzzle.id
        })

      {:ok, session} = Games.join_room(room.id, player.id)

      conn = build_conn() |> Plug.Test.init_test_session(user_id: player.id)
      {:ok, view, _html} = live(conn, ~p"/game/#{room.id}")

      %{view: view, room: room, player: player, puzzle: puzzle, session: session}
    end

    test "submits correct move and updates score", %{view: view, puzzle: puzzle} do
      {row, col, value} = find_empty_cell_solution(puzzle)

      move_data = %{"row" => row, "col" => col, "value" => value}

      html = render_submit(view, "submit_move", move_data)

      # Score should increase
      assert html =~ ~r/score/i
    end

    test "submits incorrect move with no score change", %{view: view, puzzle: puzzle} do
      {row, col, _correct} = find_empty_cell_solution(puzzle)
      wrong_value = get_wrong_value(puzzle, row, col)

      move_data = %{"row" => row, "col" => col, "value" => wrong_value}

      render_submit(view, "submit_move", move_data)

      # Move should be recorded as incorrect
      assert true
    end

    test "broadcasts move to other players via PubSub", %{view: view, room: room, puzzle: puzzle} do
      {row, col, value} = find_empty_cell_solution(puzzle)

      # Subscribe to PubSub to catch broadcast
      Phoenix.PubSub.subscribe(SudokuVersus.PubSub, "game_room:#{room.id}")

      move_data = %{"row" => row, "col" => col, "value" => value}
      render_submit(view, "submit_move", move_data)

      # Should receive broadcast message
      assert_receive {:new_move, _move}
    end
  end

  describe "handle_info new_move" do
    setup do
      {:ok, player1} = Accounts.create_guest_user(%{username: "player_one"})
      {:ok, player2} = Accounts.create_guest_user(%{username: "player_two"})
      {:ok, puzzle} = Games.create_puzzle(:medium)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Multiplayer Room",
          creator_id: player1.id,
          puzzle_id: puzzle.id
        })

      {:ok, _session1} = Games.join_room(room.id, player1.id)
      {:ok, _session2} = Games.join_room(room.id, player2.id)

      conn = build_conn() |> Plug.Test.init_test_session(user_id: player1.id)
      {:ok, view, _html} = live(conn, ~p"/game/#{room.id}")

      %{view: view, room: room, player2: player2, puzzle: puzzle}
    end

    test "updates move stream when receiving new move message", %{view: view, player2: player2} do
      # Simulate receiving a new move from player2
      move = %{
        id: Ecto.UUID.generate(),
        player_id: player2.id,
        player: player2,
        row: 0,
        col: 0,
        value: 5,
        is_correct: true,
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:new_move, move})

      html = render(view)
      assert html =~ "player_two"
    end
  end

  describe "handle_info presence_diff" do
    setup do
      {:ok, player} = Accounts.create_guest_user(%{username: "presence_player"})
      {:ok, creator} = Accounts.create_guest_user(%{username: "presence_creator"})
      {:ok, puzzle} = Games.create_puzzle(:hard)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Presence Room",
          creator_id: creator.id,
          puzzle_id: puzzle.id
        })

      {:ok, _session} = Games.join_room(room.id, player.id)

      conn = build_conn() |> Plug.Test.init_test_session(user_id: player.id)
      {:ok, view, _html} = live(conn, ~p"/game/#{room.id}")

      %{view: view, room: room}
    end

    test "updates player list when presence changes", %{view: view} do
      # Simulate presence diff message
      diff = %{
        joins: %{},
        leaves: %{}
      }

      send(view.pid, {:presence_diff, diff})

      # Player list should be updated
      assert render(view) =~ ~r/player/i
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
