defmodule SudokuVersus.Games do
  @moduledoc """
  The Games context manages game rooms, player sessions, moves, and puzzles.
  """

  import Ecto.Query, warn: false
  alias SudokuVersus.Repo
  alias SudokuVersus.Games.{GameRoom, PlayerSession, Move, Puzzle, PuzzleGenerator, Scorer}

  ## Puzzle functions

  @doc """
  Creates a new puzzle with the specified difficulty.

  Delegates to PuzzleGenerator.generate_puzzle/1.
  """
  def create_puzzle(difficulty) when difficulty in [:easy, :medium, :hard, :expert] do
    PuzzleGenerator.generate_puzzle(difficulty)
  end

  ## Game Room functions

  @doc """
  Creates a new game room.

  ## Examples

      iex> create_game_room(%{name: "My Room", creator_id: id, puzzle_id: pid})
      {:ok, %GameRoom{}}
  """
  def create_game_room(attrs \\ %{}) do
    %GameRoom{}
    |> GameRoom.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a list of active game rooms with preloaded associations.
  """
  def list_active_rooms do
    GameRoom
    |> where([r], r.status == :active)
    |> preload([:puzzle, :creator])
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single game room by ID.

  Returns nil if the room does not exist.
  """
  def get_game_room(id) when is_binary(id) do
    GameRoom
    |> preload([:puzzle, :creator])
    |> Repo.get(id)
  end

  def get_game_room(_), do: nil

  @doc """
  Updates a game room's status.
  """
  def update_room_status(%GameRoom{} = room, status) when status in [:active, :completed, :archived] do
    room
    |> GameRoom.status_changeset(%{status: status})
    |> Repo.update()
  end

  ## Player Session functions

  @doc """
  Gets a player session for a room.
  """
  def get_player_session(room_id, player_id) do
    PlayerSession
    |> where([s], s.game_room_id == ^room_id and s.player_id == ^player_id)
    |> Repo.one()
  end

  @doc """
  Joins a room by creating an active player session.

  Increments the room's current_players_count.
  """
  def join_room(room_id, player_id) do
    attrs = %{
      game_room_id: room_id,
      player_id: player_id,
      is_active: true,
      current_score: 0,
      current_streak: 0,
      longest_streak: 0,
      correct_moves_count: 0,
      incorrect_moves_count: 0,
      cells_filled: 0
    }

    result =
      %PlayerSession{}
      |> PlayerSession.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, session} ->
        # Increment room player count
        increment_room_players(room_id, 1)
        {:ok, session}

      error ->
        error
    end
  end

  @doc """
  Leaves a room by marking the player session as inactive.

  Decrements the room's current_players_count.
  """
  def leave_room(room_id, player_id) do
    case get_player_session(room_id, player_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        result =
          session
          |> PlayerSession.changeset(%{is_active: false})
          |> Repo.update()

        case result do
          {:ok, updated_session} ->
            # Decrement room player count
            increment_room_players(room_id, -1)
            {:ok, updated_session}

          error ->
            error
        end
    end
  end

  defp increment_room_players(room_id, delta) do
    from(r in GameRoom, where: r.id == ^room_id)
    |> Repo.update_all(inc: [current_players_count: delta])
  end

  ## Move functions

  @doc """
  Records a move for a player in a room.

  Validates the move against the puzzle solution, calculates score,
  and updates player session stats.
  """
  def record_move(room_id, player_id, move_attrs) do
    with {:ok, room} <- fetch_room(room_id),
         {:ok, session} <- fetch_session(room_id, player_id),
         {:ok, puzzle} <- fetch_puzzle(room.puzzle_id),
         {:ok, move_data} <- validate_and_score_move(puzzle, session, move_attrs) do
      # Insert move record
      move_result =
        %Move{}
        |> Move.changeset(
          Map.merge(move_attrs, %{
            game_room_id: room_id,
            player_id: player_id,
            player_session_id: session.id,
            is_correct: move_data.is_correct,
            points_earned: move_data.points_earned,
            submitted_at: DateTime.utc_now()
          })
        )
        |> Repo.insert()

      case move_result do
        {:ok, move} ->
          # Update player session stats
          update_session_stats(session, move_data)

          # Increment room move count
          increment_room_moves(room_id)

          {:ok, move}

        error ->
          error
      end
    end
  end

  defp fetch_room(room_id) do
    case Repo.get(GameRoom, room_id) do
      nil -> {:error, :room_not_found}
      room -> {:ok, room}
    end
  end

  defp fetch_session(room_id, player_id) do
    case get_player_session(room_id, player_id) do
      nil -> {:error, :session_not_found}
      session -> {:ok, session}
    end
  end

  defp fetch_puzzle(puzzle_id) do
    case Repo.get(Puzzle, puzzle_id) do
      nil -> {:error, :puzzle_not_found}
      puzzle -> {:ok, puzzle}
    end
  end

  defp validate_and_score_move(puzzle, session, %{row: row, col: col, value: value}) do
    is_correct = PuzzleGenerator.validate_move?(puzzle, row, col, value)

    move_data = %{
      is_correct: is_correct,
      submitted_at: DateTime.utc_now(),
      row: row,
      col: col,
      value: value
    }

    points_earned =
      if is_correct do
        Scorer.calculate_score(move_data, session, puzzle)
      else
        0
      end

    {:ok, Map.put(move_data, :points_earned, points_earned)}
  end

  defp update_session_stats(session, move_data) do
    new_stats =
      if move_data.is_correct do
        %{
          correct_moves_count: session.correct_moves_count + 1,
          current_score: session.current_score + move_data.points_earned,
          current_streak: session.current_streak + 1,
          longest_streak: max(session.longest_streak, session.current_streak + 1),
          cells_filled: session.cells_filled + 1
        }
      else
        %{
          incorrect_moves_count: session.incorrect_moves_count + 1,
          current_streak: 0
        }
      end

    session
    |> PlayerSession.changeset(new_stats)
    |> Repo.update()
  end

  defp increment_room_moves(room_id) do
    from(r in GameRoom, where: r.id == ^room_id)
    |> Repo.update_all(inc: [total_moves_count: 1])
  end

  @doc """
  Gets recent moves for a room with preloaded player association.

  Returns moves ordered by most recent first, limited to 50 by default.
  """
  def get_room_moves(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Move
    |> where([m], m.game_room_id == ^room_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload(:player)
    |> Repo.all()
  end

  ## Leaderboard functions (placeholders for T038-T039)

  @doc """
  Refreshes the materialized view for leaderboard entries.
  """
  def refresh_leaderboard do
    Repo.query("REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_entries")
  end

  @doc """
  Gets leaderboard entries, optionally filtered by difficulty.
  """
  def get_leaderboard(difficulty \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    query =
      if difficulty do
        from(l in "leaderboard_entries",
          where: l.difficulty == ^to_string(difficulty),
          order_by: [asc: l.rank],
          limit: ^limit
        )
      else
        from(l in "leaderboard_entries",
          order_by: [asc: l.difficulty, asc: l.rank],
          limit: ^limit
        )
      end

    Repo.all(query)
  end
end
