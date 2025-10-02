defmodule SudokuVersusWeb.LeaderboardLive.Index do
  use SudokuVersusWeb, :live_view

  alias SudokuVersus.Games

  @impl true
  def mount(_params, _session, socket) do
    leaderboard = Games.get_leaderboard(nil, limit: 100)

    socket =
      socket
      |> assign(:page_title, "Leaderboard")
      |> assign(:filter_difficulty, nil)
      |> assign(:leaderboard_count, length(leaderboard))
      |> stream(:leaderboard, leaderboard)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_difficulty", %{"difficulty" => difficulty}, socket) do
    filter = if difficulty == "", do: nil, else: String.to_existing_atom(difficulty)
    
    leaderboard = Games.get_leaderboard(filter, limit: 100)

    socket =
      socket
      |> assign(:filter_difficulty, filter)
      |> assign(:leaderboard_count, length(leaderboard))
      |> stream(:leaderboard, leaderboard, reset: true)

    {:noreply, socket}
  end
end
