defmodule SudokuVersus.Repo.Migrations.CreateLeaderboardEntries do
  use Ecto.Migration

  def change do
    # Create materialized view for leaderboards
    execute(
      """
      CREATE MATERIALIZED VIEW leaderboard_entries AS
        SELECT
          u.id AS player_id,
          u.username,
          u.display_name,
          u.avatar_url,
          SUM(sr.final_score) AS total_score,
          COUNT(*) FILTER (WHERE sr.completed_puzzle = true) AS games_completed,
          AVG(sr.final_score) AS average_score,
          MAX(sr.final_score) AS highest_single_score,
          sr.difficulty,
          RANK() OVER (PARTITION BY sr.difficulty ORDER BY SUM(sr.final_score) DESC) AS rank
        FROM users u
        INNER JOIN score_records sr ON sr.player_id = u.id
        WHERE sr.completed_puzzle = true
        GROUP BY u.id, u.username, u.display_name, u.avatar_url, sr.difficulty
        
        UNION ALL
        
        SELECT
          u.id AS player_id,
          u.username,
          u.display_name,
          u.avatar_url,
          SUM(sr.final_score) AS total_score,
          COUNT(*) FILTER (WHERE sr.completed_puzzle = true) AS games_completed,
          AVG(sr.final_score) AS average_score,
          MAX(sr.final_score) AS highest_single_score,
          NULL::difficulty_enum AS difficulty,
          RANK() OVER (ORDER BY SUM(sr.final_score) DESC) AS rank
        FROM users u
        INNER JOIN score_records sr ON sr.player_id = u.id
        WHERE sr.completed_puzzle = true
        GROUP BY u.id, u.username, u.display_name, u.avatar_url
      """,
      "DROP MATERIALIZED VIEW leaderboard_entries"
    )

    create unique_index(:leaderboard_entries, [:player_id, :difficulty])
  end
end
