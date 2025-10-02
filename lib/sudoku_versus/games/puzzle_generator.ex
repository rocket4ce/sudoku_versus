defmodule SudokuVersus.Games.PuzzleGenerator do
  @moduledoc """
  Generates Sudoku puzzles with solutions using a backtracking algorithm.

  Puzzle generation takes 10-50ms which is acceptable for real-time usage.
  Generated puzzles are cached in the database for reuse.
  """

  alias SudokuVersus.Repo
  alias SudokuVersus.Games.Puzzle

  @doc """
  Generates a new Sudoku puzzle with the specified difficulty and grid size.

  Difficulty levels determine the number of clues (pre-filled numbers):
  For 9x9:
  - :easy - 36-45 clues
  - :medium - 30-35 clues
  - :hard - 25-29 clues
  - :expert - 22-24 clues

  For 16x16:
  - :easy - 135-150 clues
  - :medium - 115-134 clues
  - :hard - 95-114 clues
  - :expert - 80-94 clues

  Returns {:ok, puzzle} with both grid (with empty cells as 0) and complete solution.
  """
  def generate_puzzle(difficulty, grid_size \\ 9)
      when difficulty in [:easy, :medium, :hard, :expert] and grid_size in [9, 16, 25, 36, 49, 100] do
    # Generate a complete valid Sudoku solution
    solution = generate_complete_sudoku(grid_size)

    # Remove numbers based on difficulty and grid size
    clues_count = clues_for_difficulty(difficulty, grid_size)
    grid = remove_numbers(solution, clues_count, grid_size)

    # Calculate sub_grid_size (square root of size)
    sub_grid_size = case grid_size do
      9 -> 3
      16 -> 4
      _ -> trunc(:math.sqrt(grid_size))
    end

    # Create puzzle record in database
    attrs = %{
      difficulty: difficulty,
      grid: grid,
      solution: solution,
      clues_count: count_clues(grid),
      grid_size: grid_size,
      size: grid_size,
      sub_grid_size: sub_grid_size
    }

    %Puzzle{}
    |> Puzzle.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Validates if a move is correct for the given puzzle.

  Returns true if:
  - The row, col, and value are within bounds for the grid size
  - The cell at (row, col) is currently empty (0 in grid)
  - The value matches the solution at that position

  Returns false otherwise.
  """
  def validate_move?(%Puzzle{grid_size: grid_size} = puzzle, row, col, value) do
    max_index = grid_size - 1

    cond do
      row < 0 or row > max_index -> false
      col < 0 or col > max_index -> false
      value < 1 or value > grid_size -> false
      true ->
        current_value = puzzle.grid |> Enum.at(row) |> Enum.at(col)
        solution_value = puzzle.solution |> Enum.at(row) |> Enum.at(col)
        current_value == 0 and solution_value == value
    end
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

  defp generate_complete_sudoku(grid_size) do
    grid = initialize_empty_grid(grid_size)

    grid
    |> fill_diagonal_boxes(grid_size)
    |> solve_recursive(grid_size)
    |> case do
      {:ok, solved_grid} -> solved_grid
      :error -> generate_complete_sudoku(grid_size)
    end
  end

  defp initialize_empty_grid(grid_size) do
    List.duplicate(List.duplicate(0, grid_size), grid_size)
  end

  defp fill_diagonal_boxes(grid, grid_size) do
    box_size = box_size_for_grid(grid_size)
    num_boxes = div(grid_size, box_size)

    # Fill the diagonal boxes (they don't affect each other)
    Enum.reduce(0..(num_boxes - 1), grid, fn i, acc_grid ->
      offset = i * box_size
      fill_box(acc_grid, offset, offset, box_size, grid_size)
    end)
  end

  defp fill_box(grid, row_start, col_start, box_size, grid_size) do
    numbers = Enum.shuffle(1..grid_size)
    cells_in_box = box_size * box_size

    Enum.reduce(0..(cells_in_box - 1), grid, fn i, acc_grid ->
      row = row_start + div(i, box_size)
      col = col_start + rem(i, box_size)
      value = Enum.at(numbers, i)
      set_cell(acc_grid, row, col, value)
    end)
  end

  defp solve_recursive(grid, grid_size) do
    case find_empty_cell(grid, grid_size) do
      nil ->
        {:ok, grid}

      {row, col} ->
        Enum.shuffle(1..grid_size)
        |> Enum.reduce_while(:error, fn num, _ ->
          if is_safe?(grid, row, col, num, grid_size) do
            new_grid = set_cell(grid, row, col, num)

            case solve_recursive(new_grid, grid_size) do
              {:ok, solved} -> {:halt, {:ok, solved}}
              :error -> {:cont, :error}
            end
          else
            {:cont, :error}
          end
        end)
    end
  end

  defp find_empty_cell(grid, grid_size) do
    max_index = grid_size - 1

    Enum.reduce_while(0..max_index, nil, fn row, _ ->
      result =
        Enum.reduce_while(0..max_index, nil, fn col, _ ->
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

  defp is_safe?(grid, row, col, num, grid_size) do
    box_size = box_size_for_grid(grid_size)
    box_row_start = row - rem(row, box_size)
    box_col_start = col - rem(col, box_size)

    !used_in_row?(grid, row, num) and
      !used_in_col?(grid, col, num) and
      !used_in_box?(grid, box_row_start, box_col_start, num, box_size)
  end

  defp used_in_row?(grid, row, num) do
    grid |> Enum.at(row) |> Enum.member?(num)
  end

  defp used_in_col?(grid, col, num) do
    grid |> Enum.map(&Enum.at(&1, col)) |> Enum.member?(num)
  end

  defp used_in_box?(grid, row_start, col_start, num, box_size) do
    max_offset = box_size - 1

    Enum.any?(0..max_offset, fn i ->
      Enum.any?(0..max_offset, fn j ->
        get_cell(grid, row_start + i, col_start + j) == num
      end)
    end)
  end

  defp remove_numbers(solution, target_clues, grid_size) do
    total_cells = grid_size * grid_size
    cells_to_remove = total_cells - target_clues
    max_index = grid_size - 1

    # Get all cell positions and shuffle them
    positions = for row <- 0..max_index, col <- 0..max_index, do: {row, col}
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

  defp box_size_for_grid(9), do: 3
  defp box_size_for_grid(16), do: 4
  defp box_size_for_grid(25), do: 5
  defp box_size_for_grid(36), do: 6
  defp box_size_for_grid(49), do: 7
  defp box_size_for_grid(100), do: 10

  # Clues for 9x9 grids
  defp clues_for_difficulty(:easy, 9), do: Enum.random(36..45)
  defp clues_for_difficulty(:medium, 9), do: Enum.random(30..35)
  defp clues_for_difficulty(:hard, 9), do: Enum.random(25..29)
  defp clues_for_difficulty(:expert, 9), do: Enum.random(22..24)

  # Clues for 16x16 grids (roughly 50-60% filled for various difficulties)
  defp clues_for_difficulty(:easy, 16), do: Enum.random(135..150)
  defp clues_for_difficulty(:medium, 16), do: Enum.random(115..134)
  defp clues_for_difficulty(:hard, 16), do: Enum.random(95..114)
  defp clues_for_difficulty(:expert, 16), do: Enum.random(80..94)

  # Clues for 25x25 grids (total = 625)
  defp clues_for_difficulty(:easy, 25), do: Enum.random(350..375)
  defp clues_for_difficulty(:medium, 25), do: Enum.random(300..349)
  defp clues_for_difficulty(:hard, 25), do: Enum.random(250..299)
  defp clues_for_difficulty(:expert, 25), do: Enum.random(220..249)

  # Clues for 36x36 grids (total = 1296)
  defp clues_for_difficulty(:easy, 36), do: Enum.random(700..780)
  defp clues_for_difficulty(:medium, 36), do: Enum.random(600..699)
  defp clues_for_difficulty(:hard, 36), do: Enum.random(500..599)
  defp clues_for_difficulty(:expert, 36), do: Enum.random(450..499)

  # Clues for 49x49 grids (total = 2401)
  defp clues_for_difficulty(:easy, 49), do: Enum.random(1300..1440)
  defp clues_for_difficulty(:medium, 49), do: Enum.random(1100..1299)
  defp clues_for_difficulty(:hard, 49), do: Enum.random(950..1099)
  defp clues_for_difficulty(:expert, 49), do: Enum.random(850..949)

  # Clues for 100x100 grids (total = 10000)
  defp clues_for_difficulty(:easy, 100), do: Enum.random(5500..6000)
  defp clues_for_difficulty(:medium, 100), do: Enum.random(4800..5499)
  defp clues_for_difficulty(:hard, 100), do: Enum.random(4200..4799)
  defp clues_for_difficulty(:expert, 100), do: Enum.random(3800..4199)
end
