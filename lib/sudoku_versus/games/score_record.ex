defmodule SudokuVersus.Games.ScoreRecord do
  @moduledoc """
  Schema for final game scores.

  Records completed game sessions for leaderboard tracking.
  Created when a player completes a puzzle or leaves a room.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "score_records" do
    field :final_score, :integer
    field :time_elapsed_seconds, :integer
    field :correct_moves, :integer
    field :incorrect_moves, :integer
    field :longest_streak, :integer
    field :completed_puzzle, :boolean, default: false
    field :difficulty, Ecto.Enum, values: [:easy, :medium, :hard, :expert]
    field :recorded_at, :utc_datetime

    belongs_to :player, SudokuVersus.Accounts.User
    belongs_to :game_room, SudokuVersus.Games.GameRoom

    timestamps()
  end

  @doc """
  Changeset for creating a new score record.
  """
  def changeset(score_record, attrs) do
    score_record
    |> cast(attrs, [
      :final_score,
      :time_elapsed_seconds,
      :correct_moves,
      :incorrect_moves,
      :longest_streak,
      :completed_puzzle,
      :difficulty,
      :recorded_at,
      :player_id,
      :game_room_id
    ])
    |> validate_required([
      :final_score,
      :time_elapsed_seconds,
      :correct_moves,
      :incorrect_moves,
      :longest_streak,
      :completed_puzzle,
      :difficulty,
      :player_id,
      :game_room_id
    ])
    |> validate_number(:final_score, greater_than_or_equal_to: 0)
    |> validate_number(:time_elapsed_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:correct_moves, greater_than_or_equal_to: 0)
    |> validate_number(:incorrect_moves, greater_than_or_equal_to: 0)
    |> validate_number(:longest_streak, greater_than_or_equal_to: 0)
    |> validate_inclusion(:difficulty, [:easy, :medium, :hard, :expert])
    |> put_recorded_at()
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:game_room_id)
  end

  # Private helper functions

  defp put_recorded_at(changeset) do
    case get_field(changeset, :recorded_at) do
      nil -> put_change(changeset, :recorded_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end
