# REST API Contracts

**Feature**: 002-mmo-sudoku-multiplayer
**Date**: 2025-01-10

## Purpose
Define REST API endpoints needed for OAuth authentication callbacks. Most interactions are LiveView-driven; these endpoints handle OAuth provider redirects only.

---

## Authentication Endpoints

### 1. Initiate OAuth Flow

**Endpoint**: `GET /auth/:provider`
**Description**: Redirects user to OAuth provider (Google or GitHub) for authentication
**Providers**: `google`, `github`

**Parameters**:
- `provider` (path param): `"google"` or `"github"`

**Response**: HTTP 302 Redirect to provider's authorization URL

**Example**:
```
GET /auth/google

→ 302 Redirect to:
https://accounts.google.com/o/oauth2/v2/auth?
  client_id=YOUR_CLIENT_ID&
  redirect_uri=https://yourdomain.com/auth/google/callback&
  response_type=code&
  scope=email+profile
```

**Implementation**:
```elixir
# lib/sudoku_versus_web/controllers/auth_controller.ex
defmodule SudokuVersusWeb.AuthController do
  use SudokuVersusWeb, :controller
  alias SudokuVersus.Accounts.OAuth

  def authorize(conn, %{"provider" => provider}) when provider in ["google", "github"] do
    provider_atom = String.to_existing_atom(provider)
    authorize_url = OAuth.authorize_url(provider_atom)
    redirect(conn, external: authorize_url)
  end
end
```

---

### 2. OAuth Callback

**Endpoint**: `GET /auth/:provider/callback`
**Description**: Handles OAuth provider redirect after user authorization
**Providers**: `google`, `github`

**Parameters**:
- `provider` (path param): `"google"` or `"github"`
- `code` (query param): Authorization code from provider
- `state` (query param, optional): CSRF protection token

**Success Response**: HTTP 302 Redirect to `/game` with session cookie

**Error Response**: HTTP 302 Redirect to `/login` with error message

**Example**:
```
GET /auth/google/callback?code=4/0AY0e-g7...&state=random_token

→ (Server exchanges code for token, fetches user info, creates/updates user)
→ 302 Redirect to: /game
   Set-Cookie: _sudoku_versus_key=...
```

**Implementation**:
```elixir
defmodule SudokuVersusWeb.AuthController do
  use SudokuVersusWeb, :controller
  alias SudokuVersus.Accounts
  alias SudokuVersus.Accounts.OAuth

  def callback(conn, %{"provider" => provider, "code" => code}) do
    provider_atom = String.to_existing_atom(provider)

    with {:ok, token_response} <- OAuth.fetch_token(provider_atom, code),
         access_token = token_response.body["access_token"],
         {:ok, user_info} <- OAuth.fetch_user_info(provider_atom, access_token),
         {:ok, user} <- Accounts.find_or_create_oauth_user(provider_atom, user_info.body) do

      conn
      |> put_session(:user_id, user.id)
      |> put_flash(:info, "Welcome, #{user.display_name}!")
      |> redirect(to: "/game")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: "/login")
    end
  end

  def callback(conn, %{"error" => error}) do
    conn
    |> put_flash(:error, "Authentication cancelled or failed: #{error}")
    |> redirect(to: "/login")
  end
end
```

---

### 3. Logout

**Endpoint**: `DELETE /auth/logout`
**Description**: Terminates user session

**Response**: HTTP 302 Redirect to `/`

**Example**:
```
DELETE /auth/logout

→ (Clears session)
→ 302 Redirect to: /
```

**Implementation**:
```elixir
defmodule SudokuVersusWeb.AuthController do
  use SudokuVersusWeb, :controller

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: "/")
  end
end
```

---

## Router Configuration

```elixir
# lib/sudoku_versus_web/router.ex
defmodule SudokuVersusWeb.Router do
  use SudokuVersusWeb, :router

  # ...

  scope "/auth", SudokuVersusWeb do
    pipe_through :browser

    get "/:provider", AuthController, :authorize
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :logout
  end
end
```

---

## OAuth Provider Configuration

### Environment Variables

```elixir
# config/runtime.exs
config :sudoku_versus,
  google_client_id: System.get_env("GOOGLE_CLIENT_ID"),
  google_client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  github_client_id: System.get_env("GITHUB_CLIENT_ID"),
  github_client_secret: System.get_env("GITHUB_CLIENT_SECRET"),
  app_url: System.get_env("APP_URL") || "http://localhost:4000"
```

### Provider Details

#### Google OAuth 2.0

- **Authorization URL**: `https://accounts.google.com/o/oauth2/v2/auth`
- **Token URL**: `https://oauth2.googleapis.com/token`
- **User Info URL**: `https://www.googleapis.com/oauth2/v2/userinfo`
- **Scopes**: `email profile`
- **Redirect URI**: `{APP_URL}/auth/google/callback`

#### GitHub OAuth

- **Authorization URL**: `https://github.com/login/oauth/authorize`
- **Token URL**: `https://github.com/login/oauth/access_token`
- **User Info URL**: `https://api.github.com/user`
- **Scopes**: `read:user user:email`
- **Redirect URI**: `{APP_URL}/auth/github/callback`

---

## Security Considerations

1. **CSRF Protection**: Include `state` parameter in OAuth flow (random token verified on callback)
2. **HTTPS Only**: OAuth callbacks must use HTTPS in production (set in provider console)
3. **Secret Storage**: Store client secrets in environment variables, never commit to source
4. **Session Security**: Use `put_session_options` with `secure: true, http_only: true` in production
5. **Token Expiry**: Don't store OAuth access tokens; request new token on each auth flow

---

## Error Handling

### Common Error Scenarios

| Error | HTTP Status | Action |
|-------|-------------|--------|
| Invalid provider | 404 Not Found | Redirect to `/login` with error |
| Missing code param | 400 Bad Request | Redirect to `/login` with error |
| Token exchange failed | 502 Bad Gateway | Redirect to `/login` with retry message |
| User info fetch failed | 502 Bad Gateway | Redirect to `/login` with retry message |
| Account creation failed | 500 Internal Server Error | Log error, redirect to `/login` |

---

## Testing

### Controller Tests

```elixir
# test/sudoku_versus_web/controllers/auth_controller_test.exs
defmodule SudokuVersusWeb.AuthControllerTest do
  use SudokuVersusWeb.ConnCase

  describe "GET /auth/:provider" do
    test "redirects to Google OAuth", %{conn: conn} do
      conn = get(conn, "/auth/google")
      assert redirected_to(conn, 302) =~ "accounts.google.com"
    end

    test "redirects to GitHub OAuth", %{conn: conn} do
      conn = get(conn, "/auth/github")
      assert redirected_to(conn, 302) =~ "github.com/login/oauth"
    end

    test "returns 404 for invalid provider", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, "/auth/invalid_provider")
      end
    end
  end

  describe "GET /auth/:provider/callback" do
    # Mock OAuth responses with Req.Test
    test "creates user and redirects to game on successful auth", %{conn: conn} do
      # Test implementation with mocked responses
    end

    test "redirects to login on auth error", %{conn: conn} do
      conn = get(conn, "/auth/google/callback?error=access_denied")
      assert redirected_to(conn) == "/login"
      assert get_flash(conn, :error) =~ "cancelled or failed"
    end
  end

  describe "DELETE /auth/logout" do
    test "clears session and redirects to home", %{conn: conn} do
      conn =
        conn
        |> put_session(:user_id, "user-123")
        |> delete("/auth/logout")

      assert redirected_to(conn) == "/"
      assert get_session(conn, :user_id) == nil
    end
  end
end
```

---

## Next Steps
1. Implement `SudokuVersus.Accounts.OAuth` module with `Req` library
2. Create `AuthController` with authorize, callback, logout actions
3. Add router configuration for `/auth/*` routes
4. Write controller tests with mocked OAuth responses
5. Document OAuth setup in `quickstart.md`
