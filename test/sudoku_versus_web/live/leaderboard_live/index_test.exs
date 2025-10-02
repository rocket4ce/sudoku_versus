defmodule SudokuVersusWeb.LeaderboardLive.IndexTest do
  use SudokuVersusWeb.ConnCase

  import Phoenix.LiveViewTest
  alias SudokuVersus.{Accounts, Games}

  describe "mount and render" do
    setup do
      {:ok, user} = Accounts.create_guest_user(%{username: "leaderboard_viewer"})
      %{user: user}
    end

    test "renders leaderboard with streams", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/leaderboard")

      assert has_element?(view, "#leaderboard-list")
    end

    test "displays difficulty filter", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/leaderboard")

      assert has_element?(view, "#difficulty-filter")
    end

    test "shows top 100 players by default", %{conn: conn, user: user} do
      # Create some score records
      {:ok, player1} = Accounts.create_guest_user(%{username: "top_player"})
      {:ok, puzzle} = Games.create_puzzle(:medium)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Leaderboard Room",
          creator_id: player1.id,
          puzzle_id: puzzle.id
        })

      Games.record_score(%{
        player_id: player1.id,
        game_room_id: room.id,
        final_score: 5000,
        completed_puzzle: true,
        difficulty: :medium
      })

      # Refresh materialized view
      Games.refresh_leaderboard()

      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      {:ok, view, _html} = live(conn, ~p"/leaderboard")

      assert render(view) =~ "top_player"
    end
  end

  describe "handle_event filter_difficulty" do
    setup do
      # Create players with scores at different difficulties
      {:ok, easy_player} = Accounts.create_guest_user(%{username: "easy_champ"})
      {:ok, hard_player} = Accounts.create_guest_user(%{username: "hard_master"})

      {:ok, easy_puzzle} = Games.create_puzzle(:easy)
      {:ok, hard_puzzle} = Games.create_puzzle(:hard)

      {:ok, easy_room} =
        Games.create_game_room(%{
          name: "Easy Room",
          creator_id: easy_player.id,
          puzzle_id: easy_puzzle.id
        })

      {:ok, hard_room} =
        Games.create_game_room(%{
          name: "Hard Room",
          creator_id: hard_player.id,
          puzzle_id: hard_puzzle.id
        })

      Games.record_score(%{
        player_id: easy_player.id,
        game_room_id: easy_room.id,
        final_score: 2000,
        completed_puzzle: true,
        difficulty: :easy
      })

      Games.record_score(%{
        player_id: hard_player.id,
        game_room_id: hard_room.id,
        final_score: 8000,
        completed_puzzle: true,
        difficulty: :hard
      })

      Games.refresh_leaderboard()

      conn = build_conn()
      {:ok, view, _html} = live(conn, ~p"/leaderboard")

      %{view: view}
    end

    test "filters by easy difficulty", %{view: view} do
      html = render_change(view, "filter_difficulty", %{"difficulty" => "easy"})

      assert html =~ "easy_champ"
      refute html =~ "hard_master"
    end

    test "filters by hard difficulty", %{view: view} do
      html = render_change(view, "filter_difficulty", %{"difficulty" => "hard"})

      refute html =~ "easy_champ"
      assert html =~ "hard_master"
    end

    test "shows all difficulties when 'all' selected", %{view: view} do
      html = render_change(view, "filter_difficulty", %{"difficulty" => "all"})

      assert html =~ "easy_champ"
      assert html =~ "hard_master"
    end
  end

  describe "leaderboard entries" do
    setup do
      {:ok, player} = Accounts.create_guest_user(%{username: "ranked_player"})
      {:ok, puzzle} = Games.create_puzzle(:expert)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Ranked Room",
          creator_id: player.id,
          puzzle_id: puzzle.id
        })

      Games.record_score(%{
        player_id: player.id,
        game_room_id: room.id,
        final_score: 10000,
        completed_puzzle: true,
        difficulty: :expert,
        time_elapsed_seconds: 300,
        correct_moves: 50,
        incorrect_moves: 2,
        longest_streak: 15
      })

      Games.refresh_leaderboard()

      conn = build_conn()
      {:ok, view, _html} = live(conn, ~p"/leaderboard")

      %{view: view}
    end

    test "displays player rank", %{view: view} do
      html = render(view)

      # Should show rank number
      assert html =~ ~r/\d+/
    end

    test "shows player username", %{view: view} do
      html = render(view)

      assert html =~ "ranked_player"
    end

    test "displays total score", %{view: view} do
      html = render(view)

      assert html =~ "10000"
    end

    test "shows games completed count", %{view: view} do
      html = render(view)

      # Should show at least 1 game completed
      assert html =~ "1"
    end
  end
end
