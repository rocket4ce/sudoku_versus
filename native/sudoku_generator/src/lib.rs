// Placeholder NIF module - will be implemented in later tasks
rustler::init!("Elixir.SudokuVersus.Puzzles.Generator");

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}
