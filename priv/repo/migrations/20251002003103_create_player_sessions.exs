defmodule SudokuVersus.Repo.Migrations.CreatePlayerSessions do
  use Ecto.Migration

  def change do
    create table(:player_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :started_at, :utc_datetime, null: false
      add :last_activity_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :is_active, :boolean, default: true, null: false

      # Scoring tracking
      add :current_score, :integer, default: 0, null: false
      add :current_streak, :integer, default: 0, null: false
      add :longest_streak, :integer, default: 0, null: false
      add :correct_moves_count, :integer, default: 0, null: false
      add :incorrect_moves_count, :integer, default: 0, null: false
      add :cells_filled, :integer, default: 0, null: false
      add :completed_puzzle, :boolean, default: false, null: false

      add :player_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :game_room_id, references(:game_rooms, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:player_sessions, [:player_id, :game_room_id])
    create index(:player_sessions, [:game_room_id])
    create index(:player_sessions, [:is_active])
  end
end
