defmodule SudokuVersus.Puzzles.GeneratorResult do
  @moduledoc false
  defstruct [:grid, :solution]

  @type t :: %__MODULE__{
          grid: [integer()],
          solution: [integer()]
        }
end

defmodule SudokuVersus.Puzzles.Generator do
  @moduledoc """
  Elixir wrapper for Rust NIF puzzle generator.

  This module provides high-performance Sudoku puzzle generation using Rust NIFs.
  Generation times:
  - 9×9: <50ms
  - 16×16: <100ms
  - 25×25: <500ms
  - 36×36: <1s
  - 49×49: <2s
  - 100×100: <5s
  """

  use Rustler, otp_app: :sudoku_versus, crate: "sudoku_generator"

  alias SudokuVersus.Puzzles.GeneratorResult

  @doc """
  Generates a Sudoku puzzle with the given size and difficulty.

  ## Parameters
  - `size`: Grid dimension (9, 16, 25, 36, 49, or 100)
  - `difficulty`: Difficulty level (0=easy, 1=medium, 2=hard, 3=expert)
  - `seed`: Random seed for reproducibility (defaults to current system time)

  ## Returns
  - `{:ok, %GeneratorResult{}}` - Success with grid and solution
  - `{:error, reason}` - Failure with error message

  ## Examples

      iex> {:ok, result} = generate(9, 0, 12345)
      iex> length(result.grid) == 81
      true
      iex> length(result.solution) == 81
      true
  """
  @spec generate(integer(), integer() | atom(), integer()) ::
          {:ok, GeneratorResult.t()} | {:error, String.t()}
  def generate(size, difficulty, seed \\ :erlang.system_time(:nanosecond))
      when is_integer(size) and is_integer(seed) do
    # Map Elixir atoms to integer values
    difficulty_int =
      case difficulty do
        :easy -> 0
        :medium -> 1
        :hard -> 2
        :expert -> 3
        n when is_integer(n) -> n
        _ -> nil
      end

    case difficulty_int do
      nil -> {:error, "Invalid difficulty: must be :easy, :medium, :hard, :expert, or 0-3"}
      _ -> generate_nif(size, difficulty_int, seed)
    end
  end

  # NIF placeholder - replaced when NIF loads
  defp generate_nif(_size, _difficulty, _seed), do: :erlang.nif_error(:nif_not_loaded)
end
