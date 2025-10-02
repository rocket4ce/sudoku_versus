defmodule SudokuVersus.Repo.Migrations.AddGridSizeToPuzzles do
  use Ecto.Migration

  def change do
    alter table(:puzzles) do
      add :grid_size, :integer, null: false, default: 9
    end

    # Drop existing constraint and add new one that supports both 9x9 and 16x16
    drop constraint(:puzzles, :valid_clues_count)

    create constraint(:puzzles, :valid_clues_count_9x9,
             check:
               "(grid_size = 9 AND clues_count >= 22 AND clues_count <= 45) OR grid_size != 9"
           )

    create constraint(:puzzles, :valid_clues_count_16x16,
             check:
               "(grid_size = 16 AND clues_count >= 80 AND clues_count <= 150) OR grid_size != 16"
           )

    create constraint(:puzzles, :valid_grid_size, check: "grid_size IN (9, 16)")
  end
end
