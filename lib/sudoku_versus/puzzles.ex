defmodule SudokuVersus.Puzzles do
  @moduledoc """
  The Puzzles context provides high-performance puzzle generation and validation.

  This context manages:
  - On-demand puzzle generation using Rust NIF for optimal performance
  - O(1) move validation using pre-computed solutions
  - Multi-size puzzle support (9×9, 16×16, 25×25, 36×36, 49×49, 100×100)
  - Four difficulty levels (easy, medium, hard, expert)
  """

  import Ecto.Query, warn: false
  alias SudokuVersus.Repo
  alias SudokuVersus.Games.Puzzle
  alias SudokuVersus.Puzzles.{Generator, Validator}

  @doc """
  Generates a new puzzle with pre-computed solution using Rust NIF.

  Creates a puzzle of the specified size and difficulty, saves it to the database,
  and returns the puzzle struct with all fields populated.

  ## Parameters

    * `size` - Grid dimension (9, 16, 25, 36, 49, or 100)
    * `difficulty` - Difficulty level (:easy, :medium, :hard, or :expert)

  ## Returns

    * `{:ok, %Puzzle{}}` - Successfully generated and saved puzzle
    * `{:error, reason}` - Generation failed or invalid parameters

  ## Examples

      iex> Puzzles.generate_puzzle(9, :easy)
      {:ok, %Puzzle{size: 9, difficulty: :easy, ...}}

      iex> Puzzles.generate_puzzle(16, :medium)
      {:ok, %Puzzle{size: 16, difficulty: :medium, ...}}

      iex> Puzzles.generate_puzzle(10, :easy)
      {:error, "Invalid size"}
  """
  @spec generate_puzzle(integer(), atom()) :: {:ok, Puzzle.t()} | {:error, String.t()}
  def generate_puzzle(size, difficulty) when size in [9, 16, 25, 36, 49, 100] do
    # Validate difficulty
    if difficulty not in [:easy, :medium, :hard, :expert] do
      {:error, "Invalid difficulty: #{difficulty}. Must be one of: easy, medium, hard, expert"}
    else
      # Generate using Rust NIF
      case Generator.generate(size, difficulty) do
        {:ok, %{grid: flat_grid, solution: flat_solution}} ->
          # Convert flat arrays to nested arrays for Ecto
          grid = flat_to_nested(flat_grid, size)
          solution = flat_to_nested(flat_solution, size)

          # Count non-zero cells as clues
          clues_count = Enum.count(flat_grid, fn cell -> cell != 0 end)

          # Calculate sub-grid size (√N)
          sub_grid_size = trunc(:math.sqrt(size))

          # Create puzzle record
          attrs = %{
            size: size,
            grid_size: size,
            sub_grid_size: sub_grid_size,
            difficulty: difficulty,
            grid: grid,
            solution: solution,
            clues_count: clues_count
          }

          %Puzzle{}
          |> Puzzle.changeset(attrs)
          |> Repo.insert()

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def generate_puzzle(size, _difficulty) when not is_integer(size) do
    {:error, "Size must be an integer"}
  end

  def generate_puzzle(size, _difficulty) do
    {:error, "Invalid size: #{size}. Must be one of: 9, 16, 25, 36, 49, 100"}
  end

  @doc """
  Gets a single puzzle by ID with grid and solution preloaded.

  ## Parameters

    * `id` - Binary UUID of the puzzle

  ## Returns

    * `%Puzzle{}` - The puzzle struct
    * Raises `Ecto.NoResultsError` if puzzle not found

  ## Examples

      iex> Puzzles.get_puzzle!("550e8400-...")
      %Puzzle{size: 9, ...}
  """
  @spec get_puzzle!(binary()) :: Puzzle.t()
  def get_puzzle!(id) when is_binary(id) do
    Repo.get!(Puzzle, id)
  end

  @doc """
  Validates a player move against the puzzle's pre-computed solution.

  Uses O(1) validation by checking the solution array directly.

  ## Parameters

    * `puzzle` - The puzzle struct with solution loaded
    * `row` - Row index (0-based)
    * `col` - Column index (0-based)
    * `value` - Player's submitted value (1-based)

  ## Returns

    * `{:ok, true}` - Move is correct
    * `{:ok, false}` - Move is incorrect
    * `{:error, reason}` - Invalid parameters

  ## Examples

      iex> Puzzles.validate_move(puzzle, 0, 0, 5)
      {:ok, true}

      iex> Puzzles.validate_move(puzzle, 0, 0, 1)
      {:ok, false}

      iex> Puzzles.validate_move(puzzle, -1, 0, 1)
      {:error, "Invalid row: must be between 0 and 8"}
  """
  @spec validate_move(Puzzle.t(), integer(), integer(), integer()) ::
          {:ok, boolean()} | {:error, String.t()}
  def validate_move(%Puzzle{} = puzzle, row, col, value) do
    # Convert nested array solution to flat array for Validator
    flat_solution = nested_to_flat(puzzle.solution)
    flat_puzzle = %{size: puzzle.size, solution: flat_solution}

    Validator.validate_move(flat_puzzle, row, col, value)
  end

  @doc """
  Lists recent puzzles by size and difficulty for testing/debugging.

  Returns up to 50 most recent puzzles matching the criteria.

  ## Parameters

    * `size` - Grid dimension
    * `difficulty` - Difficulty level

  ## Returns

    * List of `%Puzzle{}` structs ordered by insertion date descending

  ## Examples

      iex> Puzzles.list_puzzles_by_size_and_difficulty(9, :easy)
      [%Puzzle{}, ...]
  """
  @spec list_puzzles_by_size_and_difficulty(integer(), atom()) :: [Puzzle.t()]
  def list_puzzles_by_size_and_difficulty(size, difficulty)
      when size in [9, 16, 25, 36, 49, 100] and difficulty in [:easy, :medium, :hard, :expert] do
    Puzzle
    |> where([p], p.size == ^size and p.difficulty == ^difficulty)
    |> order_by([p], desc: p.inserted_at)
    |> limit(50)
    |> Repo.all()
  end

  def list_puzzles_by_size_and_difficulty(_size, _difficulty), do: []

  # Private helper functions

  # Converts a flat array [1,2,3,4,5,6,7,8,9, ...] to nested [[1,2,3],[4,5,6],[7,8,9], ...]
  defp flat_to_nested(flat_list, size) do
    flat_list
    |> Enum.chunk_every(size)
  end

  # Converts nested [[1,2,3],[4,5,6]] to flat [1,2,3,4,5,6]
  defp nested_to_flat(nested_list) do
    List.flatten(nested_list)
  end
end
