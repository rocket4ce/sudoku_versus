defmodule SudokuVersus.Games.PuzzleGeneratorTest do
  use SudokuVersus.DataCase

  alias SudokuVersus.Games.PuzzleGenerator

  describe "generate_puzzle/1" do
    test "generates easy puzzle with 36-45 clues" do
      assert {:ok, puzzle} = PuzzleGenerator.generate_puzzle(:easy)

      assert puzzle.difficulty == :easy
      assert puzzle.clues_count >= 36
      assert puzzle.clues_count <= 45
      assert is_list(puzzle.grid)
      assert length(puzzle.grid) == 9
      assert Enum.all?(puzzle.grid, &(length(&1) == 9))
    end

    test "generates medium puzzle with 30-35 clues" do
      assert {:ok, puzzle} = PuzzleGenerator.generate_puzzle(:medium)

      assert puzzle.difficulty == :medium
      assert puzzle.clues_count >= 30
      assert puzzle.clues_count <= 35
    end

    test "generates hard puzzle with 25-29 clues" do
      assert {:ok, puzzle} = PuzzleGenerator.generate_puzzle(:hard)

      assert puzzle.difficulty == :hard
      assert puzzle.clues_count >= 25
      assert puzzle.clues_count <= 29
    end

    test "generates expert puzzle with 22-24 clues" do
      assert {:ok, puzzle} = PuzzleGenerator.generate_puzzle(:expert)

      assert puzzle.difficulty == :expert
      assert puzzle.clues_count >= 22
      assert puzzle.clues_count <= 24
    end

    test "generated puzzle has valid solution" do
      assert {:ok, puzzle} = PuzzleGenerator.generate_puzzle(:medium)

      # Solution should be complete (no zeros)
      flat_solution = List.flatten(puzzle.solution)
      assert Enum.all?(flat_solution, &(&1 in 1..9))

      # Grid should have zeros (empty cells)
      flat_grid = List.flatten(puzzle.grid)
      assert Enum.any?(flat_grid, &(&1 == 0))
    end
  end

  describe "validate_move?/4" do
    setup do
      {:ok, puzzle} = PuzzleGenerator.generate_puzzle(:easy)
      %{puzzle: puzzle}
    end

    test "returns true for correct move", %{puzzle: puzzle} do
      # Find an empty cell and its correct value
      {row, col, value} = find_empty_cell_with_solution(puzzle)

      assert PuzzleGenerator.validate_move?(puzzle, row, col, value) == true
    end

    test "returns false for incorrect move", %{puzzle: puzzle} do
      # Find an empty cell and provide wrong value
      {row, col, _correct_value} = find_empty_cell_with_solution(puzzle)
      wrong_value = get_wrong_value(puzzle, row, col)

      assert PuzzleGenerator.validate_move?(puzzle, row, col, wrong_value) == false
    end

    test "returns false when cell is already filled", %{puzzle: puzzle} do
      # Find a filled cell
      {row, col} = find_filled_cell(puzzle)

      assert PuzzleGenerator.validate_move?(puzzle, row, col, 5) == false
    end
  end

  describe "cache_solution/1" do
    test "returns map with index keys for O(1) lookup" do
      {:ok, puzzle} = PuzzleGenerator.generate_puzzle(:easy)

      cache = PuzzleGenerator.cache_solution(puzzle)

      assert is_map(cache)
      assert map_size(cache) == 81

      # Verify all 81 cells are cached
      for row <- 0..8, col <- 0..8 do
        index = row * 9 + col
        assert Map.has_key?(cache, index)
        assert cache[index] in 1..9
      end
    end
  end

  # Helper functions
  defp find_empty_cell_with_solution(puzzle) do
    Enum.reduce_while(0..8, nil, fn row, _ ->
      Enum.reduce_while(0..8, nil, fn col, _ ->
        if Enum.at(Enum.at(puzzle.grid, row), col) == 0 do
          value = Enum.at(Enum.at(puzzle.solution, row), col)
          {:halt, {:halt, {row, col, value}}}
        else
          {:cont, nil}
        end
      end)
    end)
  end

  defp find_filled_cell(puzzle) do
    Enum.reduce_while(0..8, nil, fn row, _ ->
      Enum.reduce_while(0..8, nil, fn col, _ ->
        if Enum.at(Enum.at(puzzle.grid, row), col) != 0 do
          {:halt, {:halt, {row, col}}}
        else
          {:cont, nil}
        end
      end)
    end)
  end

  defp get_wrong_value(puzzle, row, col) do
    correct_value = Enum.at(Enum.at(puzzle.solution, row), col)
    # Return a different value (1-9) that's not the correct one
    Enum.find(1..9, fn v -> v != correct_value end)
  end
end
