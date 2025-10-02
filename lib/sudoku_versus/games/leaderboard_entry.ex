defmodule SudokuVersus.Games.LeaderboardEntry do
  @moduledoc """
  Schema for leaderboard entries (materialized view).

  Read-only schema for querying pre-aggregated leaderboard data.
  Materialized view is refreshed periodically (every 60 seconds) by a GenServer.

  Note: This schema does NOT support insert/update/delete operations.
  """
  use Ecto.Schema

  @primary_key false

  schema "leaderboard_entries" do
    field :player_id, :binary_id
    field :username, :string
    field :display_name, :string
    field :avatar_url, :string
    field :total_score, :integer
    field :games_completed, :integer
    field :average_score, :float
    field :highest_single_score, :integer
    field :difficulty, Ecto.Enum, values: [:easy, :medium, :hard, :expert]
    field :rank, :integer
  end

  @doc """
  Returns a query for fetching leaderboard entries by difficulty.
  Pass difficulty: nil for overall leaderboard.
  """
  def by_difficulty(query \\ __MODULE__, difficulty) do
    import Ecto.Query

    if is_nil(difficulty) do
      from(e in query, where: is_nil(e.difficulty))
    else
      from(e in query, where: e.difficulty == ^difficulty)
    end
  end

  @doc """
  Returns a query for top N entries ordered by rank.
  """
  def top(query \\ __MODULE__, limit) do
    import Ecto.Query

    from(e in query,
      order_by: [asc: e.rank],
      limit: ^limit
    )
  end

  @doc """
  Returns a query for a specific player's entry.
  """
  def for_player(query \\ __MODULE__, player_id) do
    import Ecto.Query

    from(e in query, where: e.player_id == ^player_id)
  end
end
