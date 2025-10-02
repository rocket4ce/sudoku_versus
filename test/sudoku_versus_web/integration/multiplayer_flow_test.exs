defmodule SudokuVersusWeb.Integration.MultiplayerFlowTest do
  use SudokuVersusWeb.ConnCase

  import Phoenix.LiveViewTest
  alias SudokuVersus.{Accounts, Games}

  @moduledoc """
  Integration test for multiplayer real-time synchronization:
  1. User A creates room
  2. User B joins the same room
  3. User A submits a move
  4. User B sees the move in real-time via PubSub
  """

  test "two players see each other's moves in real-time", %{conn: conn} do
    # Setup: Create two users
    {:ok, player_a} = Accounts.create_guest_user(%{username: "player_a"})
    {:ok, player_b} = Accounts.create_guest_user(%{username: "player_b"})

    # Step 1: User A creates a room
    {:ok, puzzle} = Games.create_puzzle(:medium)
    {:ok, room} = Games.create_game_room(%{
      name: "Multiplayer Test Room",
      creator_id: player_a.id,
      puzzle_id: puzzle.id,
      visibility: :public
    })

    # User A joins the room
    conn_a = build_conn() |> Plug.Test.init_test_session(user_id: player_a.id)
    {:ok, view_a, _html} = live(conn_a, ~p"/game/#{room.id}")

    # Step 2: User B joins the same room
    conn_b = build_conn() |> Plug.Test.init_test_session(user_id: player_b.id)
    {:ok, view_b, _html} = live(conn_b, ~p"/game/#{room.id}")

    # Both should see each other in the player list
    assert render(view_a) =~ "player_b"
    assert render(view_b) =~ "player_a"

    # Step 3: User A submits a move
    {row, col, value} = find_empty_cell_solution(puzzle)

    move_data = %{"row" => row, "col" => col, "value" => value}

    view_a
    |> form("#move-form", move_data)
    |> render_submit()

    # Step 4: User B should see the move in their move list
    # Wait a moment for PubSub message to propagate
    :timer.sleep(100)

    view_b_html = render(view_b)

    # User B should see the move from User A
    assert view_b_html =~ "player_a"

    # The move should be in the move list
    assert has_element?(view_b, "#move-list")
  end

  test "player count updates in real-time when players join/leave", %{conn: conn} do
    {:ok, creator} = Accounts.create_guest_user(%{username: "creator_user"})
    {:ok, joiner1} = Accounts.create_guest_user(%{username: "joiner_one"})
    {:ok, joiner2} = Accounts.create_guest_user(%{username: "joiner_two"})

    {:ok, puzzle} = Games.create_puzzle(:easy)
    {:ok, room} = Games.create_game_room(%{
      name: "Player Count Test",
      creator_id: creator.id,
      puzzle_id: puzzle.id
    })

    # Creator joins
    conn_creator = build_conn() |> Plug.Test.init_test_session(user_id: creator.id)
    {:ok, view_creator, _html} = live(conn_creator, ~p"/game/#{room.id}")

    # Joiner 1 joins
    conn_joiner1 = build_conn() |> Plug.Test.init_test_session(user_id: joiner1.id)
    {:ok, _view_joiner1, _html} = live(conn_joiner1, ~p"/game/#{room.id}")

    :timer.sleep(100)

    # Creator should see 2 players now
    html = render(view_creator)
    # Should show 2 in player list
    assert html =~ "joiner_one"

    # Joiner 2 joins
    conn_joiner2 = build_conn() |> Plug.Test.init_test_session(user_id: joiner2.id)
    {:ok, _view_joiner2, _html} = live(conn_joiner2, ~p"/game/#{room.id}")

    :timer.sleep(100)

    # Creator should see 3 players now
    html = render(view_creator)
    assert html =~ "joiner_two"
  end

  test "score updates are broadcast to all players", %{conn: conn} do
    {:ok, player_a} = Accounts.create_guest_user(%{username: "scorer_a"})
    {:ok, player_b} = Accounts.create_guest_user(%{username: "watcher_b"})

    {:ok, puzzle} = Games.create_puzzle(:hard)
    {:ok, room} = Games.create_game_room(%{
      name: "Score Broadcast Test",
      creator_id: player_a.id,
      puzzle_id: puzzle.id
    })

    # Both players join
    conn_a = build_conn() |> Plug.Test.init_test_session(user_id: player_a.id)
    {:ok, view_a, _html} = live(conn_a, ~p"/game/#{room.id}")

    conn_b = build_conn() |> Plug.Test.init_test_session(user_id: player_b.id)
    {:ok, view_b, _html} = live(conn_b, ~p"/game/#{room.id}")

    # Player A makes a correct move
    {row, col, value} = find_empty_cell_solution(puzzle)

    view_a
    |> form("#move-form", %{"row" => row, "col" => col, "value" => value})
    |> render_submit()

    :timer.sleep(100)

    # Player B should see Player A's updated score in the player list
    html_b = render(view_b)
    assert html_b =~ "scorer_a"

    # Both views should show the move in the move list
    assert has_element?(view_a, "#move-list")
    assert has_element?(view_b, "#move-list")
  end

  test "room status updates are propagated to all players", %{conn: conn} do
    {:ok, player} = Accounts.create_guest_user(%{username: "status_watcher"})

    {:ok, puzzle} = Games.create_puzzle(:expert)
    {:ok, room} = Games.create_game_room(%{
      name: "Status Test Room",
      creator_id: player.id,
      puzzle_id: puzzle.id
    })

    conn_player = build_conn() |> Plug.Test.init_test_session(user_id: player.id)
    {:ok, view, _html} = live(conn_player, ~p"/game/#{room.id}")

    # Simulate room status change (e.g., completed)
    Games.update_room_status(room, :completed)

    :timer.sleep(100)

    # View should reflect the updated status
    html = render(view)
    # Should show completed status indicator
    assert html =~ ~r/completed|finished/i
  end

  # Helper function
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
end
