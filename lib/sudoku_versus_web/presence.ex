defmodule SudokuVersusWeb.Presence do
  @moduledoc """
  Phoenix Presence for tracking online players in game rooms.

  Automatically tracks player presence per room with graceful handling of disconnects.
  Used to maintain accurate current_players_count in game rooms.

  ## Usage

  Subscribe to presence updates:

      Phoenix.PubSub.subscribe(SudokuVersus.PubSub, "game_room:\#{room_id}")

  Track a player in a room:

      SudokuVersusWeb.Presence.track(
        self(),
        "game_room:\#{room_id}",
        player_id,
        %{username: username, joined_at: System.system_time(:second)}
      )

  Get list of present players:

      SudokuVersusWeb.Presence.list("game_room:\#{room_id}")
  """
  use Phoenix.Presence,
    otp_app: :sudoku_versus,
    pubsub_server: SudokuVersus.PubSub
end
