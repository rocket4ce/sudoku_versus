defmodule SudokuVersusWeb.Plugs.Authenticate do
  @moduledoc """
  Plug for authenticating users and loading current_user into conn/socket assigns.

  This plug checks the session for a user_id and loads the corresponding user
  from the database. If no user is found or the session is missing, it redirects
  to the guest login page.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias SudokuVersus.Accounts

  @doc """
  Initializes the plug with options.
  """
  def init(opts), do: opts

  @doc """
  Loads the current user from the session.

  If a user_id exists in the session, loads the user and assigns it to conn.
  If no user_id or user not found, redirects to /login/guest.
  """
  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      case Accounts.get_user(user_id) do
        nil ->
          conn
          |> put_flash(:error, "You must be logged in to access this page.")
          |> redirect(to: "/login/guest")
          |> halt()

        user ->
          assign(conn, :current_user, user)
      end
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: "/login/guest")
      |> halt()
    end
  end

  @doc """
  Loads the current user for LiveView sockets.

  This function is called in the on_mount hook for LiveView sessions.
  Returns {:cont, socket} if user is authenticated, {:halt, socket} otherwise.
  """
  def on_mount(:default, _params, session, socket) do
    user_id = session["user_id"]

    case user_id && Accounts.get_user(user_id) do
      %Accounts.User{} = user ->
        {:cont, Phoenix.Component.assign(socket, :current_user, user)}

      _ ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
          |> Phoenix.LiveView.redirect(to: "/login/guest")

        {:halt, socket}
    end
  end
end
