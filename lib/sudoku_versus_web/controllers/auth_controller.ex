defmodule SudokuVersusWeb.AuthController do
  use SudokuVersusWeb, :controller

  alias SudokuVersus.Accounts
  alias SudokuVersus.Accounts.OAuth

  @doc """
  Redirects to the OAuth provider's authorization page.

  Supported providers: "google", "github"
  """
  def authorize(conn, %{"provider" => provider}) when provider in ["google", "github"] do
    authorize_url = OAuth.authorize_url(provider)
    redirect(conn, external: authorize_url)
  end

  @doc """
  Handles the OAuth callback from the provider.

  Creates or finds the user and logs them in by setting the session.
  """
  def callback(conn, %{"provider" => provider, "code" => code})
      when provider in ["google", "github"] do
    with {:ok, token} <- OAuth.fetch_token(provider, code),
         {:ok, user_info} <- OAuth.fetch_user_info(provider, token),
         {:ok, user} <- Accounts.find_or_create_oauth_user(provider, user_info) do
      conn
      |> put_flash(:info, "Successfully authenticated with #{String.capitalize(provider)}!")
      |> put_session(:user_id, user.id)
      |> redirect(to: ~p"/")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: ~p"/login/guest")
    end
  end

  def callback(conn, %{"provider" => _provider, "error" => error}) do
    conn
    |> put_flash(:error, "Authentication failed: #{error}")
    |> redirect(to: ~p"/login/guest")
  end

  def callback(conn, %{"provider" => _provider}) do
    conn
    |> put_flash(:error, "Authentication failed: Missing authorization code")
    |> redirect(to: ~p"/login/guest")
  end

  @doc """
  Logs out the current user by clearing the session.
  """
  def logout(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out successfully.")
    |> clear_session()
    |> redirect(to: ~p"/")
  end
end
