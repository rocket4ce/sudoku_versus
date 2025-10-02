defmodule SudokuVersus.Games.Puzzle do
  @moduledoc """
  Schema for Sudoku puzzles.

  Stores pre-generated puzzles with their solutions for game rooms.
  Grid and solution are stored as NxN arrays (list of lists) where N can be 9 or 16.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "puzzles" do
    field :grid, {:array, {:array, :integer}}
    field :solution, {:array, {:array, :integer}}
    field :clues_count, :integer
    field :grid_size, :integer, default: 9
    field :size, :integer, default: 16
    field :sub_grid_size, :integer, default: 4
    field :difficulty, Ecto.Enum, values: [:easy, :medium, :hard, :expert]

    timestamps()
  end

  @doc """
  Changeset for creating a new puzzle.
  """
  def changeset(puzzle, attrs) do
    puzzle
    |> cast(attrs, [:grid, :solution, :clues_count, :difficulty, :grid_size, :size, :sub_grid_size])
    |> validate_required([:grid, :solution, :clues_count, :difficulty, :grid_size, :size, :sub_grid_size])
    |> validate_inclusion(:grid_size, [9, 16, 25, 36, 49, 100])
    |> validate_inclusion(:size, [9, 16, 25, 36, 49, 100])
    |> validate_grid_structure(:grid)
    |> validate_grid_structure(:solution)
    |> validate_clues_count()
    |> validate_sub_grid_size()
    |> validate_solution_complete()
  end

  # Private validation functions

  defp validate_grid_structure(changeset, field) do
    validate_change(changeset, field, fn ^field, grid ->
      grid_size = get_field(changeset, :grid_size) || 9
      max_value = grid_size

      cond do
        !is_list(grid) ->
          [{field, "must be a list"}]

        length(grid) != grid_size ->
          [{field, "must have exactly #{grid_size} rows"}]

        !Enum.all?(grid, &valid_row?(&1, grid_size, max_value)) ->
          [
            {field,
             "each row must have exactly #{grid_size} cells with values 0-#{max_value} (0 for empty)"}
          ]

        true ->
          []
      end
    end)
  end

  defp valid_row?(row, grid_size, max_value) do
    is_list(row) and length(row) == grid_size and
      Enum.all?(row, &valid_cell?(&1, max_value))
  end

  defp valid_cell?(cell, max_value) do
    is_integer(cell) and cell >= 0 and cell <= max_value
  end

  defp validate_clues_count(changeset) do
    size = get_field(changeset, :size) || get_field(changeset, :grid_size) || 16

    # Dynamic constraint: 20-60% of cells must be clues
    min_clues = trunc(size * size * 0.2)
    max_clues = trunc(size * size * 0.6)

    changeset
    |> validate_number(:clues_count,
      greater_than_or_equal_to: min_clues,
      less_than_or_equal_to: max_clues,
      message: "must be between #{min_clues} and #{max_clues} for #{size}x#{size} puzzle"
    )
  end

  defp validate_sub_grid_size(changeset) do
    validate_change(changeset, :sub_grid_size, fn :sub_grid_size, sub_grid_size ->
      size = get_field(changeset, :size)

      expected_sub_grid_size = case size do
        9 -> 3
        16 -> 4
        25 -> 5
        36 -> 6
        49 -> 7
        100 -> 10
        _ -> nil
      end

      if expected_sub_grid_size && sub_grid_size == expected_sub_grid_size do
        []
      else
        [{:sub_grid_size, "must be #{expected_sub_grid_size} for #{size}x#{size} puzzle (√#{size})"}]
      end
    end)
  end

  defp validate_solution_complete(changeset) do
    validate_change(changeset, :solution, fn :solution, solution ->
      grid_size = get_field(changeset, :grid_size) || 9

      if is_list(solution) and
           Enum.all?(List.flatten(solution), &(&1 in 1..grid_size)) do
        []
      else
        [{:solution,
          "must be a complete #{grid_size}x#{grid_size} grid with values 1-#{grid_size} (no empty cells)"}]
      end
    end)
  end
end
