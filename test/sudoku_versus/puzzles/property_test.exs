defmodule SudokuVersus.Puzzles.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias SudokuVersus.Puzzles.Generator

  @moduledoc """
  Property-based tests for puzzle generation using StreamData.
  These tests verify invariants that should hold for ALL generated puzzles.
  """

  describe "puzzle validity properties" do
    @tag timeout: 120_000
    property "all generated 9x9 puzzles have valid solutions" do
      check all(
              difficulty <- member_of([:easy, :medium, :hard, :expert]),
              max_runs: 20
            ) do
        assert {:ok, puzzle_data} = Generator.generate(9, difficulty)

        # Solution satisfies all Sudoku constraints
        assert valid_sudoku_solution?(puzzle_data.solution, 9, 3)
      end
    end

    @tag timeout: 120_000
    property "grid values are always subset of solution values" do
      check all(
              size <- member_of([9, 16, 25]),
              difficulty <- member_of([:easy, :medium, :hard, :expert]),
              max_runs: 15
            ) do
        sub_grid_size = trunc(:math.sqrt(size))
        assert {:ok, puzzle_data} = Generator.generate(size, difficulty)

        # Every non-zero grid value must match solution
        Enum.zip(puzzle_data.grid, puzzle_data.solution)
        |> Enum.with_index()
        |> Enum.each(fn {{grid_val, solution_val}, index} ->
          if grid_val != 0 do
            assert grid_val == solution_val,
                   "Grid[#{index}]=#{grid_val} doesn't match Solution[#{index}]=#{solution_val}"
          end
        end)

        # Solution is valid
        assert valid_sudoku_solution?(puzzle_data.solution, size, sub_grid_size)
      end
    end

    @tag timeout: 120_000
    property "clue count matches difficulty percentage ranges" do
      check all(
              size <- member_of([9, 16]),
              difficulty <- member_of([:easy, :medium, :hard, :expert]),
              max_runs: 10
            ) do
        assert {:ok, puzzle_data} = Generator.generate(size, difficulty)

        total_cells = size * size
        clue_count = Enum.count(puzzle_data.grid, &(&1 != 0))
        clue_percentage = clue_count / total_cells * 100

        # Define expected ranges per difficulty
        {min_pct, max_pct} =
          case difficulty do
            :easy -> {50, 60}
            :medium -> {35, 45}
            :hard -> {25, 35}
            :expert -> {20, 25}
          end

        assert clue_percentage >= min_pct - 5 and clue_percentage <= max_pct + 5,
               "#{difficulty} puzzle has #{clue_percentage}% clues (expected #{min_pct}-#{max_pct}%)"
      end
    end

    @tag timeout: 120_000
    property "sub_grid_size is always sqrt(N) for all sizes" do
      check all(
              size <- member_of([9, 16, 25, 36, 49, 100]),
              difficulty <- member_of([:easy, :hard]),
              max_runs: 6
            ) do
        assert {:ok, puzzle_data} = Generator.generate(size, difficulty)

        expected_sub_grid_size = trunc(:math.sqrt(size))

        # Verify the puzzle can be logically divided into sub-grids
        # This is implicit in the generation, but we verify by checking solution validity
        assert valid_sudoku_solution?(puzzle_data.solution, size, expected_sub_grid_size)
      end
    end

    @tag timeout: 120_000
    property "solution values are always in range 1..N" do
      check all(
              size <- member_of([9, 16, 25]),
              difficulty <- member_of([:easy, :expert]),
              max_runs: 10
            ) do
        assert {:ok, puzzle_data} = Generator.generate(size, difficulty)

        # All solution values in range
        Enum.each(puzzle_data.solution, fn value ->
          assert value >= 1 and value <= size,
                 "Solution value #{value} out of range 1..#{size}"
        end)
      end
    end

    @tag timeout: 120_000
    property "grid values are always 0 or in range 1..N" do
      check all(
              size <- member_of([9, 16]),
              difficulty <- member_of([:medium, :expert]),
              max_runs: 10
            ) do
        assert {:ok, puzzle_data} = Generator.generate(size, difficulty)

        # All grid values are 0 (empty) or 1..N (clue)
        Enum.each(puzzle_data.grid, fn value ->
          assert (value == 0 or (value >= 1 and value <= size)),
                 "Grid value #{value} invalid (expected 0 or 1..#{size})"
        end)
      end
    end

    @tag timeout: 180_000
    property "generated puzzles have consistent dimensions" do
      check all(
              size <- member_of([9, 16, 25, 36]),
              difficulty <- member_of([:easy, :medium, :hard, :expert]),
              max_runs: 8
            ) do
        assert {:ok, puzzle_data} = Generator.generate(size, difficulty)

        # Grid and solution have correct length
        assert length(puzzle_data.grid) == size * size,
               "Grid length #{length(puzzle_data.grid)} != #{size * size}"

        assert length(puzzle_data.solution) == size * size,
               "Solution length #{length(puzzle_data.solution)} != #{size * size}"
      end
    end
  end

  describe "uniqueness property (expensive)" do
    @tag timeout: 300_000
    @tag :slow
    test "9x9 expert puzzles have exactly one solution" do
      # This is expensive to verify, so we only test a few samples
      for _ <- 1..3 do
        assert {:ok, puzzle_data} = Generator.generate(9, :expert)

        # Count solutions (this is a brute-force solver, very slow)
        solution_count = count_solutions(puzzle_data.grid, 9, 3)

        assert solution_count == 1,
               "Puzzle has #{solution_count} solutions (expected 1)"
      end
    end
  end

  # Helper: Validate that a solution satisfies all Sudoku constraints
  defp valid_sudoku_solution?(solution, size, sub_grid_size) do
    # Check all rows
    rows_valid =
      0..(size - 1)
      |> Enum.all?(fn row ->
        row_values =
          0..(size - 1)
          |> Enum.map(fn col -> Enum.at(solution, row * size + col) end)

        unique_and_complete?(row_values, size)
      end)

    # Check all columns
    cols_valid =
      0..(size - 1)
      |> Enum.all?(fn col ->
        col_values =
          0..(size - 1)
          |> Enum.map(fn row -> Enum.at(solution, row * size + col) end)

        unique_and_complete?(col_values, size)
      end)

    # Check all sub-grids
    sub_grids_valid =
      for(
        box_row <- 0..(div(size, sub_grid_size) - 1),
        box_col <- 0..(div(size, sub_grid_size) - 1),
        do: {box_row, box_col}
      )
      |> Enum.all?(fn {box_row, box_col} ->
        sub_grid_values =
          for(
            row <- 0..(sub_grid_size - 1),
            col <- 0..(sub_grid_size - 1)
          ) do
            actual_row = box_row * sub_grid_size + row
            actual_col = box_col * sub_grid_size + col
            Enum.at(solution, actual_row * size + actual_col)
          end

        unique_and_complete?(sub_grid_values, size)
      end)

    rows_valid and cols_valid and sub_grids_valid
  end

  # Helper: Check if values contain 1..N exactly once
  defp unique_and_complete?(values, size) do
    sorted = Enum.sort(values)
    expected = Enum.to_list(1..size)
    sorted == expected
  end

  # Helper: Count solutions (brute-force backtracking solver)
  # WARNING: Very slow for large puzzles!
  defp count_solutions(grid, size, sub_grid_size) do
    # Convert grid to mutable structure for backtracking
    grid_map =
      grid
      |> Enum.with_index()
      |> Enum.into(%{}, fn {val, idx} -> {idx, val} end)

    empty_cells = Enum.filter(0..(size * size - 1), fn idx -> Map.get(grid_map, idx) == 0 end)

    count_solutions_backtrack(grid_map, empty_cells, size, sub_grid_size, 0, 0)
  end

  defp count_solutions_backtrack(_grid_map, [], _size, _sub_grid_size, _index, count) do
    # Found a complete solution
    count + 1
  end

  defp count_solutions_backtrack(grid_map, [cell_idx | rest], size, sub_grid_size, _index, count) do
    # Try each value 1..size
    Enum.reduce(1..size, count, fn value, acc_count ->
      if acc_count >= 2 do
        # Early exit if we found 2+ solutions (puzzle is invalid)
        acc_count
      else
        if can_place_value?(grid_map, cell_idx, value, size, sub_grid_size) do
          new_grid_map = Map.put(grid_map, cell_idx, value)

          count_solutions_backtrack(new_grid_map, rest, size, sub_grid_size, cell_idx, acc_count)
        else
          acc_count
        end
      end
    end)
  end

  defp can_place_value?(grid_map, cell_idx, value, size, sub_grid_size) do
    row = div(cell_idx, size)
    col = rem(cell_idx, size)

    # Check row
    row_valid =
      Enum.all?(0..(size - 1), fn c ->
        idx = row * size + c
        idx == cell_idx or Map.get(grid_map, idx) != value
      end)

    # Check column
    col_valid =
      Enum.all?(0..(size - 1), fn r ->
        idx = r * size + col
        idx == cell_idx or Map.get(grid_map, idx) != value
      end)

    # Check sub-grid
    box_row = div(row, sub_grid_size)
    box_col = div(col, sub_grid_size)

    sub_grid_valid =
      Enum.all?(0..(sub_grid_size - 1), fn dr ->
        Enum.all?(0..(sub_grid_size - 1), fn dc ->
          r = box_row * sub_grid_size + dr
          c = box_col * sub_grid_size + dc
          idx = r * size + c
          idx == cell_idx or Map.get(grid_map, idx) != value
        end)
      end)

    row_valid and col_valid and sub_grid_valid
  end
end
