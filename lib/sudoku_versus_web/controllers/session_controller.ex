defmodule SudokuVersusWeb.SessionController do
  use SudokuVersusWeb, :controller

  @doc """
  Creates a session for a user and redirects to the specified path.

  This controller is used by LiveViews that need to establish a user session,
  since LiveViews cannot directly modify the session after mount.

  Accepts both GET and POST requests to support LiveView redirects.
  """
  def create(conn, params) do
    user_id = params["user_id"]
    redirect_to = params["redirect_to"] || ~p"/game"

    conn
    |> put_session(:user_id, user_id)
    |> redirect(to: redirect_to)
  end
end
