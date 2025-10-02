defmodule SudokuVersusWeb.AuthLive.Register do
  use SudokuVersusWeb, :live_view

  alias SudokuVersus.Accounts
  alias SudokuVersus.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})

    socket =
      socket
      |> assign(:page_title, "Register")
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Redirect to session controller to set session, then to game
        form_data = %{
          "user_id" => user.id,
          "redirect_to" => ~p"/game"
        }

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully! Welcome, #{user.username}!")
         |> redirect(to: ~p"/session/create?#{form_data}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
