defmodule SudokuVersus.Games.LeaderboardRefresher do
  @moduledoc """
  GenServer that periodically refreshes the leaderboard materialized view.

  Refreshes the leaderboard_entries materialized view every 60 seconds to ensure
  rankings stay up-to-date as games complete and scores are recorded.
  """

  use GenServer
  require Logger

  alias SudokuVersus.Games

  @refresh_interval :timer.seconds(60)

  ## Client API

  @doc """
  Starts the LeaderboardRefresher GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an immediate refresh of the leaderboard (async).
  """
  def refresh_now do
    GenServer.cast(__MODULE__, :refresh)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("LeaderboardRefresher started, will refresh every #{@refresh_interval}ms")
    schedule_refresh()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:refresh, state) do
    Logger.debug("LeaderboardRefresher: refreshing materialized view")

    case Games.refresh_leaderboard() do
      {:ok, _result} ->
        Logger.debug("LeaderboardRefresher: refresh completed successfully")

      {:error, reason} ->
        Logger.error("LeaderboardRefresher: refresh failed - #{inspect(reason)}")
    end

    schedule_refresh()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    send(self(), :refresh)
    {:noreply, state}
  end

  ## Private Functions

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
