# Contract: Puzzles Context API

**Feature**: 005-necesito-crear-mas
**Module**: `SudokuVersus.Puzzles`
**Type**: Internal Elixir Context API

## Overview

The Puzzles context provides the business logic for generating, storing, and validating Sudoku puzzles of varying sizes. This is an internal API called by LiveView and other contexts.

---

## Functions

### `generate_puzzle(size, difficulty)`

**Purpose**: Generates a new puzzle with pre-computed solution using Rust NIF.

**Signature**:
```elixir
@spec generate_puzzle(integer(), atom()) ::
  {:ok, Puzzle.t()} | {:error, String.t()}
```

**Parameters**:
| Name | Type | Constraints | Description |
|------|------|-------------|-------------|
| `size` | `integer()` | Must be in [9, 16, 25, 36, 49, 100] | Grid dimension (NxN) |
| `difficulty` | `atom()` | Must be in [:easy, :medium, :hard, :expert] | Difficulty level |

**Returns**:
- **Success**: `{:ok, %Puzzle{}}` - Puzzle struct with grid, solution, and metadata
- **Error**: `{:error, "reason"}` - Generation failed (timeout, invalid params, NIF error)

**Side Effects**:
- Calls Rust NIF via `Puzzles.Generator.generate/2`
- Inserts puzzle record into database
- Blocks BEAM scheduler using dirty_cpu

**Performance**:
- 9×9: <50ms (p99 <100ms)
- 16×16: <100ms (p99 <200ms)
- 25×25: <500ms (p99 <1s)
- 36×36: <1s (p99 <2s)
- 49×49: <2s (p99 <4s)
- 100×100: <5s (p99 <10s)

**Example**:
```elixir
case Puzzles.generate_puzzle(16, :medium) do
  {:ok, puzzle} ->
    # puzzle.grid = [0, 0, 3, ...]
    # puzzle.solution = [1, 2, 3, ...]
    # puzzle.size = 16
    {:ok, puzzle}

  {:error, "Generation timeout"} ->
    # Retry or show error to user
    {:error, :timeout}
end
```

**Contract Tests**:
- [ ] Generates valid 9×9 puzzle within 50ms
- [ ] Generates valid 16×16 puzzle within 100ms
- [ ] Generates valid 25×25 puzzle within 500ms
- [ ] Generates valid 36×36 puzzle within 1s
- [ ] Generates valid 49×49 puzzle within 2s
- [ ] Generates valid 100×100 puzzle within 5s
- [ ] Returns error for invalid size (e.g., 10)
- [ ] Returns error for invalid difficulty (e.g., :impossible)
- [ ] Solution is valid complete Sudoku grid
- [ ] Grid matches difficulty clue percentage
- [ ] Puzzle has exactly one solution (uniqueness)

---

### `get_puzzle!(id)`

**Purpose**: Fetches a puzzle by ID with grid and solution preloaded.

**Signature**:
```elixir
@spec get_puzzle!(binary()) :: Puzzle.t()
```

**Parameters**:
| Name | Type | Constraints | Description |
|------|------|-------------|-------------|
| `id` | `binary()` (UUID) | Must exist in database | Puzzle ID |

**Returns**:
- **Success**: `%Puzzle{}` - Puzzle struct with all fields
- **Error**: Raises `Ecto.NoResultsError`

**Performance**: <1ms (indexed lookup)

**Example**:
```elixir
puzzle = Puzzles.get_puzzle!("550e8400-...")
# puzzle.grid loaded
# puzzle.solution loaded
```

**Contract Tests**:
- [ ] Returns puzzle with grid and solution
- [ ] Raises for non-existent ID

---

### `validate_move(puzzle, row, col, value)`

**Purpose**: Validates a player move against the pre-computed solution.

**Signature**:
```elixir
@spec validate_move(Puzzle.t(), integer(), integer(), integer()) ::
  {:ok, boolean()} | {:error, String.t()}
```

**Parameters**:
| Name | Type | Constraints | Description |
|------|------|-------------|-------------|
| `puzzle` | `Puzzle.t()` | Must have solution loaded | Puzzle struct |
| `row` | `integer()` | 0 <= row < puzzle.size | Row index (0-based) |
| `col` | `integer()` | 0 <= col < puzzle.size | Column index (0-based) |
| `value` | `integer()` | 1 <= value <= puzzle.size | Player's move value |

**Returns**:
- **Success**: `{:ok, true}` - Move is correct
- **Success**: `{:ok, false}` - Move is incorrect
- **Error**: `{:error, "reason"}` - Invalid parameters

**Side Effects**: None (pure lookup)

**Performance**: <5ms (O(1) array index lookup)

**Algorithm**:
```elixir
index = row * puzzle.size + col
correct_value = Enum.at(puzzle.solution, index)
{:ok, value == correct_value}
```

**Example**:
```elixir
case Puzzles.validate_move(puzzle, 0, 0, 5) do
  {:ok, true} -> # Correct move
  {:ok, false} -> # Incorrect move
  {:error, "Invalid row"} -> # Row out of bounds
end
```

**Contract Tests**:
- [ ] Returns true for correct move
- [ ] Returns false for incorrect move
- [ ] Returns error for row < 0
- [ ] Returns error for row >= size
- [ ] Returns error for col < 0
- [ ] Returns error for col >= size
- [ ] Returns error for value < 1
- [ ] Returns error for value > size
- [ ] Completes in <5ms for all puzzle sizes

---

### `list_puzzles_by_size_and_difficulty(size, difficulty)`

**Purpose**: Lists recent puzzles by size and difficulty (for testing/debugging).

**Signature**:
```elixir
@spec list_puzzles_by_size_and_difficulty(integer(), atom()) :: [Puzzle.t()]
```

**Parameters**:
| Name | Type | Constraints | Description |
|------|------|-------------|-------------|
| `size` | `integer()` | Must be in [9, 16, 25, 36, 49, 100] | Grid size |
| `difficulty` | `atom()` | Must be in [:easy, :medium, :hard, :expert] | Difficulty |

**Returns**:
- List of matching puzzles, ordered by `inserted_at DESC`
- Limit 50 results

**Example**:
```elixir
puzzles = Puzzles.list_puzzles_by_size_and_difficulty(16, :medium)
# Returns up to 50 recent 16×16 medium puzzles
```

**Contract Tests**:
- [ ] Returns puzzles matching criteria
- [ ] Returns empty list if no matches
- [ ] Orders by inserted_at DESC
- [ ] Limits to 50 results

---

## Error Codes

| Error Code | Meaning | User Action |
|------------|---------|-------------|
| `"Invalid size"` | Size not in [9,16,25,36,49,100] | Select valid size |
| `"Invalid difficulty"` | Difficulty not in valid set | Select valid difficulty |
| `"Generation timeout"` | NIF took too long | Retry generation |
| `"Generation failed"` | NIF internal error | Retry or report bug |
| `"Invalid row"` | Row index out of bounds | Check row value |
| `"Invalid col"` | Column index out of bounds | Check col value |
| `"Invalid value"` | Value outside 1..N range | Check move value |

---

## Performance Requirements

| Operation | Target | Measurement |
|-----------|--------|-------------|
| `generate_puzzle(9, _)` | <50ms avg | p99 <100ms |
| `generate_puzzle(16, _)` | <100ms avg | p99 <200ms |
| `generate_puzzle(25, _)` | <500ms avg | p99 <1s |
| `generate_puzzle(36, _)` | <1s avg | p99 <2s |
| `generate_puzzle(49, _)` | <2s avg | p99 <4s |
| `generate_puzzle(100, _)` | <5s avg | p99 <10s |
| `get_puzzle!/1` | <1ms | Always |
| `validate_move/4` | <5ms | All sizes |
| `list_puzzles_by_size_and_difficulty/2` | <10ms | Indexed query |

---

## Dependencies

**Internal**:
- `SudokuVersus.Puzzles.Puzzle` (schema)
- `SudokuVersus.Puzzles.Generator` (NIF wrapper)
- `SudokuVersus.Repo` (database)

**External**:
- `Ecto` (queries)
- `Rustler` (NIF bindings)
- Rust `sudoku_generator` (actual generation logic)

---

**Status**: ✅ Contract Complete | **Next**: Implement TDD
