defmodule SudokuVersus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SudokuVersusWeb.Telemetry,
      SudokuVersus.Repo,
      {DNSCluster, query: Application.get_env(:sudoku_versus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SudokuVersus.PubSub},
      SudokuVersusWeb.Presence,
      # Start a worker by calling: SudokuVersus.Worker.start_link(arg)
      # {SudokuVersus.Worker, arg},
      # Start to serve requests, typically the last entry
      SudokuVersusWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SudokuVersus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SudokuVersusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
