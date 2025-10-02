defmodule SudokuVersusWeb.AuthLive.Guest do
  use SudokuVersusWeb, :live_view

  alias SudokuVersus.Accounts
  alias SudokuVersus.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = User.guest_changeset(%User{}, %{})

    socket =
      socket
      |> assign(:page_title, "Guest Login")
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.create_guest_user(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome, #{user.username}!")
         |> push_navigate(to: ~p"/game")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
