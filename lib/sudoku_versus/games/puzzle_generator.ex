defmodule SudokuVersus.Games.PuzzleGenerator do
  @moduledoc """
  Generates Sudoku puzzles with solutions using a backtracking algorithm.

  Puzzle generation takes 10-50ms which is acceptable for real-time usage.
  Generated puzzles are cached in the database for reuse.
  """

  alias SudokuVersus.Repo
  alias SudokuVersus.Games.Puzzle

  @doc """
  Generates a new Sudoku puzzle with the specified difficulty.

  Difficulty levels determine the number of clues (pre-filled numbers):
  - :easy - 36-45 clues
  - :medium - 30-35 clues
  - :hard - 25-29 clues
  - :expert - 22-24 clues

  Returns {:ok, puzzle} with both grid (with empty cells as 0) and complete solution.
  """
  def generate_puzzle(difficulty) when difficulty in [:easy, :medium, :hard, :expert] do
    # Generate a complete valid Sudoku solution
    solution = generate_complete_sudoku()

    # Remove numbers based on difficulty
    clues_count = clues_for_difficulty(difficulty)
    grid = remove_numbers(solution, clues_count)

    # Create puzzle record in database
    attrs = %{
      difficulty: difficulty,
      grid: grid,
      solution: solution,
      clues_count: count_clues(grid)
    }

    %Puzzle{}
    |> Puzzle.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Validates if a move is correct for the given puzzle.

  Returns true if:
  - The cell at (row, col) is currently empty (0 in grid)
  - The value matches the solution at that position

  Returns false otherwise.
  """
  def validate_move?(%Puzzle{} = puzzle, row, col, value)
      when row in 0..8 and col in 0..8 and value in 1..9 do
    current_value = puzzle.grid |> Enum.at(row) |> Enum.at(col)
    solution_value = puzzle.solution |> Enum.at(row) |> Enum.at(col)

    current_value == 0 and solution_value == value
  end

  def validate_move?(_, _, _, _), do: false

  @doc """
  Caches the puzzle solution as a map with index keys for O(1) lookup.

  Returns a map like %{0 => 5, 1 => 3, ..., 80 => 7} where index = row * 9 + col.
  """
  def cache_solution(%Puzzle{} = puzzle) do
    puzzle.solution
    |> List.flatten()
    |> Enum.with_index()
    |> Map.new(fn {value, index} -> {index, value} end)
  end

  # Private functions

  defp generate_complete_sudoku do
    grid = initialize_empty_grid()

    grid
    |> fill_diagonal_boxes()
    |> solve_recursive()
    |> case do
      {:ok, solved_grid} -> solved_grid
      :error -> generate_complete_sudoku()
    end
  end

  defp initialize_empty_grid do
    List.duplicate(List.duplicate(0, 9), 9)
  end

  defp fill_diagonal_boxes(grid) do
    # Fill the three 3x3 boxes on the diagonal (they don't affect each other)
    grid
    |> fill_box(0, 0)
    |> fill_box(3, 3)
    |> fill_box(6, 6)
  end

  defp fill_box(grid, row_start, col_start) do
    numbers = Enum.shuffle(1..9)

    Enum.reduce(0..8, grid, fn i, acc_grid ->
      row = row_start + div(i, 3)
      col = col_start + rem(i, 3)
      value = Enum.at(numbers, i)
      set_cell(acc_grid, row, col, value)
    end)
  end

  defp solve_recursive(grid) do
    case find_empty_cell(grid) do
      nil ->
        {:ok, grid}

      {row, col} ->
        Enum.shuffle(1..9)
        |> Enum.reduce_while(:error, fn num, _ ->
          if is_safe?(grid, row, col, num) do
            new_grid = set_cell(grid, row, col, num)

            case solve_recursive(new_grid) do
              {:ok, solved} -> {:halt, {:ok, solved}}
              :error -> {:cont, :error}
            end
          else
            {:cont, :error}
          end
        end)
    end
  end

  defp find_empty_cell(grid) do
    Enum.reduce_while(0..8, nil, fn row, _ ->
      result =
        Enum.reduce_while(0..8, nil, fn col, _ ->
          if get_cell(grid, row, col) == 0 do
            {:halt, {row, col}}
          else
            {:cont, nil}
          end
        end)

      if result do
        {:halt, result}
      else
        {:cont, nil}
      end
    end)
  end

  defp is_safe?(grid, row, col, num) do
    !used_in_row?(grid, row, num) and
      !used_in_col?(grid, col, num) and
      !used_in_box?(grid, row - rem(row, 3), col - rem(col, 3), num)
  end

  defp used_in_row?(grid, row, num) do
    grid |> Enum.at(row) |> Enum.member?(num)
  end

  defp used_in_col?(grid, col, num) do
    grid |> Enum.map(&Enum.at(&1, col)) |> Enum.member?(num)
  end

  defp used_in_box?(grid, row_start, col_start, num) do
    Enum.any?(0..2, fn i ->
      Enum.any?(0..2, fn j ->
        get_cell(grid, row_start + i, col_start + j) == num
      end)
    end)
  end

  defp remove_numbers(solution, target_clues) do
    total_cells = 81
    cells_to_remove = total_cells - target_clues

    # Get all cell positions and shuffle them
    positions = for row <- 0..8, col <- 0..8, do: {row, col}
    positions_to_remove = positions |> Enum.shuffle() |> Enum.take(cells_to_remove)

    Enum.reduce(positions_to_remove, solution, fn {row, col}, acc_grid ->
      set_cell(acc_grid, row, col, 0)
    end)
  end

  defp count_clues(grid) do
    grid
    |> List.flatten()
    |> Enum.count(&(&1 != 0))
  end

  defp get_cell(grid, row, col) do
    grid |> Enum.at(row) |> Enum.at(col)
  end

  defp set_cell(grid, row, col, value) do
    List.update_at(grid, row, fn row_list ->
      List.update_at(row_list, col, fn _ -> value end)
    end)
  end

  defp clues_for_difficulty(:easy), do: Enum.random(36..45)
  defp clues_for_difficulty(:medium), do: Enum.random(30..35)
  defp clues_for_difficulty(:hard), do: Enum.random(25..29)
  defp clues_for_difficulty(:expert), do: Enum.random(22..24)
end
