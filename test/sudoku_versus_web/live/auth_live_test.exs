defmodule SudokuVersusWeb.AuthLiveTest do
  use SudokuVersusWeb.ConnCase

  import Phoenix.LiveViewTest
  alias SudokuVersus.Accounts

  describe "guest login form" do
    test "renders guest login form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login/guest")

      assert has_element?(view, "#guest-login-form")
    end

    test "creates guest user and redirects to lobby", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login/guest")

      form_data = %{"user" => %{"username" => "new_guest_player"}}

      view
      |> form("#guest-login-form", form_data)
      |> render_submit()

      assert_redirect(view, ~p"/game")
    end

    test "shows error with invalid username", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login/guest")

      # Too short
      form_data = %{"user" => %{"username" => "ab"}}

      html =
        view
        |> form("#guest-login-form", form_data)
        |> render_submit()

      assert html =~ "should be at least 3 character"
    end

    test "validates username format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login/guest")

      # Contains invalid chars
      form_data = %{"user" => %{"username" => "invalid username!"}}

      html =
        view
        |> form("#guest-login-form", form_data)
        |> render_submit()

      assert html =~ "must contain only letters, numbers"
    end
  end

  describe "registration form" do
    test "renders registration form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      assert has_element?(view, "#register-form")
    end

    test "creates registered user and redirects to lobby", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      form_data = %{
        "user" => %{
          "username" => "registered_user",
          "email" => "user@example.com",
          "password" => "SecurePass123",
          "password_confirmation" => "SecurePass123"
        }
      }

      view
      |> form("#register-form", form_data)
      |> render_submit()

      assert_redirect(view, ~p"/game")
    end

    test "shows error with invalid email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      form_data = %{
        "user" => %{
          "username" => "test_user",
          "email" => "invalid-email",
          "password" => "SecurePass123"
        }
      }

      html =
        view
        |> form("#register-form", form_data)
        |> render_submit()

      assert html =~ "must be a valid email"
    end

    test "shows error with weak password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      form_data = %{
        "user" => %{
          "username" => "test_user",
          "email" => "test@example.com",
          "password" => "weak"
        }
      }

      html =
        view
        |> form("#register-form", form_data)
        |> render_submit()

      assert html =~ "should be at least 8 character"
    end

    test "validates password confirmation match", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      form_data = %{
        "user" => %{
          "username" => "test_user",
          "email" => "test@example.com",
          "password" => "SecurePass123",
          "password_confirmation" => "DifferentPass456"
        }
      }

      html =
        view
        |> form("#register-form", form_data)
        |> render_submit()

      assert html =~ "does not match"
    end
  end

  describe "OAuth buttons" do
    test "displays Google OAuth button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      assert has_element?(view, "#google-oauth-btn")
    end

    test "displays GitHub OAuth button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      assert has_element?(view, "#github-oauth-btn")
    end

    test "Google button redirects to OAuth flow", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      element = element(view, "#google-oauth-btn")
      html = render_click(element)

      # Should redirect to /auth/google
      assert_redirect(view, ~p"/auth/google")
    end

    test "GitHub button redirects to OAuth flow", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      element = element(view, "#github-oauth-btn")
      html = render_click(element)

      # Should redirect to /auth/github
      assert_redirect(view, ~p"/auth/github")
    end
  end

  describe "login form (email/password)" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          username: "existing_user",
          email: "existing@example.com",
          password: "SecurePass123"
        })

      %{user: user}
    end

    test "renders login form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      assert has_element?(view, "form")
    end

    test "logs in with correct credentials", %{conn: conn, user: _user} do
      {:ok, view, _html} = live(conn, ~p"/login")

      form_data = %{
        "user" => %{
          "email" => "existing@example.com",
          "password" => "SecurePass123"
        }
      }

      view
      |> form("form", form_data)
      |> render_submit()

      assert_redirect(view, ~p"/game")
    end

    test "shows error with incorrect password", %{conn: conn, user: _user} do
      {:ok, view, _html} = live(conn, ~p"/login")

      form_data = %{
        "user" => %{
          "email" => "existing@example.com",
          "password" => "WrongPassword"
        }
      }

      html =
        view
        |> form("form", form_data)
        |> render_submit()

      assert html =~ "Invalid email or password"
    end

    test "shows error with non-existent email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      form_data = %{
        "user" => %{
          "email" => "nonexistent@example.com",
          "password" => "SomePassword123"
        }
      }

      html =
        view
        |> form("form", form_data)
        |> render_submit()

      assert html =~ "Invalid email or password"
    end
  end
end
