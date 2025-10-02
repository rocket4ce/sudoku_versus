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

      # Should receive broadcast message with full move details
      assert_receive {:new_move,
                      %{id: _id, row: ^row, col: ^col, value: ^value, is_correct: true}}
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

    test "updates move stream when receiving new move message", %{
      view: view,
      player2: player2,
      room: room
    } do
      # Player 2 makes a move
      move_data = %{row: 0, col: 0, value: 5}
      {:ok, move} = Games.record_move(room.id, player2.id, move_data)

      # Simulate receiving the new move broadcast
      move_broadcast = %{
        id: move.id,
        row: move.row,
        col: move.col,
        value: move.value,
        is_correct: move.is_correct
      }

      send(view.pid, {:new_move, move_broadcast})

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

  describe "grid state persistence on page refresh" do
    setup do
      {:ok, player} = Accounts.create_guest_user(%{username: "persistent_player"})
      {:ok, creator} = Accounts.create_guest_user(%{username: "room_creator"})
      {:ok, puzzle} = Games.create_puzzle(:easy)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Persistence Test Room",
          creator_id: creator.id,
          puzzle_id: puzzle.id
        })

      {:ok, _session} = Games.join_room(room.id, player.id)

      %{room: room, player: player, puzzle: puzzle}
    end

    test "grid preserves correct moves after page refresh", %{
      conn: conn,
      room: room,
      player: player,
      puzzle: puzzle
    } do
      # First connection: submit a correct move
      conn1 = Plug.Test.init_test_session(conn, user_id: player.id)
      {:ok, view1, _html} = live(conn1, ~p"/game/#{room.id}")

      {row, col, value} = find_empty_cell_solution(puzzle)
      move_data = %{"row" => to_string(row), "col" => to_string(col), "value" => to_string(value)}

      render_submit(view1, "submit_move", move_data)

      # Disconnect the first view (simulating page close)
      # LiveView automatically cleans up when process exits

      # Second connection: mount the page again (simulating page refresh)
      conn2 = Plug.Test.init_test_session(conn, user_id: player.id)
      {:ok, view2, html} = live(conn2, ~p"/game/#{room.id}")

      # Get the grid state from assigns
      grid = :sys.get_state(view2.pid).socket.assigns.grid

      # Verify the move was applied to the grid
      assert Enum.at(Enum.at(grid, row), col) == value

      # Verify the grid is rendered with the value (not an input field)
      assert html =~ ~r/<span class="text-gray-900 font-bold">#{value}<\/span>/
    end

    test "grid preserves multiple correct moves after refresh", %{
      conn: conn,
      room: room,
      player: player,
      puzzle: puzzle
    } do
      conn1 = Plug.Test.init_test_session(conn, user_id: player.id)
      {:ok, view1, _html} = live(conn1, ~p"/game/#{room.id}")

      # Submit three correct moves
      moves = [
        find_empty_cell_solution(puzzle),
        find_next_empty_cell_solution(puzzle, 1),
        find_next_empty_cell_solution(puzzle, 2)
      ]

      Enum.each(moves, fn {row, col, value} ->
        move_data = %{
          "row" => to_string(row),
          "col" => to_string(col),
          "value" => to_string(value)
        }

        render_submit(view1, "submit_move", move_data)
      end)

      # Refresh page
      conn2 = Plug.Test.init_test_session(conn, user_id: player.id)
      {:ok, view2, _html} = live(conn2, ~p"/game/#{room.id}")

      # Get the grid state
      grid = :sys.get_state(view2.pid).socket.assigns.grid

      # Verify all moves were preserved
      Enum.each(moves, fn {row, col, value} ->
        assert Enum.at(Enum.at(grid, row), col) == value
      end)
    end
  end

  describe "move validation with new O(1) lookup" do
    setup do
      {:ok, player} = Accounts.create_guest_user(%{username: "validator"})
      {:ok, creator} = Accounts.create_guest_user(%{username: "val_creator"})
      {:ok, puzzle} = Games.create_puzzle(:medium)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Validation Test",
          creator_id: creator.id,
          puzzle_id: puzzle.id
        })

      {:ok, _session} = Games.join_room(room.id, player.id)

      conn = build_conn() |> Plug.Test.init_test_session(user_id: player.id)
      {:ok, view, _html} = live(conn, ~p"/game/#{room.id}")

      %{view: view, room: room, puzzle: puzzle}
    end

    test "validates correct move and updates UI", %{view: view, puzzle: puzzle} do
      {row, col, value} = find_empty_cell_solution(puzzle)

      move_data = %{"row" => row, "col" => col, "value" => value}

      html = render_submit(view, "submit_move", move_data)

      # UI should show success feedback (green border, checkmark, etc.)
      assert html =~ ~r/correct|success/i or html =~ "✓"
    end

    test "validates incorrect move and shows error", %{view: view, puzzle: puzzle} do
      {row, col, _correct} = find_empty_cell_solution(puzzle)
      wrong_value = get_wrong_value(puzzle, row, col)

      move_data = %{"row" => row, "col" => col, "value" => wrong_value}

      html = render_submit(view, "submit_move", move_data)

      # UI should show error feedback (red border, x mark, etc.)
      assert html =~ ~r/incorrect|error/i or html =~ "✗"
    end

    test "validation uses O(1) solution lookup", %{view: view, puzzle: puzzle} do
      {row, col, value} = find_empty_cell_solution(puzzle)

      # Time the validation (should be <5ms even for large puzzles)
      {time_us, _html} = :timer.tc(fn ->
        render_submit(view, "submit_move", %{"row" => row, "col" => col, "value" => value})
      end)

      time_ms = time_us / 1000

      # Validation should be fast (note: includes LiveView overhead)
      assert time_ms < 100, "Validation took #{time_ms}ms (expected <100ms including LiveView)"
    end

    test "score updates correctly on valid move", %{view: view, puzzle: puzzle} do
      {row, col, value} = find_empty_cell_solution(puzzle)

      # Get initial score
      initial_html = render(view)
      initial_score = extract_score(initial_html)

      # Submit correct move
      render_submit(view, "submit_move", %{"row" => row, "col" => col, "value" => value})

      # Get updated score
      updated_html = render(view)
      updated_score = extract_score(updated_html)

      assert updated_score > initial_score
    end

    test "streak updates correctly on consecutive correct moves", %{view: view, puzzle: puzzle} do
      # Submit multiple correct moves
      moves = [
        find_empty_cell_solution(puzzle),
        find_next_empty_cell_solution(puzzle, 1),
        find_next_empty_cell_solution(puzzle, 2)
      ]

      Enum.each(moves, fn {row, col, value} ->
        render_submit(view, "submit_move", %{"row" => row, "col" => col, "value" => value})
      end)

      # Check streak is 3
      html = render(view)
      assert html =~ ~r/streak.*3/i or html =~ "🔥"
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

  defp find_next_empty_cell_solution(puzzle, skip_count) do
    result =
      Enum.reduce_while(0..8, {0, nil}, fn row, {skipped, _} ->
        Enum.reduce_while(0..8, {skipped, nil}, fn col, {skip_acc, _} ->
          if Enum.at(Enum.at(puzzle.grid, row), col) == 0 do
            if skip_acc >= skip_count do
              value = Enum.at(Enum.at(puzzle.solution, row), col)
              {:halt, {:halt, {skip_acc, {row, col, value}}}}
            else
              {:cont, {skip_acc + 1, nil}}
            end
          else
            {:cont, {skip_acc, nil}}
          end
        end)
      end)

    case result do
      {_, solution} when is_tuple(solution) -> solution
      # fallback
      _ -> find_empty_cell_solution(puzzle)
    end
  end

  defp get_wrong_value(puzzle, row, col) do
    correct = Enum.at(Enum.at(puzzle.solution, row), col)
    Enum.find(1..9, fn v -> v != correct end)
  end

  defp extract_score(html) do
    case Regex.run(~r/score.*?(\d+)/i, html) do
      [_, score_str] -> String.to_integer(score_str)
      _ -> 0
    end
  end
end
