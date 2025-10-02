defmodule SudokuVersus.Games.Puzzle do
  @moduledoc """
  Schema for Sudoku puzzles.

  Stores pre-generated puzzles with their solutions for game rooms.
  Grid and solution are stored as 9x9 arrays (list of lists).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "puzzles" do
    field :grid, {:array, {:array, :integer}}
    field :solution, {:array, {:array, :integer}}
    field :clues_count, :integer
    field :difficulty, Ecto.Enum, values: [:easy, :medium, :hard, :expert]

    timestamps()
  end

  @doc """
  Changeset for creating a new puzzle.
  """
  def changeset(puzzle, attrs) do
    puzzle
    |> cast(attrs, [:grid, :solution, :clues_count, :difficulty])
    |> validate_required([:grid, :solution, :clues_count, :difficulty])
    |> validate_grid_structure(:grid)
    |> validate_grid_structure(:solution)
    |> validate_clues_count()
    |> validate_solution_complete()
  end

  # Private validation functions

  defp validate_grid_structure(changeset, field) do
    validate_change(changeset, field, fn ^field, grid ->
      cond do
        !is_list(grid) ->
          [{field, "must be a list"}]

        length(grid) != 9 ->
          [{field, "must have exactly 9 rows"}]

        !Enum.all?(grid, &valid_row?/1) ->
          [{field, "each row must have exactly 9 cells with values 0-9 (0 for empty)"}]

        true ->
          []
      end
    end)
  end

  defp valid_row?(row) do
    is_list(row) and length(row) == 9 and Enum.all?(row, &valid_cell?/1)
  end

  defp valid_cell?(cell) do
    is_integer(cell) and cell >= 0 and cell <= 9
  end

  defp validate_clues_count(changeset) do
    changeset
    |> validate_number(:clues_count, greater_than_or_equal_to: 22, less_than_or_equal_to: 45)
  end

  defp validate_solution_complete(changeset) do
    validate_change(changeset, :solution, fn :solution, solution ->
      if is_list(solution) and Enum.all?(List.flatten(solution), &(&1 in 1..9)) do
        []
      else
        [{:solution, "must be a complete 9x9 grid with values 1-9 (no empty cells)"}]
      end
    end)
  end
end
