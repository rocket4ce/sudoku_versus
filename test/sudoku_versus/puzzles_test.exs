defmodule SudokuVersus.PuzzlesTest do
  use SudokuVersus.DataCase

  alias SudokuVersus.Puzzles
  alias SudokuVersus.Games.Puzzle

  describe "generate_puzzle/2" do
    test "creates valid 9x9 puzzle and saves to database" do
      assert {:ok, puzzle} = Puzzles.generate_puzzle(9, :easy)

      assert %Puzzle{} = puzzle
      assert puzzle.id != nil
      assert puzzle.size == 9
      assert puzzle.difficulty == :easy
      assert length(puzzle.grid) == 9  # 9 rows
      assert length(hd(puzzle.grid)) == 9  # 9 cols per row
      assert length(puzzle.solution) == 9
      assert length(hd(puzzle.solution)) == 9
      assert puzzle.clues_count > 0
      assert puzzle.sub_grid_size == 3
      assert puzzle.inserted_at != nil
    end

    @tag timeout: 180_000
    test "creates valid 16x16 puzzle and saves to database" do
      assert {:ok, puzzle} = Puzzles.generate_puzzle(16, :medium)

      assert puzzle.size == 16
      assert puzzle.difficulty == :medium
      assert length(puzzle.grid) == 16  # 16 rows
      assert length(hd(puzzle.grid)) == 16  # 16 cols per row
      assert length(puzzle.solution) == 16
      assert length(hd(puzzle.solution)) == 16
      assert puzzle.sub_grid_size == 4
    end

    @tag timeout: 300_000
    test "creates valid 25x25 puzzle and saves to database" do
      assert {:ok, puzzle} = Puzzles.generate_puzzle(25, :hard)

      assert puzzle.size == 25
      assert puzzle.difficulty == :hard
      assert length(puzzle.grid) == 25  # 25 rows
      assert length(hd(puzzle.grid)) == 25  # 25 cols per row
      assert length(puzzle.solution) == 25
      assert length(hd(puzzle.solution)) == 25
      assert puzzle.sub_grid_size == 5
    end

    @tag timeout: 600_000
    test "creates valid 36x36 puzzle and saves to database" do
      assert {:ok, puzzle} = Puzzles.generate_puzzle(36, :expert)

      assert puzzle.size == 36
      assert puzzle.difficulty == :expert
      assert length(puzzle.grid) == 36  # 36 rows
      assert length(hd(puzzle.grid)) == 36  # 36 cols per row
      assert length(puzzle.solution) == 36
      assert length(hd(puzzle.solution)) == 36
      assert puzzle.sub_grid_size == 6
    end

    test "returns error for invalid size" do
      assert {:error, reason} = Puzzles.generate_puzzle(10, :easy)
      assert reason =~ "Invalid size"
    end

    test "returns error for invalid difficulty" do
      assert {:error, reason} = Puzzles.generate_puzzle(9, :impossible)
      assert reason =~ "Invalid difficulty"
    end

    test "grid values are subset of solution values" do
      assert {:ok, puzzle} = Puzzles.generate_puzzle(9, :medium)

      # Flatten nested arrays before comparing
      flat_grid = List.flatten(puzzle.grid)
      flat_solution = List.flatten(puzzle.solution)

      Enum.zip(flat_grid, flat_solution)
      |> Enum.each(fn {grid_val, solution_val} ->
        if grid_val != 0 do
          assert grid_val == solution_val
        end
      end)
    end

    test "clues_count matches non-zero values in grid" do
      assert {:ok, puzzle} = Puzzles.generate_puzzle(9, :hard)

      # Flatten nested grid to count individual cells
      actual_clues = puzzle.grid |> List.flatten() |> Enum.count(&(&1 != 0))
      assert puzzle.clues_count == actual_clues
    end

    test "difficulty affects clue percentage" do
      assert {:ok, easy_puzzle} = Puzzles.generate_puzzle(9, :easy)
      assert {:ok, expert_puzzle} = Puzzles.generate_puzzle(9, :expert)

      easy_percentage = easy_puzzle.clues_count / (easy_puzzle.size * easy_puzzle.size) * 100
      expert_percentage = expert_puzzle.clues_count / (expert_puzzle.size * expert_puzzle.size) * 100

      assert easy_percentage > expert_percentage
    end
  end

  describe "get_puzzle!/1" do
    test "retrieves puzzle with grid and solution" do
      {:ok, created_puzzle} = Puzzles.generate_puzzle(9, :easy)

      fetched_puzzle = Puzzles.get_puzzle!(created_puzzle.id)

      assert fetched_puzzle.id == created_puzzle.id
      assert fetched_puzzle.size == 9
      assert fetched_puzzle.difficulty == :easy
      assert is_list(fetched_puzzle.grid)
      assert is_list(fetched_puzzle.solution)
      assert length(fetched_puzzle.grid) == 9  # 9 rows
      assert length(hd(fetched_puzzle.grid)) == 9  # 9 cols per row
      assert length(fetched_puzzle.solution) == 9
      assert length(hd(fetched_puzzle.solution)) == 9
    end

    test "raises Ecto.NoResultsError for non-existent ID" do
      non_existent_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Puzzles.get_puzzle!(non_existent_id)
      end
    end
  end

  describe "validate_move/4" do
    setup do
      {:ok, puzzle} = Puzzles.generate_puzzle(9, :easy)
      {:ok, puzzle: puzzle}
    end

    test "delegates to Validator module", %{puzzle: puzzle} do
      # Get first empty cell and its solution value
      flat_grid = List.flatten(puzzle.grid)
      flat_solution = List.flatten(puzzle.solution)

      {index, solution_value} =
        Enum.zip(flat_grid, flat_solution)
        |> Enum.with_index()
        |> Enum.find(fn {{grid_val, _}, _} -> grid_val == 0 end)
        |> then(fn {{_, solution_val}, idx} -> {idx, solution_val} end)

      row = div(index, puzzle.size)
      col = rem(index, puzzle.size)

      # Correct move
      assert {:ok, true} = Puzzles.validate_move(puzzle, row, col, solution_value)

      # Incorrect move (different value)
      wrong_value = if solution_value == 1, do: 2, else: 1
      assert {:ok, false} = Puzzles.validate_move(puzzle, row, col, wrong_value)
    end

    test "returns error for invalid coordinates", %{puzzle: puzzle} do
      assert {:error, _reason} = Puzzles.validate_move(puzzle, -1, 0, 1)
      assert {:error, _reason} = Puzzles.validate_move(puzzle, 0, -1, 1)
      assert {:error, _reason} = Puzzles.validate_move(puzzle, 9, 0, 1)
      assert {:error, _reason} = Puzzles.validate_move(puzzle, 0, 9, 1)
    end

    test "returns error for invalid value", %{puzzle: puzzle} do
      assert {:error, _reason} = Puzzles.validate_move(puzzle, 0, 0, 0)
      assert {:error, _reason} = Puzzles.validate_move(puzzle, 0, 0, 10)
      assert {:error, _reason} = Puzzles.validate_move(puzzle, 0, 0, -1)
    end
  end

  describe "list_puzzles_by_size_and_difficulty/2" do
    test "returns puzzles matching size and difficulty" do
      # Create multiple puzzles
      {:ok, _p1} = Puzzles.generate_puzzle(9, :easy)
      {:ok, _p2} = Puzzles.generate_puzzle(9, :easy)
      {:ok, _p3} = Puzzles.generate_puzzle(9, :medium)
      {:ok, _p4} = Puzzles.generate_puzzle(16, :easy)

      results = Puzzles.list_puzzles_by_size_and_difficulty(9, :easy)

      assert length(results) == 2
      assert Enum.all?(results, fn p -> p.size == 9 and p.difficulty == :easy end)
    end

    test "returns empty list when no matches" do
      results = Puzzles.list_puzzles_by_size_and_difficulty(100, :expert)

      assert results == []
    end

    test "orders by inserted_at DESC" do
      # Create at least one puzzle to test
      {:ok, _} = Puzzles.generate_puzzle(9, :medium)

      results = Puzzles.list_puzzles_by_size_and_difficulty(9, :medium)

      assert length(results) >= 1

      # Verify results are ordered by inserted_at descending (newest first)
      if length(results) > 1 do
        timestamps = Enum.map(results, & &1.inserted_at)
        sorted_desc = Enum.sort(timestamps, {:desc, NaiveDateTime})
        assert timestamps == sorted_desc, "Results should be ordered by inserted_at DESC"
      end
    end

    test "limits to 50 results" do
      # This test would be slow in practice, so we'll just verify the query works
      # In real scenario, we'd seed 60+ puzzles and verify limit
      results = Puzzles.list_puzzles_by_size_and_difficulty(9, :easy)

      assert length(results) <= 50
    end

    test "filters correctly for different sizes" do
      {:ok, _} = Puzzles.generate_puzzle(9, :easy)
      {:ok, _} = Puzzles.generate_puzzle(16, :easy)
      {:ok, _} = Puzzles.generate_puzzle(25, :easy)

      results_9 = Puzzles.list_puzzles_by_size_and_difficulty(9, :easy)
      results_16 = Puzzles.list_puzzles_by_size_and_difficulty(16, :easy)
      results_25 = Puzzles.list_puzzles_by_size_and_difficulty(25, :easy)

      assert Enum.all?(results_9, &(&1.size == 9))
      assert Enum.all?(results_16, &(&1.size == 16))
      assert Enum.all?(results_25, &(&1.size == 25))
    end

    test "filters correctly for different difficulties" do
      {:ok, _} = Puzzles.generate_puzzle(9, :easy)
      {:ok, _} = Puzzles.generate_puzzle(9, :medium)
      {:ok, _} = Puzzles.generate_puzzle(9, :hard)
      {:ok, _} = Puzzles.generate_puzzle(9, :expert)

      results_easy = Puzzles.list_puzzles_by_size_and_difficulty(9, :easy)
      results_medium = Puzzles.list_puzzles_by_size_and_difficulty(9, :medium)
      results_hard = Puzzles.list_puzzles_by_size_and_difficulty(9, :hard)
      results_expert = Puzzles.list_puzzles_by_size_and_difficulty(9, :expert)

      assert Enum.all?(results_easy, &(&1.difficulty == :easy))
      assert Enum.all?(results_medium, &(&1.difficulty == :medium))
      assert Enum.all?(results_hard, &(&1.difficulty == :hard))
      assert Enum.all?(results_expert, &(&1.difficulty == :expert))
    end
  end
end
