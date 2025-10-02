defmodule SudokuVersus.Puzzles.ValidatorTest do
  use ExUnit.Case, async: true

  alias SudokuVersus.Puzzles.Validator

  describe "validate_move/4 - correctness" do
    setup do
      # Create a simple 9x9 puzzle for testing
      # Solution is a valid Sudoku grid
      solution = [
        1, 2, 3, 4, 5, 6, 7, 8, 9,
        4, 5, 6, 7, 8, 9, 1, 2, 3,
        7, 8, 9, 1, 2, 3, 4, 5, 6,
        2, 3, 4, 5, 6, 7, 8, 9, 1,
        5, 6, 7, 8, 9, 1, 2, 3, 4,
        8, 9, 1, 2, 3, 4, 5, 6, 7,
        3, 4, 5, 6, 7, 8, 9, 1, 2,
        6, 7, 8, 9, 1, 2, 3, 4, 5,
        9, 1, 2, 3, 4, 5, 6, 7, 8
      ]

      puzzle = %{size: 9, solution: solution}
      {:ok, puzzle: puzzle}
    end

    test "validates correct move returns true", %{puzzle: puzzle} do
      # Cell (0,0) should be 1
      assert {:ok, true} = Validator.validate_move(puzzle, 0, 0, 1)
    end

    test "validates incorrect move returns false", %{puzzle: puzzle} do
      # Cell (0,0) is 1, not 5
      assert {:ok, false} = Validator.validate_move(puzzle, 0, 0, 5)
    end

    test "validates correct move at different position", %{puzzle: puzzle} do
      # Cell (4,4) should be 9 (center of grid)
      assert {:ok, true} = Validator.validate_move(puzzle, 4, 4, 9)
    end

    test "validates incorrect move at different position", %{puzzle: puzzle} do
      # Cell (4,4) is 9, not 1
      assert {:ok, false} = Validator.validate_move(puzzle, 4, 4, 1)
    end

    test "validates last cell correctly", %{puzzle: puzzle} do
      # Cell (8,8) should be 8 (last cell)
      assert {:ok, true} = Validator.validate_move(puzzle, 8, 8, 8)
    end
  end

  describe "validate_move/4 - performance" do
    setup do
      # Create 100x100 puzzle solution for performance testing
      size = 100
      # For simplicity, create a pattern-based solution (not valid Sudoku, but tests performance)
      solution = for i <- 0..(size * size - 1), do: rem(i, size) + 1

      puzzle = %{size: size, solution: solution}
      {:ok, puzzle: puzzle}
    end

    test "validates move in <5ms for large puzzle", %{puzzle: puzzle} do
      {time_us, result} = :timer.tc(fn ->
        Validator.validate_move(puzzle, 50, 50, 51)
      end)
      time_ms = time_us / 1000

      assert {:ok, _} = result
      assert time_ms < 5, "Expected <5ms, got #{time_ms}ms"
    end

    test "validates multiple moves quickly", %{puzzle: puzzle} do
      {time_us, _} = :timer.tc(fn ->
        for _ <- 1..100 do
          Validator.validate_move(puzzle, 10, 10, 11)
        end
      end)
      avg_time_ms = time_us / 100 / 1000

      assert avg_time_ms < 5, "Average validation time #{avg_time_ms}ms exceeds 5ms"
    end
  end

  describe "validate_move/4 - error handling" do
    setup do
      solution = List.duplicate(1, 81)
      puzzle = %{size: 9, solution: solution}
      {:ok, puzzle: puzzle}
    end

    test "returns error for row < 0", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, -1, 0, 1)
      assert reason =~ "Invalid row"
    end

    test "returns error for row >= size", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, 9, 0, 1)
      assert reason =~ "Invalid row"
    end

    test "returns error for row > size", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, 10, 0, 1)
      assert reason =~ "Invalid row"
    end

    test "returns error for col < 0", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, 0, -1, 1)
      assert reason =~ "Invalid col"
    end

    test "returns error for col >= size", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, 0, 9, 1)
      assert reason =~ "Invalid col"
    end

    test "returns error for col > size", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, 0, 10, 1)
      assert reason =~ "Invalid col"
    end

    test "returns error for value < 1", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, 0, 0, 0)
      assert reason =~ "Invalid value"
    end

    test "returns error for value > size", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, 0, 0, 10)
      assert reason =~ "Invalid value"
    end

    test "returns error for negative value", %{puzzle: puzzle} do
      assert {:error, reason} = Validator.validate_move(puzzle, 0, 0, -5)
      assert reason =~ "Invalid value"
    end
  end

  describe "validate_move/4 - different puzzle sizes" do
    test "validates 16x16 puzzle correctly" do
      solution = for i <- 0..255, do: rem(i, 16) + 1
      puzzle = %{size: 16, solution: solution}

      assert {:ok, true} = Validator.validate_move(puzzle, 0, 0, 1)
      assert {:ok, false} = Validator.validate_move(puzzle, 0, 0, 5)
    end

    test "validates 25x25 puzzle correctly" do
      solution = for i <- 0..624, do: rem(i, 25) + 1
      puzzle = %{size: 25, solution: solution}

      assert {:ok, true} = Validator.validate_move(puzzle, 0, 0, 1)
      assert {:ok, false} = Validator.validate_move(puzzle, 0, 0, 10)
    end

    test "validates boundary correctly for different sizes" do
      for size <- [9, 16, 25, 36, 49, 100] do
        solution = for i <- 0..(size * size - 1), do: rem(i, size) + 1
        puzzle = %{size: size, solution: solution}

        # Last valid position
        assert {:ok, _} = Validator.validate_move(puzzle, size - 1, size - 1, size)

        # Out of bounds
        assert {:error, _} = Validator.validate_move(puzzle, size, 0, 1)
        assert {:error, _} = Validator.validate_move(puzzle, 0, size, 1)
      end
    end
  end
end
