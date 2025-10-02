defmodule SudokuVersus.Repo.Migrations.CreatePuzzles do
  use Ecto.Migration

  def change do
    # Create enum type for difficulty
    execute(
      "CREATE TYPE difficulty_enum AS ENUM ('easy', 'medium', 'hard', 'expert')",
      "DROP TYPE difficulty_enum"
    )

    create table(:puzzles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :difficulty, :difficulty_enum, null: false
      add :grid, {:array, {:array, :integer}}, null: false
      add :solution, {:array, {:array, :integer}}, null: false
      add :clues_count, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:puzzles, [:difficulty])

    create constraint(:puzzles, :valid_clues_count,
             check: "clues_count >= 22 AND clues_count <= 45"
           )
  end
end
