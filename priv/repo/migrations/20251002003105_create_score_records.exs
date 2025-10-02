defmodule SudokuVersus.Repo.Migrations.CreateScoreRecords do
  use Ecto.Migration

  def change do
    create table(:score_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :final_score, :integer, null: false
      add :time_elapsed_seconds, :integer, null: false
      add :correct_moves, :integer, null: false
      add :incorrect_moves, :integer, null: false
      add :longest_streak, :integer, null: false
      add :completed_puzzle, :boolean, null: false
      add :difficulty, :difficulty_enum, null: false
      add :recorded_at, :utc_datetime, null: false

      add :player_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :game_room_id, references(:game_rooms, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:score_records, [:player_id, :final_score])
    create index(:score_records, [:difficulty, :final_score])
    create index(:score_records, [:recorded_at])
  end
end
