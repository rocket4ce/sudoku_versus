defmodule SudokuVersusWeb.PageController do
  use SudokuVersusWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
