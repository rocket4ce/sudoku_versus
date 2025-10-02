defmodule SudokuVersus.Puzzles.Validator do
  @moduledoc """
  Fast O(1) move validation using pre-computed puzzle solutions.

  This module provides constant-time move validation by checking submitted
  values against the complete solution stored in the puzzle record.
  """

  alias SudokuVersus.Games.Puzzle

  @doc """
  Validates a player move against the puzzle's pre-computed solution.

  Returns `{:ok, true}` if the move is correct, `{:ok, false}` if incorrect,
  or `{:error, reason}` if the parameters are invalid.

  ## Parameters

    * `puzzle` - The puzzle struct with solution loaded
    * `row` - Row index (0-based)
    * `col` - Column index (0-based)
    * `value` - The value the player submitted (1-based, 1..size)

  ## Performance

  This function runs in O(1) time by calculating the index directly:
  `index = row * size + col` and checking `solution[index] == value`

  ## Examples

      iex> puzzle = %Puzzle{size: 9, solution: [1,2,3, ...]}
      iex> Validator.validate_move(puzzle, 0, 0, 1)
      {:ok, true}

      iex> Validator.validate_move(puzzle, 0, 0, 5)
      {:ok, false}

      iex> Validator.validate_move(puzzle, -1, 0, 1)
      {:error, "Invalid row: must be between 0 and 8"}
  """
  @spec validate_move(Puzzle.t() | map(), integer(), integer(), integer()) ::
          {:ok, boolean()} | {:error, String.t()}
  def validate_move(puzzle, row, col, value)
      when is_map(puzzle) and is_integer(row) and is_integer(col) and is_integer(value) do
    # Extract size and solution from either Puzzle struct or map (for testing)
    size = Map.get(puzzle, :size)
    solution = Map.get(puzzle, :solution)

    cond do
      is_nil(size) or is_nil(solution) ->
        {:error, "Invalid puzzle: must have size and solution fields"}

      row < 0 ->
        {:error, "Invalid row: must be between 0 and #{size - 1}"}

      row >= size ->
        {:error, "Invalid row: must be between 0 and #{size - 1}"}

      col < 0 ->
        {:error, "Invalid col: must be between 0 and #{size - 1}"}

      col >= size ->
        {:error, "Invalid col: must be between 0 and #{size - 1}"}

      value < 1 ->
        {:error, "Invalid value: must be between 1 and #{size}"}

      value > size ->
        {:error, "Invalid value: must be between 1 and #{size}"}

      true ->
        # O(1) validation: calculate index and check solution
        index = row * size + col
        correct_value = Enum.at(solution, index)
        {:ok, value == correct_value}
    end
  end

  def validate_move(_puzzle, _row, _col, _value) do
    {:error, "Invalid parameters: puzzle must be a map, row/col/value must be integers"}
  end

  @doc """
  Checks if a move is correct without returning detailed errors.

  This is a convenience function that returns a boolean directly.

  ## Examples

      iex> Validator.correct_move?(puzzle, 0, 0, 1)
      true

      iex> Validator.correct_move?(puzzle, 0, 0, 5)
      false
  """
  @spec correct_move?(Puzzle.t(), integer(), integer(), integer()) :: boolean()
  def correct_move?(puzzle, row, col, value) do
    case validate_move(puzzle, row, col, value) do
      {:ok, result} -> result
      {:error, _} -> false
    end
  end

  @doc """
  Calculates the array index for a given row and column.

  This is useful for debugging and testing.

  ## Examples

      iex> Validator.cell_index(0, 0, 9)
      0

      iex> Validator.cell_index(1, 0, 9)
      9

      iex> Validator.cell_index(1, 1, 16)
      17
  """
  @spec cell_index(integer(), integer(), integer()) :: integer()
  def cell_index(row, col, size) do
    row * size + col
  end
end
