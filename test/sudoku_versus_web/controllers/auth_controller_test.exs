defmodule SudokuVersusWeb.AuthControllerTest do
  use SudokuVersusWeb.ConnCase

  alias SudokuVersus.Accounts

  describe "GET /auth/:provider" do
    test "redirects to Google OAuth authorization URL", %{conn: conn} do
      conn = get(conn, ~p"/auth/google")

      assert redirected_to(conn) =~ "accounts.google.com/o/oauth2/v2/auth"
      assert redirected_to(conn) =~ "client_id="
      assert redirected_to(conn) =~ "redirect_uri="
      assert redirected_to(conn) =~ "scope=openid"
    end

    test "redirects to GitHub OAuth authorization URL", %{conn: conn} do
      conn = get(conn, ~p"/auth/github")

      assert redirected_to(conn) =~ "github.com/login/oauth/authorize"
      assert redirected_to(conn) =~ "client_id="
      assert redirected_to(conn) =~ "redirect_uri="
    end

    test "returns 404 for unsupported provider", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/auth/unsupported")
      end
    end
  end

  describe "GET /auth/:provider/callback" do
    setup %{conn: conn} do
      # Mock OAuth responses using Req.Test
      Req.Test.stub(SudokuVersus.Accounts.OAuth, fn conn ->
        Req.Test.json(conn, %{"access_token" => "mock_token"})
      end)

      %{conn: conn}
    end

    test "creates user and logs in on successful Google callback", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback", %{"code" => "valid_code"})

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_id)
    end

    test "creates user and logs in on successful GitHub callback", %{conn: conn} do
      conn = get(conn, ~p"/auth/github/callback", %{"code" => "valid_code"})

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_id)
    end

    test "redirects to login with error on OAuth failure", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback", %{"error" => "access_denied"})

      assert redirected_to(conn) == ~p"/login/guest"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication failed"
    end

    test "redirects to login when code is missing", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback", %{})

      assert redirected_to(conn) == ~p"/login/guest"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end
  end

  describe "DELETE /auth/logout" do
    setup %{conn: conn} do
      {:ok, user} = Accounts.create_guest_user(%{username: "logout_test"})
      conn = Plug.Test.init_test_session(conn, user_id: user.id)

      %{conn: conn, user: user}
    end

    test "clears session and redirects to home", %{conn: conn} do
      conn = delete(conn, ~p"/auth/logout")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_id)
    end

    test "shows flash message on logout", %{conn: conn} do
      conn = delete(conn, ~p"/auth/logout")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "logged out"
    end
  end
end
