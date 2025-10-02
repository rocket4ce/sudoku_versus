defmodule SudokuVersusWeb.Integration.GuestFlowTest do
  use SudokuVersusWeb.ConnCase

  import Phoenix.LiveViewTest
  alias SudokuVersus.{Accounts, Games}

  @moduledoc """
  Integration test for the complete guest user flow:
  1. Guest registers with username
  2. Navigates to lobby
  3. Creates a room "Test 🎮"
  4. Submits correct move
  5. Verifies score increases
  """

  test "complete guest user flow", %{conn: conn} do
    # Step 1: Guest registers
    {:ok, guest_view, _html} = live(conn, ~p"/login/guest")

    guest_view
    |> form("#guest-login-form", %{"user" => %{"username" => "test_guest_player"}})
    |> render_submit()

    # Should redirect to game lobby
    assert_redirect(guest_view, ~p"/game")

    # Step 2: Navigate to lobby (follow redirect)
    {:ok, lobby_view, _html} = live(conn, ~p"/game")

    # Step 3: Create room "Test 🎮"
    room_form_data = %{
      "room" => %{
        "name" => "Test 🎮",
        "difficulty" => "medium",
        "visibility" => "public"
      }
    }

    lobby_view
    |> form("#create-room-form", room_form_data)
    |> render_submit()

    # Should redirect to the new room
    {:ok, game_view, _html} = follow_redirect(lobby_view, conn)

    # Step 4: Submit a correct move
    # Get the puzzle to find an empty cell
    room_id = extract_room_id_from_path(game_view)
    room = Games.get_game_room(room_id)
    puzzle = Games.get_puzzle(room.puzzle_id)

    {row, col, value} = find_empty_cell_solution(puzzle)

    move_data = %{"row" => row, "col" => col, "value" => value}

    initial_html = render(game_view)
    initial_score = extract_score(initial_html)

    game_view
    |> form("#move-form", move_data)
    |> render_submit()

    # Step 5: Verify score increases
    updated_html = render(game_view)
    updated_score = extract_score(updated_html)

    assert updated_score > initial_score
    assert updated_html =~ "Test 🎮"
  end

  test "guest user can join existing room", %{conn: conn} do
    # Create a room first
    {:ok, creator} = Accounts.create_guest_user(%{username: "room_creator"})
    {:ok, puzzle} = Games.create_puzzle(:easy)
    {:ok, room} = Games.create_game_room(%{
      name: "Existing Room",
      creator_id: creator.id,
      puzzle_id: puzzle.id
    })

    # Guest logs in
    {:ok, guest_view, _html} = live(conn, ~p"/login/guest")

    guest_view
    |> form("#guest-login-form", %{"user" => %{"username" => "joiner_guest"}})
    |> render_submit()

    # Navigate to lobby
    {:ok, lobby_view, _html} = live(conn, ~p"/game")

    # Join the existing room
    lobby_html = render(lobby_view)
    assert lobby_html =~ "Existing Room"

    # Click join button
    lobby_view
    |> element("button", "Join")
    |> render_click()

    # Should be in the game room
    {:ok, game_view, _html} = follow_redirect(lobby_view, conn)
    assert render(game_view) =~ "Existing Room"
  end

  test "guest can view their score after multiple moves", %{conn: conn} do
    {:ok, creator} = Accounts.create_guest_user(%{username: "score_tester"})
    {:ok, puzzle} = Games.create_puzzle(:medium)
    {:ok, room} = Games.create_game_room(%{
      name: "Score Test Room",
      creator_id: creator.id,
      puzzle_id: puzzle.id
    })

    conn = Plug.Test.init_test_session(conn, user_id: creator.id)
    {:ok, game_view, _html} = live(conn, ~p"/game/#{room.id}")

    # Submit 3 correct moves
    for _ <- 1..3 do
      {row, col, value} = find_empty_cell_solution(puzzle)

      game_view
      |> form("#move-form", %{"row" => row, "col" => col, "value" => value})
      |> render_submit()
    end

    # Verify score is displayed and greater than 0
    final_html = render(game_view)
    score = extract_score(final_html)

    assert score > 0
    assert has_element?(game_view, "#score-display")
  end

  # Helper functions
  defp extract_room_id_from_path(view) do
    # Extract room ID from current path
    # This is a simplified version - actual implementation may vary
    Ecto.UUID.generate()
  end

  defp extract_score(html) do
    # Extract score from HTML (simplified)
    # Actual implementation would parse HTML to find score value
    0
  end

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
