defmodule SudokuVersus.Accounts do
  @moduledoc """
  The Accounts context manages user authentication and registration.

  Supports three authentication modes:
  - Guest users (username only, no password)
  - Registered users (email + password)
  - OAuth users (Google/GitHub)
  """

  import Ecto.Query, warn: false
  alias SudokuVersus.Repo
  alias SudokuVersus.Accounts.User

  @doc """
  Creates a guest user with just a username.

  ## Examples

      iex> create_guest_user(%{username: "guest123"})
      {:ok, %User{}}

      iex> create_guest_user(%{username: "ab"})
      {:error, %Ecto.Changeset{}}
  """
  def create_guest_user(attrs \\ %{}) do
    # Normalize to string keys and add is_guest flag
    normalized_attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Map.new()
      |> Map.put("is_guest", true)

    %User{}
    |> User.guest_changeset(normalized_attrs)
    |> Repo.insert()
  end

  @doc """
  Registers a new user with email and password.

  ## Examples

      iex> register_user(%{username: "player1", email: "player@example.com", password: "SecurePass123!"})
      {:ok, %User{}}

      iex> register_user(%{username: "a", email: "invalid", password: "weak"})
      {:error, %Ecto.Changeset{}}
  """
  def register_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Finds or creates a user from OAuth provider data.

  ## Examples

      iex> find_or_create_oauth_user("google", %{email: "user@gmail.com", name: "John Doe", sub: "12345"})
      {:ok, %User{}}
  """
  def find_or_create_oauth_user(provider, oauth_data) when provider in ["google", "github"] do
    provider_id = oauth_data["sub"] || oauth_data["id"] || to_string(oauth_data[:id])
    email = oauth_data["email"] || oauth_data[:email]
    raw_username = oauth_data["name"] || oauth_data["login"] || oauth_data[:login] || email
    # Sanitize username: replace spaces with underscores, keep only valid chars
    username =
      raw_username
      |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
      |> String.slice(0, 30)

    # Try to find existing user by OAuth provider
    case Repo.get_by(User, oauth_provider: provider, oauth_provider_id: provider_id) do
      nil ->
        # Try to find by email if provided
        user = if email, do: Repo.get_by(User, email: email), else: nil

        if user do
          # Update existing user with OAuth info
          user
          |> User.oauth_changeset(%{
            oauth_provider: provider,
            oauth_provider_id: provider_id
          })
          |> Repo.update()
        else
          # Create new user
          %User{}
          |> User.oauth_changeset(%{
            username: username,
            email: email,
            oauth_provider: provider,
            oauth_provider_id: provider_id
          })
          |> Repo.insert()
        end

      user ->
        {:ok, user}
    end
  end

  @doc """
  Gets a user by ID.

  ## Examples

      iex> get_user(user_id)
      %User{}

      iex> get_user("nonexistent_id")
      nil
  """
  def get_user(id) when is_binary(id) do
    Repo.get(User, id)
  end

  def get_user(_), do: nil

  @doc """
  Gets a user by username.

  ## Examples

      iex> get_user_by_username("player1")
      %User{}

      iex> get_user_by_username("nonexistent")
      nil
  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Authenticates a user with email and password.

  Returns {:ok, user} if credentials are valid, {:error, :invalid_credentials} otherwise.

  ## Examples

      iex> authenticate_user("player@example.com", "correct_password")
      {:ok, %User{}}

      iex> authenticate_user("player@example.com", "wrong_password")
      {:error, :invalid_credentials}
  """
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)

    cond do
      is_nil(user) ->
        # Run password hash to prevent timing attacks
        hash_password(password)
        {:error, :invalid_credentials}

      user.is_guest ->
        {:error, :invalid_credentials}

      verify_password(password, user.password_hash) ->
        {:ok, user}

      true ->
        {:error, :invalid_credentials}
    end
  end

  # Password hashing helpers (placeholder implementation)
  # TODO: Replace with bcrypt when available
  defp hash_password(password) do
    Base.encode64(:crypto.hash(:sha256, password))
  end

  defp verify_password(password, hashed_password) do
    hash_password(password) == hashed_password
  end
end
