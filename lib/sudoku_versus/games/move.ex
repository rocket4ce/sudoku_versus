defmodule SudokuVersus.Games.Move do
  @moduledoc """
  Schema for individual Sudoku moves in game rooms.

  Records each cell placement attempt with validation results and scoring.
  Move history is used for live updates and replay functionality.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "moves" do
    field :row, :integer
    field :col, :integer
    field :value, :integer
    field :is_correct, :boolean
    field :submitted_at, :utc_datetime
    field :points_earned, :integer, default: 0

    belongs_to :player, SudokuVersus.Accounts.User
    belongs_to :game_room, SudokuVersus.Games.GameRoom
    belongs_to :player_session, SudokuVersus.Games.PlayerSession

    timestamps()
  end

  @doc """
  Changeset for creating a new move.
  """
  def changeset(move, attrs) do
    move
    |> cast(attrs, [
      :row,
      :col,
      :value,
      :is_correct,
      :submitted_at,
      :points_earned,
      :player_id,
      :game_room_id,
      :player_session_id
    ])
    |> validate_required([
      :row,
      :col,
      :value,
      :is_correct,
      :player_id,
      :game_room_id,
      :player_session_id
    ])
    |> validate_number(:row, greater_than_or_equal_to: 0, less_than_or_equal_to: 8)
    |> validate_number(:col, greater_than_or_equal_to: 0, less_than_or_equal_to: 8)
    |> validate_number(:value, greater_than_or_equal_to: 1, less_than_or_equal_to: 9)
    |> validate_number(:points_earned, greater_than_or_equal_to: 0)
    |> put_submitted_at()
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:game_room_id)
    |> foreign_key_constraint(:player_session_id)
  end

  # Private helper functions

  defp put_submitted_at(changeset) do
    case get_field(changeset, :submitted_at) do
      nil -> put_change(changeset, :submitted_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end
