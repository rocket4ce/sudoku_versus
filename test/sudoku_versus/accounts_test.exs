defmodule SudokuVersus.AccountsTest do
  use SudokuVersus.DataCase

  alias SudokuVersus.Accounts

  describe "create_guest_user/1" do
    test "creates a guest user with valid username" do
      attrs = %{username: "guest_player_123"}

      assert {:ok, user} = Accounts.create_guest_user(attrs)
      assert user.username == "guest_player_123"
      assert user.is_guest == true
      assert is_nil(user.email)
      assert is_nil(user.password_hash)
    end

    test "returns error with invalid username" do
      attrs = %{username: "ab"}  # Too short

      assert {:error, changeset} = Accounts.create_guest_user(attrs)
      assert "should be at least 3 character(s)" in errors_on(changeset).username
    end

    test "returns error when username already taken" do
      attrs = %{username: "duplicate_user"}

      assert {:ok, _user} = Accounts.create_guest_user(attrs)
      assert {:error, changeset} = Accounts.create_guest_user(attrs)
      assert "has already been taken" in errors_on(changeset).username
    end
  end

  describe "register_user/1" do
    test "creates a registered user with valid attributes" do
      attrs = %{
        username: "registered_player",
        email: "player@example.com",
        password: "SecurePass123"
      }

      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.username == "registered_player"
      assert user.email == "player@example.com"
      assert user.is_guest == false
      assert is_binary(user.password_hash)
      assert user.password_hash != "SecurePass123"
    end

    test "returns error with invalid email" do
      attrs = %{
        username: "test_user",
        email: "invalid-email",
        password: "SecurePass123"
      }

      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "must be a valid email" in errors_on(changeset).email
    end

    test "returns error with weak password" do
      attrs = %{
        username: "test_user",
        email: "test@example.com",
        password: "weak"
      }

      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end
  end

  describe "find_or_create_oauth_user/2" do
    test "creates a new OAuth user" do
      provider = "google"
      profile = %{
        "id" => "google_12345",
        "email" => "oauth@example.com",
        "name" => "OAuth User"
      }

      assert {:ok, user} = Accounts.find_or_create_oauth_user(provider, profile)
      assert user.oauth_provider == "google"
      assert user.oauth_provider_id == "google_12345"
      assert user.email == "oauth@example.com"
      assert user.is_guest == false
    end

    test "finds existing OAuth user" do
      provider = "github"
      profile = %{
        "id" => "github_67890",
        "login" => "github_user",
        "email" => "github@example.com"
      }

      assert {:ok, user1} = Accounts.find_or_create_oauth_user(provider, profile)
      assert {:ok, user2} = Accounts.find_or_create_oauth_user(provider, profile)

      assert user1.id == user2.id
    end
  end

  describe "get_user_by_username/1" do
    test "returns user when username exists" do
      {:ok, user} = Accounts.create_guest_user(%{username: "findme"})

      assert found_user = Accounts.get_user_by_username("findme")
      assert found_user.id == user.id
    end

    test "returns nil when username does not exist" do
      assert is_nil(Accounts.get_user_by_username("nonexistent"))
    end
  end

  describe "authenticate_user/2" do
    test "authenticates user with correct credentials" do
      {:ok, user} = Accounts.register_user(%{
        username: "auth_test",
        email: "auth@example.com",
        password: "SecurePass123"
      })

      assert {:ok, authenticated_user} = Accounts.authenticate_user("auth@example.com", "SecurePass123")
      assert authenticated_user.id == user.id
    end

    test "returns error with incorrect password" do
      {:ok, _user} = Accounts.register_user(%{
        username: "auth_test2",
        email: "auth2@example.com",
        password: "SecurePass123"
      })

      assert {:error, :invalid_credentials} = Accounts.authenticate_user("auth2@example.com", "WrongPassword")
    end

    test "returns error when user does not exist" do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user("nonexistent@example.com", "password")
    end
  end
end
