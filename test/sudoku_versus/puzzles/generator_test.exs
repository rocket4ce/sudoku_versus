defmodule SudokuVersus.Puzzles.GeneratorTest do
  use ExUnit.Case, async: true

  alias SudokuVersus.Puzzles.Generator

  describe "generate/2 - performance and correctness" do
    test "generates 9x9 easy puzzle in <50ms" do
      {time_us, result} = :timer.tc(fn -> Generator.generate(9, :easy) end)
      time_ms = time_us / 1000

      assert {:ok, puzzle_data} = result
      assert time_ms < 50, "Expected <50ms, got #{time_ms}ms"
      assert length(puzzle_data.grid) == 81
      assert length(puzzle_data.solution) == 81
    end

    test "generates 16x16 medium puzzle in <100ms" do
      {time_us, result} = :timer.tc(fn -> Generator.generate(16, :medium) end)
      time_ms = time_us / 1000

      assert {:ok, puzzle_data} = result
      assert time_ms < 100, "Expected <100ms, got #{time_ms}ms"
      assert length(puzzle_data.grid) == 256
      assert length(puzzle_data.solution) == 256
    end

    test "generates 25x25 hard puzzle in <500ms" do
      {time_us, result} = :timer.tc(fn -> Generator.generate(25, :hard) end)
      time_ms = time_us / 1000

      assert {:ok, puzzle_data} = result
      assert time_ms < 500, "Expected <500ms, got #{time_ms}ms"
      assert length(puzzle_data.grid) == 625
      assert length(puzzle_data.solution) == 625
    end

    test "generates 36x36 expert puzzle in <1s" do
      {time_us, result} = :timer.tc(fn -> Generator.generate(36, :expert) end)
      time_ms = time_us / 1000

      assert {:ok, puzzle_data} = result
      assert time_ms < 1000, "Expected <1000ms, got #{time_ms}ms"
      assert length(puzzle_data.grid) == 1296
      assert length(puzzle_data.solution) == 1296
    end

    @tag timeout: 10_000
    test "generates 49x49 easy puzzle in <2s" do
      {time_us, result} = :timer.tc(fn -> Generator.generate(49, :easy) end)
      time_ms = time_us / 1000

      assert {:ok, puzzle_data} = result
      assert time_ms < 2000, "Expected <2000ms, got #{time_ms}ms"
      assert length(puzzle_data.grid) == 2401
      assert length(puzzle_data.solution) == 2401
    end

    @tag timeout: 15_000
    test "generates 100x100 expert puzzle in <5s" do
      {time_us, result} = :timer.tc(fn -> Generator.generate(100, :expert) end)
      time_ms = time_us / 1000

      assert {:ok, puzzle_data} = result
      assert time_ms < 5000, "Expected <5000ms, got #{time_ms}ms"
      assert length(puzzle_data.grid) == 10_000
      assert length(puzzle_data.solution) == 10_000
    end
  end

  describe "generate/2 - error handling" do
    test "returns error for invalid size (10)" do
      assert {:error, reason} = Generator.generate(10, :easy)
      assert reason =~ "Invalid size"
    end

    test "returns error for invalid difficulty" do
      assert {:error, reason} = Generator.generate(9, :impossible)
      assert reason =~ "Invalid difficulty"
    end
  end

  describe "generate/2 - grid and solution validation" do
    test "grid and solution have correct lengths for 9x9" do
      assert {:ok, puzzle_data} = Generator.generate(9, :medium)

      assert length(puzzle_data.grid) == 81
      assert length(puzzle_data.solution) == 81
    end

    test "grid and solution have correct lengths for 16x16" do
      assert {:ok, puzzle_data} = Generator.generate(16, :hard)

      assert length(puzzle_data.grid) == 256
      assert length(puzzle_data.solution) == 256
    end

    test "grid values are subset of solution values" do
      assert {:ok, puzzle_data} = Generator.generate(9, :easy)

      # Check each grid cell matches solution if non-zero
      Enum.zip(puzzle_data.grid, puzzle_data.solution)
      |> Enum.each(fn {grid_val, solution_val} ->
        if grid_val != 0 do
          assert grid_val == solution_val,
            "Grid clue #{grid_val} doesn't match solution #{solution_val}"
        end
      end)
    end

    test "solution contains values in valid range (1 to size)" do
      assert {:ok, puzzle_data} = Generator.generate(9, :medium)

      # All solution values should be between 1 and 9
      Enum.each(puzzle_data.solution, fn value ->
        assert value >= 1 and value <= 9,
          "Solution value #{value} out of range 1..9"
      end)
    end

    test "solution is valid Sudoku - each row contains 1..N exactly once" do
      assert {:ok, puzzle_data} = Generator.generate(9, :easy)
      size = 9

      # Check each row
      0..(size - 1)
      |> Enum.each(fn row ->
        row_values =
          0..(size - 1)
          |> Enum.map(fn col -> Enum.at(puzzle_data.solution, row * size + col) end)
          |> Enum.sort()

        assert row_values == Enum.to_list(1..size),
          "Row #{row} doesn't contain 1..#{size} exactly once"
      end)
    end

    test "solution is valid Sudoku - each column contains 1..N exactly once" do
      assert {:ok, puzzle_data} = Generator.generate(9, :medium)
      size = 9

      # Check each column
      0..(size - 1)
      |> Enum.each(fn col ->
        col_values =
          0..(size - 1)
          |> Enum.map(fn row -> Enum.at(puzzle_data.solution, row * size + col) end)
          |> Enum.sort()

        assert col_values == Enum.to_list(1..size),
          "Column #{col} doesn't contain 1..#{size} exactly once"
      end)
    end

    test "solution is valid Sudoku - each 3x3 sub-grid contains 1..9 exactly once" do
      assert {:ok, puzzle_data} = Generator.generate(9, :hard)
      size = 9
      sub_grid_size = 3

      # Check each 3x3 sub-grid
      for box_row <- 0..(sub_grid_size - 1),
          box_col <- 0..(sub_grid_size - 1) do

        sub_grid_values =
          for row <- 0..(sub_grid_size - 1),
              col <- 0..(sub_grid_size - 1) do
            actual_row = box_row * sub_grid_size + row
            actual_col = box_col * sub_grid_size + col
            Enum.at(puzzle_data.solution, actual_row * size + actual_col)
          end
          |> Enum.sort()

        assert sub_grid_values == Enum.to_list(1..size),
          "Sub-grid (#{box_row},#{box_col}) doesn't contain 1..#{size} exactly once"
      end
    end

    test "grid contains zeros for empty cells" do
      assert {:ok, puzzle_data} = Generator.generate(9, :expert)

      zero_count = Enum.count(puzzle_data.grid, &(&1 == 0))
      assert zero_count > 0, "Expert puzzle should have empty cells"
    end

    test "difficulty affects clue count - easy has more clues than expert" do
      assert {:ok, easy_data} = Generator.generate(9, :easy)
      assert {:ok, expert_data} = Generator.generate(9, :expert)

      easy_clues = Enum.count(easy_data.grid, &(&1 != 0))
      expert_clues = Enum.count(expert_data.grid, &(&1 != 0))

      assert easy_clues > expert_clues,
        "Easy (#{easy_clues} clues) should have more clues than Expert (#{expert_clues} clues)"
    end
  end
end
