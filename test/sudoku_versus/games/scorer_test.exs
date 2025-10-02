defmodule SudokuVersus.Games.ScorerTest do
  use SudokuVersus.DataCase

  alias SudokuVersus.Games.Scorer
  alias SudokuVersus.Accounts.User
  alias SudokuVersus.Games.{Puzzle, PlayerSession}

  describe "calculate_score/3" do
    setup do
      user = %User{id: Ecto.UUID.generate()}
      puzzle = %Puzzle{difficulty: :medium}
      session = %PlayerSession{
        player_id: user.id,
        current_streak: 5,
        longest_streak: 10,
        correct_moves_count: 20,
        incorrect_moves_count: 3
      }

      move = %{
        is_correct: true,
        submitted_at: DateTime.utc_now(),
        row: 0,
        col: 0,
        value: 5
      }

      %{puzzle: puzzle, session: session, move: move}
    end

    test "calculates score for easy correct move", %{session: session, move: move} do
      puzzle = %Puzzle{difficulty: :easy}

      score = Scorer.calculate_score(move, session, puzzle)

      assert score > 0
      assert is_integer(score)
      # Easy base: 500 points
      assert score >= 500
    end

    test "calculates score for medium correct move", %{session: session, move: move} do
      puzzle = %Puzzle{difficulty: :medium}

      score = Scorer.calculate_score(move, session, puzzle)

      # Medium base: 1500 points
      assert score >= 1500
    end

    test "calculates score for hard correct move", %{session: session, move: move} do
      puzzle = %Puzzle{difficulty: :hard}

      score = Scorer.calculate_score(move, session, puzzle)

      # Hard base: 3000 points
      assert score >= 3000
    end

    test "calculates score for expert correct move", %{session: session, move: move} do
      puzzle = %Puzzle{difficulty: :expert}

      score = Scorer.calculate_score(move, session, puzzle)

      # Expert base: 5000 points
      assert score >= 5000
    end

    test "applies streak multiplier to score", %{puzzle: puzzle, move: move} do
      session_no_streak = %PlayerSession{current_streak: 0, correct_moves_count: 1, incorrect_moves_count: 0}
      session_with_streak = %PlayerSession{current_streak: 10, correct_moves_count: 10, incorrect_moves_count: 0}

      score_no_streak = Scorer.calculate_score(move, session_no_streak, puzzle)
      score_with_streak = Scorer.calculate_score(move, session_with_streak, puzzle)

      # Score with streak should be higher
      assert score_with_streak > score_no_streak
    end

    test "returns 0 for incorrect move", %{puzzle: puzzle, session: session} do
      incorrect_move = %{
        is_correct: false,
        submitted_at: DateTime.utc_now(),
        row: 0,
        col: 0,
        value: 5
      }

      score = Scorer.calculate_score(incorrect_move, session, puzzle)

      assert score == 0
    end

    test "applies speed bonus for fast moves", %{puzzle: puzzle, session: session} do
      # Move submitted 5 seconds after start (fast)
      fast_move = %{
        is_correct: true,
        submitted_at: DateTime.add(DateTime.utc_now(), -5, :second),
        row: 0,
        col: 0,
        value: 5
      }

      score = Scorer.calculate_score(fast_move, session, puzzle)

      # Should have some bonus
      assert score > 0
    end
  end

  describe "base_points_for_difficulty/1" do
    test "returns 500 for easy" do
      assert Scorer.base_points_for_difficulty(:easy) == 500
    end

    test "returns 1500 for medium" do
      assert Scorer.base_points_for_difficulty(:medium) == 1500
    end

    test "returns 3000 for hard" do
      assert Scorer.base_points_for_difficulty(:hard) == 3000
    end

    test "returns 5000 for expert" do
      assert Scorer.base_points_for_difficulty(:expert) == 5000
    end
  end

  describe "calculate_streak_multiplier/1" do
    test "returns 1.0 for no streak" do
      assert Scorer.calculate_streak_multiplier(0) == 1.0
    end

    test "returns increasing multiplier for longer streaks" do
      multiplier_5 = Scorer.calculate_streak_multiplier(5)
      multiplier_10 = Scorer.calculate_streak_multiplier(10)
      multiplier_20 = Scorer.calculate_streak_multiplier(20)

      assert multiplier_5 > 1.0
      assert multiplier_10 > multiplier_5
      assert multiplier_20 > multiplier_10
    end

    test "caps multiplier at 2.0" do
      assert Scorer.calculate_streak_multiplier(100) <= 2.0
    end
  end

  describe "calculate_speed_bonus/2" do
    test "returns bonus for moves under 10 seconds" do
      fast_time = DateTime.add(DateTime.utc_now(), -5, :second)
      bonus = Scorer.calculate_speed_bonus(fast_time, DateTime.utc_now())

      assert bonus > 0
    end

    test "returns 0 for slow moves" do
      slow_time = DateTime.add(DateTime.utc_now(), -30, :second)
      bonus = Scorer.calculate_speed_bonus(slow_time, DateTime.utc_now())

      assert bonus == 0
    end
  end

  describe "calculate_penalties/1" do
    test "applies penalty for incorrect moves" do
      session = %PlayerSession{correct_moves_count: 10, incorrect_moves_count: 5}

      penalty = Scorer.calculate_penalties(session)

      assert penalty > 0
    end

    test "returns 0 when no incorrect moves" do
      session = %PlayerSession{correct_moves_count: 10, incorrect_moves_count: 0}

      penalty = Scorer.calculate_penalties(session)

      assert penalty == 0
    end
  end
end
