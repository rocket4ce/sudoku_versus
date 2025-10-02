defmodule SudokuVersus.Repo.Migrations.AddPuzzleSizeSupport do
  use Ecto.Migration

  def change do
    # Add size and sub_grid_size columns to puzzles table
    alter table(:puzzles) do
      add :size, :integer, null: false, default: 16
      add :sub_grid_size, :integer, null: false, default: 4
    end

    # Create index on size for filtering
    create index(:puzzles, [:size])

    # Create composite index for size and difficulty filtering
    create index(:puzzles, [:size, :difficulty])

    # Add constraint to ensure size is one of the supported values
    create constraint(:puzzles, :valid_size,
             check: "size IN (9, 16, 25, 36, 49, 100)"
           )

    # Add constraint to ensure sub_grid_size is the square root of size
    create constraint(:puzzles, :valid_sub_grid_size,
             check: "(size = 9 AND sub_grid_size = 3) OR
                     (size = 16 AND sub_grid_size = 4) OR
                     (size = 25 AND sub_grid_size = 5) OR
                     (size = 36 AND sub_grid_size = 6) OR
                     (size = 49 AND sub_grid_size = 7) OR
                     (size = 100 AND sub_grid_size = 10)"
           )

    # Drop old clues_count constraint (16x16 specific)
    drop constraint(:puzzles, :valid_clues_count)

    # Add new dynamic clues_count constraint based on size
    # Minimum: 20% of cells, Maximum: 60% of cells
    create constraint(:puzzles, :valid_clues_count_by_size,
             check: "clues_count >= (size * size * 0.2)::integer AND
                     clues_count <= (size * size * 0.6)::integer"
           )
  end
end
