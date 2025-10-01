defmodule SudokuVersus.Repo do
  use Ecto.Repo,
    otp_app: :sudoku_versus,
    adapter: Ecto.Adapters.Postgres
end
