defmodule SudokuVersus.Puzzles.Generator do
  @moduledoc """
  Elixir wrapper for Rust NIF puzzle generator.

  This module provides high-performance Sudoku puzzle generation using Rust NIFs.
  """

  use Rustler, otp_app: :sudoku_versus, crate: "sudoku_generator"

  # Placeholder function - will be replaced when NIF is loaded
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
