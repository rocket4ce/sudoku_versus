defmodule SudokuVersus.Repo.Migrations.CreateGameRooms do
  use Ecto.Migration

  def change do
    # Create enum types for status and visibility
    execute(
      "CREATE TYPE room_status_enum AS ENUM ('active', 'completed', 'archived')",
      "DROP TYPE room_status_enum"
    )

    execute(
      "CREATE TYPE visibility_enum AS ENUM ('public', 'private')",
      "DROP TYPE visibility_enum"
    )

    create table(:game_rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :status, :room_status_enum, default: "active", null: false
      add :max_players, :integer
      add :visibility, :visibility_enum, default: "public", null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      # Denormalized counts for performance
      add :current_players_count, :integer, default: 0, null: false
      add :total_moves_count, :integer, default: 0, null: false

      add :creator_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :puzzle_id, references(:puzzles, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:game_rooms, [:status])
    create index(:game_rooms, [:inserted_at])
    create index(:game_rooms, [:creator_id])
  end
end
