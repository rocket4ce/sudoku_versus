# Contract: Rust NIF Module

**Feature**: 005-necesito-criar-mas
**Module**: `SudokuVersus.Puzzles.Generator` (Elixir wrapper)
**Native Module**: `sudoku_generator` (Rust)
**Type**: NIF (Native Implemented Function)

## Overview

The Rust NIF module provides high-performance Sudoku puzzle generation for grids ranging from 9×9 to 100×100. It returns both the partial puzzle grid and complete solution in a single call.

---

## NIF Function

### `generate(size, difficulty_level, seed)`

**Purpose**: Generate a Sudoku puzzle and solution using Rust.

**Elixir Wrapper Signature**:
```elixir
@spec generate(integer(), atom()) :: {:ok, %{grid: list(), solution: list()}} | {:error, String.t()}
```

**Rust Signature**:
```rust
#[rustler::nif(schedule = "DirtyCpu")]
fn generate(size: i32, difficulty_level: i32, seed: u64) -> Result<PuzzleResult, String>
```

**Parameters**:
| Name | Type (Elixir) | Type (Rust) | Constraints | Description |
|------|---------------|-------------|-------------|-------------|
| `size` | `integer()` | `i32` | Must be in [9,16,25,36,49,100] | Grid dimension (NxN) |
| `difficulty` | `atom()` | `i32` (encoded) | 0=easy, 1=medium, 2=hard, 3=expert | Difficulty level |
| `seed` | (auto) | `u64` | Random | RNG seed for reproducibility |

**Note**: `seed` is auto-generated in Elixir wrapper using `:erlang.system_time()` for production. Can be overridden in tests for deterministic generation.

**Returns**:

**Success** - `{:ok, %{grid: grid, solution: solution}}`
- `grid`: List of integers (length = size²), values 0..size (0 = empty)
- `solution`: List of integers (length = size²), values 1..size (complete)

**Error** - `{:error, reason}`
- `"Invalid size"`: Size not supported
- `"Generation failed"`: Algorithm failed to generate valid puzzle
- `"Timeout"`: Generation exceeded time limit
- `"Invalid difficulty"`: Difficulty level out of range

**Rust Return Type**:
```rust
pub struct PuzzleResult {
    pub grid: Vec<i32>,      // Partial puzzle (0 = empty)
    pub solution: Vec<i32>,  // Complete solution
}
```

**Example Usage (Elixir)**:
```elixir
# Production usage (auto-seed)
case SudokuVersus.Puzzles.Generator.generate(16, :medium) do
  {:ok, %{grid: grid, solution: solution}} ->
    # grid = [0, 0, 3, 4, ...]  (256 elements)
    # solution = [1, 2, 3, 4, ...]  (256 elements)
    {:ok, grid, solution}

  {:error, reason} ->
    {:error, reason}
end

# Test usage (fixed seed for reproducibility)
{:ok, %{grid: grid, solution: solution}} =
  SudokuVersus.Puzzles.Generator.generate(9, :easy, 12345)
```

---

## Algorithm Requirements

### Generation Process

**Phase 1: Solution Generation**
1. Create empty N×N grid
2. Fill using backtracking with constraint propagation
3. Constraints: Each row, column, sub-grid contains 1..N exactly once
4. Use optimized heuristics for large grids (N ≥ 36)

**Phase 2: Puzzle Extraction**
1. Start with complete solution
2. Remove cells strategically based on difficulty
3. Ensure unique solution (verify with solver)
4. Target clue counts:
   - Easy: 50-60% of cells
   - Medium: 35-45% of cells
   - Hard: 25-35% of cells
   - Expert: 20-25% of cells

**Phase 3: Validation**
1. Verify solution is valid (all constraints satisfied)
2. Verify puzzle has exactly one solution
3. Return both grid and solution

### Performance Constraints

| Grid Size | Target Time | Max Time | Notes |
|-----------|-------------|----------|-------|
| 9×9       | <25ms       | 50ms     | Simple backtracking |
| 16×16     | <50ms       | 100ms    | Constraint propagation |
| 25×25     | <250ms      | 500ms    | Optimized heuristics |
| 36×36     | <500ms      | 1s       | Parallel sub-grids |
| 49×49     | <1s         | 2s       | Advanced pruning |
| 100×100   | <2.5s       | 5s       | Divide & conquer |

**All timing includes**:
- Solution generation
- Puzzle extraction
- Uniqueness validation
- Elixir term conversion

---

## Rust Implementation Details

### Module Structure

**File**: `native/sudoku_generator/src/lib.rs`
```rust
use rustler::{Env, Term, NifResult, Encoder};

rustler::init!("Elixir.SudokuVersus.Puzzles.Generator", [generate]);

#[rustler::nif(schedule = "DirtyCpu")]
fn generate(size: i32, difficulty_level: i32, seed: u64) -> Result<PuzzleResult, String> {
    // Implementation
}
```

**Key Files**:
- `lib.rs`: NIF interface and term conversion
- `generator.rs`: Core puzzle generation algorithm
- `solver.rs`: Fast solution validation
- `difficulty.rs`: Difficulty calculation and cell removal

### Error Handling

**Rust Errors → Elixir Errors**:
- Rust `Result::Err(String)` → Elixir `{:error, reason}`
- Rust panic (should never happen) → NIF crashes BEAM scheduler (bad)
- Use `Result` everywhere, never panic in NIF code

**Timeout Handling**:
- Elixir wrapper uses `Task.await(timeout)` to enforce timeouts
- Rust NIF should complete quickly, but Elixir enforces hard limit
- If timeout: Task killed, return `{:error, "Timeout"}`

### Memory Management

**Allocations**:
- Grid vector: `size² * sizeof(i32)` ≈ 40KB for 100×100
- Temporary working memory: ~3× grid size during generation
- Total peak: ~150KB for 100×100 (well within limits)

**Deallocation**:
- Rust manages memory automatically (no manual free)
- Rustler handles term conversion and cleanup
- No memory leaks if Result is properly used

---

## Testing Strategy

### Unit Tests (Rust)

**File**: `native/sudoku_generator/src/tests.rs`

**Test Cases**:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_9x9_easy() {
        let result = internal_generate(9, 0, 12345);
        assert!(result.is_ok());
        let puzzle = result.unwrap();
        assert_eq!(puzzle.grid.len(), 81);
        assert_eq!(puzzle.solution.len(), 81);
        assert!(is_valid_solution(&puzzle.solution, 9));
        assert_clue_count_in_range(&puzzle.grid, 45, 54); // 50-60%
    }

    #[test]
    fn test_generate_100x100_expert() {
        let result = internal_generate(100, 3, 12345);
        assert!(result.is_ok());
        let puzzle = result.unwrap();
        assert_eq!(puzzle.grid.len(), 10000);
        assert_clue_count_in_range(&puzzle.grid, 2000, 2500); // 20-25%
    }

    #[test]
    fn test_invalid_size() {
        let result = internal_generate(10, 0, 12345);
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "Invalid size");
    }

    #[test]
    fn test_solution_uniqueness() {
        let result = internal_generate(9, 2, 12345);
        assert!(result.is_ok());
        let puzzle = result.unwrap();
        assert!(has_unique_solution(&puzzle.grid, 9));
    }
}
```

### Integration Tests (Elixir)

**File**: `test/sudoku_versus/puzzles/generator_test.exs`

**Test Cases**:
```elixir
defmodule SudokuVersus.Puzzles.GeneratorTest do
  use ExUnit.Case, async: false

  describe "generate/2" do
    test "generates valid 9x9 easy puzzle" do
      assert {:ok, %{grid: grid, solution: solution}} =
        Generator.generate(9, :easy)

      assert length(grid) == 81
      assert length(solution) == 81
      assert valid_solution?(solution, 9)
      assert clue_percentage(grid) in 50..60
    end

    test "generates valid 100x100 expert puzzle within 5s" do
      {time_us, result} = :timer.tc(fn ->
        Generator.generate(100, :expert)
      end)

      assert {:ok, %{grid: grid, solution: solution}} = result
      assert time_us < 5_000_000  # 5 seconds in microseconds
      assert length(grid) == 10_000
    end

    test "returns error for invalid size" do
      assert {:error, "Invalid size"} = Generator.generate(10, :easy)
    end
  end
end
```

---

## Performance Benchmarks

**Benchmark Script**: `priv/scripts/benchmark_generator.exs`

```elixir
sizes = [9, 16, 25, 36, 49, 100]
difficulties = [:easy, :medium, :hard, :expert]

for size <- sizes, difficulty <- difficulties do
  results = for _ <- 1..10 do
    {time_us, _} = :timer.tc(fn ->
      Generator.generate(size, difficulty)
    end)
    time_us / 1_000  # Convert to ms
  end

  avg = Enum.sum(results) / 10
  p99 = Enum.sort(results) |> Enum.at(8)

  IO.puts("#{size}x#{size} #{difficulty}: avg=#{avg}ms, p99=#{p99}ms")
end
```

**Acceptance Criteria**:
- All averages must meet target times
- p99 must be within max times
- No failures or timeouts

---

## Dependencies

**Rust Crates** (`Cargo.toml`):
```toml
[dependencies]
rustler = "0.30"
rand = "0.8"  # For RNG seeding
```

**Elixir Dependencies** (`mix.exs`):
```elixir
{:rustler, "~> 0.30"}
```

---

## Build Configuration

**File**: `mix.exs` (add Rustler configuration)
```elixir
def project do
  [
    # ...
    rustler_crates: [
      sudoku_generator: [
        path: "native/sudoku_generator",
        mode: rustler_mode(Mix.env())
      ]
    ]
  ]
end

defp rustler_mode(:prod), do: :release
defp rustler_mode(_), do: :debug
```

**Compilation**:
- Development: `mix compile` → Rust debug build
- Production: `MIX_ENV=prod mix compile` → Rust release build
- Tests: Rust build automatically triggered before `mix test`

---

**Status**: ✅ NIF Contract Complete | **Next**: Implement with TDD
