defmodule SudokuVersus.Repo.Migrations.CreateMoves do
  use Ecto.Migration

  def change do
    create table(:moves, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :row, :integer, null: false
      add :col, :integer, null: false
      add :value, :integer, null: false
      add :is_correct, :boolean, null: false
      add :submitted_at, :utc_datetime, null: false
      add :points_earned, :integer, default: 0, null: false

      add :player_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :game_room_id, references(:game_rooms, type: :binary_id, on_delete: :delete_all),
        null: false

      add :player_session_id,
          references(:player_sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:moves, [:game_room_id, :inserted_at])
    create index(:moves, [:player_session_id])
    create index(:moves, [:player_id])

    create constraint(:moves, :valid_row, check: "row >= 0 AND row < 9")
    create constraint(:moves, :valid_col, check: "col >= 0 AND col < 9")
    create constraint(:moves, :valid_value, check: "value >= 1 AND value <= 9")
  end
end
