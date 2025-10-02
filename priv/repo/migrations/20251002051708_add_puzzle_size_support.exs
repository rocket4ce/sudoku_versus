defmodule SudokuVersus.Repo.Migrations.AddPuzzleSizeSupport do
  use Ecto.Migration

  def up do
    # Add size and sub_grid_size columns to puzzles table
    alter table(:puzzles) do
      add :size, :integer, null: false, default: 16
      add :sub_grid_size, :integer, null: false, default: 4
    end

    # Update existing puzzles to have correct size from grid_size
    execute "UPDATE puzzles SET size = grid_size"
    execute "UPDATE puzzles SET sub_grid_size = 3 WHERE grid_size = 9"
    execute "UPDATE puzzles SET sub_grid_size = 4 WHERE grid_size = 16"

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

    # Drop old grid_size based constraints
    drop constraint(:puzzles, :valid_clues_count_9x9)
    drop constraint(:puzzles, :valid_clues_count_16x16)
    drop constraint(:puzzles, :valid_grid_size)

    # Add new dynamic clues_count constraint based on size
    # Minimum: 20% of cells, Maximum: 60% of cells
    create constraint(:puzzles, :valid_clues_count_by_size,
             check: "clues_count >= (size * size * 0.2)::integer AND
                     clues_count <= (size * size * 0.6)::integer"
           )
  end

  def down do
    # Drop new constraint
    drop constraint(:puzzles, :valid_clues_count_by_size)

    # Restore old constraints
    create constraint(:puzzles, :valid_grid_size, check: "grid_size IN (9, 16)")

    create constraint(:puzzles, :valid_clues_count_16x16,
             check:
               "(grid_size = 16 AND clues_count >= 80 AND clues_count <= 150) OR grid_size != 16"
           )

    create constraint(:puzzles, :valid_clues_count_9x9,
             check:
               "(grid_size = 9 AND clues_count >= 22 AND clues_count <= 45) OR grid_size != 9"
           )

    # Drop constraints
    drop constraint(:puzzles, :valid_sub_grid_size)
    drop constraint(:puzzles, :valid_size)

    # Drop indexes
    drop index(:puzzles, [:size, :difficulty])
    drop index(:puzzles, [:size])

    # Drop columns
    alter table(:puzzles) do
      remove :sub_grid_size
      remove :size
    end
  end
end
