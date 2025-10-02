defmodule SudokuVersus.Games.PlayerSession do
  @moduledoc """
  Schema for player sessions in game rooms.

  Tracks individual player progress, scoring, and statistics within a specific game room.
  Each player can only have one active session per room (enforced by unique index).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "player_sessions" do
    field :started_at, :utc_datetime
    field :last_activity_at, :utc_datetime
    field :is_active, :boolean, default: true
    field :current_score, :integer, default: 0
    field :current_streak, :integer, default: 0
    field :longest_streak, :integer, default: 0
    field :correct_moves_count, :integer, default: 0
    field :incorrect_moves_count, :integer, default: 0
    field :cells_filled, :integer, default: 0
    field :completed_puzzle, :boolean, default: false

    belongs_to :player, SudokuVersus.Accounts.User
    belongs_to :game_room, SudokuVersus.Games.GameRoom

    has_many :moves, SudokuVersus.Games.Move

    timestamps()
  end

  @doc """
  Changeset for creating a new player session.
  """
  def changeset(player_session, attrs) do
    now = DateTime.utc_now()

    attrs =
      attrs
      |> Map.put_new(:started_at, now)
      |> Map.put_new(:last_activity_at, now)

    player_session
    |> cast(attrs, [
      :player_id,
      :game_room_id,
      :started_at,
      :last_activity_at,
      :is_active,
      :current_score,
      :current_streak,
      :longest_streak,
      :correct_moves_count,
      :incorrect_moves_count,
      :cells_filled,
      :completed_puzzle
    ])
    |> validate_required([:player_id, :game_room_id, :started_at, :last_activity_at])
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:game_room_id)
    |> unique_constraint([:player_id, :game_room_id],
      name: :player_sessions_player_id_game_room_id_index
    )
  end

  @doc """
  Changeset for updating session scoring statistics.
  """
  def score_changeset(player_session, attrs) do
    player_session
    |> cast(attrs, [
      :current_score,
      :current_streak,
      :longest_streak,
      :correct_moves_count,
      :incorrect_moves_count,
      :cells_filled
    ])
    |> validate_number(:current_score, greater_than_or_equal_to: 0)
    |> validate_number(:current_streak, greater_than_or_equal_to: 0)
    |> validate_number(:longest_streak, greater_than_or_equal_to: 0)
    |> validate_number(:correct_moves_count, greater_than_or_equal_to: 0)
    |> validate_number(:incorrect_moves_count, greater_than_or_equal_to: 0)
    |> validate_number(:cells_filled, greater_than_or_equal_to: 0, less_than_or_equal_to: 81)
  end

  @doc """
  Changeset for marking session as completed.
  """
  def completion_changeset(player_session, attrs) do
    player_session
    |> cast(attrs, [:completed_puzzle])
    |> validate_required([:completed_puzzle])
  end

  @doc """
  Changeset for updating presence status.
  """
  def presence_changeset(player_session, attrs) do
    player_session
    |> cast(attrs, [:is_active])
    |> validate_required([:is_active])
  end
end
