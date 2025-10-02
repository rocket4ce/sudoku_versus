defmodule SudokuVersusWeb.GameLive.IndexTest do
  use SudokuVersusWeb.ConnCase

  import Phoenix.LiveViewTest
  alias SudokuVersus.{Accounts, Games}

  describe "mount" do
    setup do
      {:ok, user} = Accounts.create_guest_user(%{username: "lobby_viewer"})
      %{user: user}
    end

    test "renders room list with streams", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/game")

      assert has_element?(view, "#room-list")
    end

    test "displays create room form", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/game")

      assert has_element?(view, "#create-room-form")
    end

    test "shows existing rooms with player counts", %{conn: conn, user: user} do
      {:ok, puzzle} = Games.create_puzzle(:medium)

      {:ok, _room} =
        Games.create_game_room(%{
          name: "Test Room 🎮",
          creator_id: user.id,
          puzzle_id: puzzle.id,
          visibility: :public
        })

      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      {:ok, view, _html} = live(conn, ~p"/game")

      assert render(view) =~ "Test Room 🎮"
    end
  end

  describe "handle_event create_room" do
    setup do
      {:ok, user} = Accounts.create_guest_user(%{username: "room_creator"})
      conn = build_conn() |> Plug.Test.init_test_session(user_id: user.id)
      {:ok, view, _html} = live(conn, ~p"/game")

      %{view: view, user: user}
    end

    test "creates room and redirects to game page", %{view: view} do
      form_data = %{
        "room" => %{
          "name" => "New Room",
          "difficulty" => "medium",
          "visibility" => "public"
        }
      }

      render_submit(view, "create_room", form_data)

      # Should redirect to the new room's show page
      assert_redirect(view, ~p"/game/#{:id}")
    end

    test "shows error with invalid room name", %{view: view} do
      form_data = %{
        "room" => %{
          # Empty name
          "name" => "",
          "difficulty" => "medium"
        }
      }

      html = render_submit(view, "create_room", form_data)

      assert html =~ "can&#39;t be blank"
    end

    test "creates room with emoji in name", %{view: view} do
      form_data = %{
        "room" => %{
          "name" => "Epic Room 🎮🔥",
          "difficulty" => "hard"
        }
      }

      render_submit(view, "create_room", form_data)

      # Room should be created successfully
      assert_redirect(view)
    end
  end

  describe "handle_event filter" do
    setup do
      {:ok, user} = Accounts.create_guest_user(%{username: "filter_user"})
      {:ok, puzzle_easy} = Games.create_puzzle(:easy)
      {:ok, puzzle_hard} = Games.create_puzzle(:hard)

      {:ok, _easy_room} =
        Games.create_game_room(%{
          name: "Easy Room",
          creator_id: user.id,
          puzzle_id: puzzle_easy.id
        })

      {:ok, _hard_room} =
        Games.create_game_room(%{
          name: "Hard Room",
          creator_id: user.id,
          puzzle_id: puzzle_hard.id
        })

      conn = build_conn() |> Plug.Test.init_test_session(user_id: user.id)
      {:ok, view, _html} = live(conn, ~p"/game")

      %{view: view}
    end

    test "filters rooms by difficulty", %{view: view} do
      html = render_change(view, "filter", %{"difficulty" => "easy"})

      assert html =~ "Easy Room"
      refute html =~ "Hard Room"
    end

    test "shows all rooms when filter is 'all'", %{view: view} do
      html = render_change(view, "filter", %{"difficulty" => "all"})

      assert html =~ "Easy Room"
      assert html =~ "Hard Room"
    end
  end

  describe "room cards" do
    setup do
      {:ok, user} = Accounts.create_guest_user(%{username: "card_viewer"})
      {:ok, puzzle} = Games.create_puzzle(:medium)

      {:ok, room} =
        Games.create_game_room(%{
          name: "Active Room",
          creator_id: user.id,
          puzzle_id: puzzle.id
        })

      # Join room to update player count
      {:ok, _session} = Games.join_room(room.id, user.id)

      conn = build_conn() |> Plug.Test.init_test_session(user_id: user.id)
      {:ok, view, _html} = live(conn, ~p"/game")

      %{view: view, room: room}
    end

    test "displays room name and difficulty", %{view: view} do
      html = render(view)

      assert html =~ "Active Room"
      assert html =~ "medium"
    end

    test "shows current player count", %{view: view} do
      html = render(view)

      # Room has 1 player (the creator who joined)
      assert html =~ "1"
    end

    test "has join button for each room", %{view: view} do
      assert has_element?(view, "button", "Join")
    end
  end
end
