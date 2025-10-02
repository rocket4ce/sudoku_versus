defmodule SudokuVersus.Games.Scorer do
  @moduledoc """
  Calculates scores for Sudoku moves with difficulty-based points,
  streak multipliers, speed bonuses, and penalties.
  
  Scoring is calculated immediately on each move submission (<1ms compute time).
  """

  alias SudokuVersus.Games.PlayerSession

  @doc """
  Calculates the score for a move.
  
  Returns 0 for incorrect moves.
  For correct moves, returns: (base_points * streak_multiplier) + speed_bonus - penalties
  """
  def calculate_score(%{is_correct: false}, _session, _puzzle), do: 0

  def calculate_score(move, session, puzzle) do
    base = base_points_for_difficulty(puzzle.difficulty)
    multiplier = calculate_streak_multiplier(session.current_streak)
    speed_bonus = calculate_speed_bonus(move.submitted_at, DateTime.utc_now())

    # Note: Penalties are tracked in session stats but don't reduce per-move scores
    # This ensures players always get rewarded for correct moves
    score = round(base * multiplier) + speed_bonus
    max(score, 0)
  end

  @doc """
  Returns base points for a difficulty level.
  
  - :easy - 500 points
  - :medium - 1500 points
  - :hard - 3000 points
  - :expert - 5000 points
  """
  def base_points_for_difficulty(:easy), do: 500
  def base_points_for_difficulty(:medium), do: 1500
  def base_points_for_difficulty(:hard), do: 3000
  def base_points_for_difficulty(:expert), do: 5000

  @doc """
  Calculates streak multiplier (1.0 to 2.0).
  
  Formula: 1.0 + min(streak * 0.05, 1.0)
  - 0 streak: 1.0x
  - 5 streak: 1.25x
  - 10 streak: 1.5x
  - 20+ streak: 2.0x (capped)
  """
  def calculate_streak_multiplier(streak) when is_integer(streak) and streak >= 0 do
    1.0 + min(streak * 0.05, 1.0)
  end

  def calculate_streak_multiplier(_), do: 1.0

  @doc """
  Calculates speed bonus for fast moves.
  
  Bonus for moves completed in under 10 seconds:
  - < 5 seconds: 200 bonus points
  - 5-10 seconds: 100 bonus points
  - > 10 seconds: 0 bonus points
  """
  def calculate_speed_bonus(move_time, current_time) do
    # Calculate elapsed time in seconds
    seconds = DateTime.diff(current_time, move_time)

    cond do
      seconds < 5 -> 200
      seconds < 10 -> 100
      true -> 0
    end
  end

  @doc """
  Calculates penalties based on incorrect moves.
  
  Formula: incorrect_moves_count * 100
  """
  def calculate_penalties(%PlayerSession{} = session) do
    session.incorrect_moves_count * 100
  end

  def calculate_penalties(_), do: 0
end
