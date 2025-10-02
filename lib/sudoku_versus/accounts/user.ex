defmodule SudokuVersus.Accounts.User do
  @moduledoc """
  Schema for user accounts.

  Supports three authentication modes:
  - Guest: username only, is_guest=true
  - Registered: email + password_hash
  - OAuth: oauth_provider + oauth_provider_id (Google/GitHub)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :display_name, :string
    field :avatar_url, :string
    field :is_guest, :boolean, default: false
    field :oauth_provider, :string
    field :oauth_provider_id, :string
    field :total_games_played, :integer, default: 0
    field :total_puzzles_completed, :integer, default: 0
    field :total_points_earned, :integer, default: 0
    field :highest_score, :integer, default: 0

    timestamps()
  end

  @doc """
  Changeset for guest user creation (username only).
  """
  def guest_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :display_name, :avatar_url])
    |> validate_required([:username])
    |> validate_username()
    |> put_change(:is_guest, true)
    |> unique_constraint(:username)
  end

  @doc """
  Changeset for registered user creation (email + password).
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password, :display_name, :avatar_url])
    |> validate_required([:username, :email, :password])
    |> validate_username()
    |> validate_email()
    |> validate_password()
    |> put_password_hash()
    |> put_change(:is_guest, false)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for OAuth user creation (provider + provider_id).
  """
  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :email,
      :oauth_provider,
      :oauth_provider_id,
      :display_name,
      :avatar_url
    ])
    |> validate_required([:username, :oauth_provider, :oauth_provider_id])
    |> validate_username()
    |> validate_inclusion(:oauth_provider, ["google", "github"])
    |> put_change(:is_guest, false)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> unique_constraint([:oauth_provider, :oauth_provider_id])
  end

  @doc """
  Changeset for updating user statistics.
  """
  def stats_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :total_games_played,
      :total_puzzles_completed,
      :total_points_earned,
      :highest_score
    ])
    |> validate_number(:total_games_played, greater_than_or_equal_to: 0)
    |> validate_number(:total_puzzles_completed, greater_than_or_equal_to: 0)
    |> validate_number(:total_points_earned, greater_than_or_equal_to: 0)
    |> validate_number(:highest_score, greater_than_or_equal_to: 0)
  end

  # Private functions

  defp validate_username(changeset) do
    changeset
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
      message: "must contain only letters, numbers, underscore, and hyphen"
    )
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_length(:email, max: 160)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/,
      message: "must contain at least one lowercase letter"
    )
    |> validate_format(:password, ~r/[A-Z]/,
      message: "must contain at least one uppercase letter"
    )
    |> validate_format(:password, ~r/[0-9]/, message: "must contain at least one digit")
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        # TODO: Add bcrypt dependency and use Bcrypt.hash_pwd_salt(password)
        put_change(changeset, :password_hash, Base.encode64(:crypto.hash(:sha256, password)))

      _ ->
        changeset
    end
  end
end
