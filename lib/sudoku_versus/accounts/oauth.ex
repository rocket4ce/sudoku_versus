defmodule SudokuVersus.Accounts.OAuth do
  @moduledoc """
  OAuth 2.0 authentication module for Google and GitHub.

  Uses the Req HTTP client library for making OAuth requests.
  Configuration is read from environment variables:
  - GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
  - GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET
  - OAUTH_REDIRECT_URI (defaults to http://localhost:4000/auth/:provider/callback)
  """

  @doc """
  Generates the OAuth authorization URL for the given provider.

  ## Examples

      iex> authorize_url("google")
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=...&redirect_uri=...&scope=..."

      iex> authorize_url("github")
      "https://github.com/login/oauth/authorize?client_id=...&redirect_uri=..."
  """
  def authorize_url("google") do
    params = %{
      client_id: google_client_id(),
      redirect_uri: redirect_uri("google"),
      response_type: "code",
      scope: "openid email profile"
    }

    "https://accounts.google.com/o/oauth2/v2/auth?" <> URI.encode_query(params)
  end

  def authorize_url("github") do
    params = %{
      client_id: github_client_id(),
      redirect_uri: redirect_uri("github"),
      scope: "user:email"
    }

    "https://github.com/login/oauth/authorize?" <> URI.encode_query(params)
  end

  @doc """
  Exchanges an authorization code for an access token.

  ## Examples

      iex> fetch_token("google", "auth_code_123")
      {:ok, "access_token_xyz"}

      iex> fetch_token("google", "invalid_code")
      {:error, "invalid_grant"}
  """
  def fetch_token("google", code) do
    body = %{
      code: code,
      client_id: google_client_id(),
      client_secret: google_client_secret(),
      redirect_uri: redirect_uri("google"),
      grant_type: "authorization_code"
    }

    case Req.post("https://oauth2.googleapis.com/token", json: body) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch_token("github", code) do
    body = %{
      code: code,
      client_id: github_client_id(),
      client_secret: github_client_secret(),
      redirect_uri: redirect_uri("github")
    }

    headers = [{"accept", "application/json"}]

    case Req.post("https://github.com/login/oauth/access_token",
           json: body,
           headers: headers
         ) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches user information from the OAuth provider using an access token.

  ## Examples

      iex> fetch_user_info("google", "access_token_xyz")
      {:ok, %{"sub" => "12345", "email" => "user@gmail.com", "name" => "John Doe"}}

      iex> fetch_user_info("github", "access_token_xyz")
      {:ok, %{"id" => 12345, "email" => "user@github.com", "login" => "johndoe"}}
  """
  def fetch_user_info("google", token) do
    headers = [{"authorization", "Bearer #{token}"}]

    case Req.get("https://www.googleapis.com/oauth2/v3/userinfo", headers: headers) do
      {:ok, %{status: 200, body: user_info}} ->
        {:ok, user_info}

      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch_user_info("github", token) do
    headers = [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/json"}
    ]

    with {:ok, %{status: 200, body: user_info}} <-
           Req.get("https://api.github.com/user", headers: headers),
         {:ok, emails} <- fetch_github_emails(token) do
      # GitHub user endpoint doesn't always include email, fetch separately
      primary_email = Enum.find(emails, & &1["primary"]) || List.first(emails)
      user_info_with_email = Map.put(user_info, "email", primary_email["email"])
      {:ok, user_info_with_email}
    else
      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helpers

  defp fetch_github_emails(token) do
    headers = [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/json"}
    ]

    case Req.get("https://api.github.com/user/emails", headers: headers) do
      {:ok, %{status: 200, body: emails}} when is_list(emails) ->
        {:ok, emails}

      {:ok, %{status: 200, body: _}} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp google_client_id do
    System.get_env("GOOGLE_CLIENT_ID") || "test_google_client_id"
  end

  defp google_client_secret do
    System.get_env("GOOGLE_CLIENT_SECRET") || "test_google_client_secret"
  end

  defp github_client_id do
    System.get_env("GITHUB_CLIENT_ID") || "test_github_client_id"
  end

  defp github_client_secret do
    System.get_env("GITHUB_CLIENT_SECRET") || "test_github_client_secret"
  end

  defp redirect_uri(provider) do
    base_url = System.get_env("OAUTH_REDIRECT_URI") || "http://localhost:4000"
    "#{base_url}/auth/#{provider}/callback"
  end
end
