defmodule SudokuVersusWeb.Router do
  use SudokuVersusWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SudokuVersusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # OAuth routes
  scope "/auth", SudokuVersusWeb do
    pipe_through :browser

    get "/:provider", AuthController, :authorize
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :logout
  end

  # Public routes (no auth required)
  scope "/", SudokuVersusWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/login/guest", AuthLive.Guest, :new
    live "/register", AuthLive.Register, :new
    live "/leaderboard", LeaderboardLive.Index, :index
  end

  # Protected routes (auth required)
  scope "/", SudokuVersusWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: {SudokuVersusWeb.Plugs.Authenticate, :default} do
      live "/game", GameLive.Index, :index
      live "/game/:id", GameLive.Show, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", SudokuVersusWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sudoku_versus, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SudokuVersusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
