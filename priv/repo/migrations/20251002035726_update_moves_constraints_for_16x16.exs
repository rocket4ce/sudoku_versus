defmodule SudokuVersus.Repo.Migrations.UpdateMovesConstraintsFor16x16 do
  use Ecto.Migration

  def change do
    # Drop existing constraints that limit to 9x9
    drop constraint(:moves, :valid_row)
    drop constraint(:moves, :valid_col)
    drop constraint(:moves, :valid_value)

    # Add new constraints that support both 9x9 and 16x16
    create constraint(:moves, :valid_row, check: "row >= 0 AND row < 16")
    create constraint(:moves, :valid_col, check: "col >= 0 AND col < 16")
    create constraint(:moves, :valid_value, check: "value >= 1 AND value <= 16")
  end
end
