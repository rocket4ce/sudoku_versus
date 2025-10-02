defmodule SudokuVersus.Games.GameRoom do
  @moduledoc """
  Schema for multiplayer game rooms.

  Each room has a puzzle, a creator, and can have multiple player sessions.
  Rooms support public/private visibility and track denormalized counts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_rooms" do
    field :name, :string
    field :status, Ecto.Enum, values: [:active, :completed, :archived], default: :active
    field :visibility, Ecto.Enum, values: [:public, :private], default: :public
    field :current_players_count, :integer, default: 0
    field :total_moves_count, :integer, default: 0
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :creator, SudokuVersus.Accounts.User
    belongs_to :puzzle, SudokuVersus.Games.Puzzle

    has_many :player_sessions, SudokuVersus.Games.PlayerSession
    has_many :moves, SudokuVersus.Games.Move

    timestamps()
  end

  @doc """
  Changeset for creating a new game room.
  """
  def changeset(game_room, attrs) do
    game_room
    |> cast(attrs, [:name, :visibility, :creator_id, :puzzle_id])
    |> validate_required([:name, :creator_id, :puzzle_id])
    |> validate_room_name()
    |> validate_inclusion(:visibility, [:public, :private])
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:puzzle_id)
  end

  @doc """
  Changeset for updating room status.
  """
  def status_changeset(game_room, attrs) do
    game_room
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, [:active, :completed, :archived])
  end

  @doc """
  Changeset for updating denormalized counts.
  """
  def counts_changeset(game_room, attrs) do
    game_room
    |> cast(attrs, [:current_players_count, :total_moves_count])
    |> validate_number(:current_players_count, greater_than_or_equal_to: 0)
    |> validate_number(:total_moves_count, greater_than_or_equal_to: 0)
  end

  # Private validation functions

  defp validate_room_name(changeset) do
    changeset
    |> validate_length(:name, min: 1, max: 30)
    |> validate_format(:name, ~r/^[\p{L}\p{N}\p{So}\s_-]+$/u,
      message: "must contain only letters, numbers, emojis, spaces, underscores, and hyphens"
    )
  end
end
