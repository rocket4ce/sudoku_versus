defmodule SudokuVersusWeb.Integration.PresenceTest do
  use SudokuVersusWeb.ConnCase

  import Phoenix.LiveViewTest
  alias SudokuVersus.{Accounts, Games}
  alias SudokuVersusWeb.Presence

  @moduledoc """
  Integration test for Phoenix.Presence player tracking:
  1. User joins room → presence count = 1
  2. User leaves → presence count = 0
  3. Multiple users join → count increases
  4. LiveView handles presence_diff messages
  """

  test "presence count increases when player joins room", _context do
    {:ok, player} = Accounts.create_guest_user(%{username: "presence_joiner"})
    {:ok, puzzle} = Games.create_puzzle(:medium)

    {:ok, room} =
      Games.create_game_room(%{
        name: "Presence Test Room",
        creator_id: player.id,
        puzzle_id: puzzle.id
      })

    # Initially, no one is in the room
    topic = "game_room:#{room.id}"
    presences = Presence.list(topic)
    assert map_size(presences) == 0

    # Player joins via LiveView
    conn_player = build_conn() |> Plug.Test.init_test_session(user_id: player.id)
    {:ok, view, _html} = live(conn_player, ~p"/game/#{room.id}")

    # Wait for presence to track
    :timer.sleep(100)

    # Now presence count should be 1
    presences = Presence.list(topic)
    assert map_size(presences) == 1

    # View should show 1 player online
    assert has_element?(view, "#player-list")
  end

  test "presence count decreases when player leaves room", _context do
    {:ok, player} = Accounts.create_guest_user(%{username: "presence_leaver"})
    {:ok, puzzle} = Games.create_puzzle(:easy)

    {:ok, room} =
      Games.create_game_room(%{
        name: "Leave Test Room",
        creator_id: player.id,
        puzzle_id: puzzle.id
      })

    topic = "game_room:#{room.id}"

    # Player joins
    conn_player = build_conn() |> Plug.Test.init_test_session(user_id: player.id)
    {:ok, view, _html} = live(conn_player, ~p"/game/#{room.id}")

    :timer.sleep(100)

    # Verify presence
    presences = Presence.list(topic)
    assert map_size(presences) == 1

    # Player leaves (stop the LiveView process)
    GenServer.stop(view.pid)

    :timer.sleep(100)

    # Presence count should be 0
    presences = Presence.list(topic)
    assert map_size(presences) == 0
  end

  test "multiple players tracked correctly", _context do
    {:ok, player1} = Accounts.create_guest_user(%{username: "multi_player_1"})
    {:ok, player2} = Accounts.create_guest_user(%{username: "multi_player_2"})
    {:ok, player3} = Accounts.create_guest_user(%{username: "multi_player_3"})

    {:ok, puzzle} = Games.create_puzzle(:hard)

    {:ok, room} =
      Games.create_game_room(%{
        name: "Multi Player Room",
        creator_id: player1.id,
        puzzle_id: puzzle.id
      })

    topic = "game_room:#{room.id}"

    # Player 1 joins
    conn1 = build_conn() |> Plug.Test.init_test_session(user_id: player1.id)
    {:ok, view1, _html} = live(conn1, ~p"/game/#{room.id}")

    :timer.sleep(50)
    assert map_size(Presence.list(topic)) == 1

    # Player 2 joins
    conn2 = build_conn() |> Plug.Test.init_test_session(user_id: player2.id)
    {:ok, view2, _html} = live(conn2, ~p"/game/#{room.id}")

    :timer.sleep(50)
    assert map_size(Presence.list(topic)) == 2

    # Player 3 joins
    conn3 = build_conn() |> Plug.Test.init_test_session(user_id: player3.id)
    {:ok, _view3, _html} = live(conn3, ~p"/game/#{room.id}")

    :timer.sleep(50)
    assert map_size(Presence.list(topic)) == 3

    # Player 1 should see all 3 players
    html1 = render(view1)
    assert html1 =~ "multi_player_2"
    assert html1 =~ "multi_player_3"

    # Player 2 should see all 3 players
    html2 = render(view2)
    assert html2 =~ "multi_player_1"
    assert html2 =~ "multi_player_3"
  end

  test "presence_diff message updates player list in LiveView", _context do
    {:ok, player_a} = Accounts.create_guest_user(%{username: "diff_player_a"})
    {:ok, player_b} = Accounts.create_guest_user(%{username: "diff_player_b"})

    {:ok, puzzle} = Games.create_puzzle(:expert)

    {:ok, room} =
      Games.create_game_room(%{
        name: "Diff Test Room",
        creator_id: player_a.id,
        puzzle_id: puzzle.id
      })

    # Player A joins first
    conn_a = build_conn() |> Plug.Test.init_test_session(user_id: player_a.id)
    {:ok, view_a, _html} = live(conn_a, ~p"/game/#{room.id}")

    :timer.sleep(50)

    # Player B joins
    conn_b = build_conn() |> Plug.Test.init_test_session(user_id: player_b.id)
    {:ok, _view_b, _html} = live(conn_b, ~p"/game/#{room.id}")

    :timer.sleep(100)

    # Player A should receive presence_diff and update their view
    html_a = render(view_a)
    assert html_a =~ "diff_player_b"
  end

  test "presence metadata includes player information", _context do
    {:ok, player} = Accounts.create_guest_user(%{username: "metadata_player"})
    {:ok, puzzle} = Games.create_puzzle(:medium)

    {:ok, room} =
      Games.create_game_room(%{
        name: "Metadata Room",
        creator_id: player.id,
        puzzle_id: puzzle.id
      })

    topic = "game_room:#{room.id}"

    # Player joins
    conn_player = build_conn() |> Plug.Test.init_test_session(user_id: player.id)
    {:ok, _view, _html} = live(conn_player, ~p"/game/#{room.id}")

    :timer.sleep(100)

    # Get presence list
    presences = Presence.list(topic)

    # Should have metadata about the player
    assert map_size(presences) == 1

    # Verify presence entry has player info
    [{_player_id, %{metas: metas}}] = Map.to_list(presences)
    [meta | _] = metas

    assert Map.has_key?(meta, :username) or Map.has_key?(meta, :player_id)
  end

  test "presence handles player reconnection", _context do
    {:ok, player} = Accounts.create_guest_user(%{username: "reconnect_player"})
    {:ok, puzzle} = Games.create_puzzle(:easy)

    {:ok, room} =
      Games.create_game_room(%{
        name: "Reconnect Room",
        creator_id: player.id,
        puzzle_id: puzzle.id
      })

    topic = "game_room:#{room.id}"

    # Player joins
    conn_player = build_conn() |> Plug.Test.init_test_session(user_id: player.id)
    {:ok, view1, _html} = live(conn_player, ~p"/game/#{room.id}")

    :timer.sleep(50)
    assert map_size(Presence.list(topic)) == 1

    # Player disconnects
    GenServer.stop(view1.pid)

    :timer.sleep(50)
    assert map_size(Presence.list(topic)) == 0

    # Player reconnects
    {:ok, _view2, _html} = live(conn_player, ~p"/game/#{room.id}")

    :timer.sleep(50)
    assert map_size(Presence.list(topic)) == 1
  end
end
