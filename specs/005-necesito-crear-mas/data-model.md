# Data Model: High-Performance Puzzle Generation

**Feature**: 005-necesito-crear-mas
**Date**: 2025-10-02
**Status**: Complete

## Entity Definitions

### Puzzle (Enhanced)

**Purpose**: Represents a generated Sudoku puzzle with partial cell values for any supported grid size.

**Schema**: `lib/sudoku_versus/puzzles/puzzle.ex`

**Attributes**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | `binary_id` | Primary key | UUID |
| `size` | `integer` | Required, in [9,16,25,36,49,100] | Grid dimension (NxN) |
| `difficulty` | `Ecto.Enum` | [:easy, :medium, :hard, :expert] | Puzzle difficulty level |
| `grid` | `jsonb` | Required, length=size² | Partial grid (0=empty, 1-N=clue) |
| `solution` | `jsonb` | Required, length=size² | Complete solved grid (1-N) |
| `clues_count` | `integer` | Required, >0 | Number of pre-filled cells |
| `sub_grid_size` | `integer` | Required | Sub-grid dimension (√N) |
| `inserted_at` | `naive_datetime` | Auto | Creation timestamp |
| `updated_at` | `naive_datetime` | Auto | Last update timestamp |

**Relationships**:
- `has_many :game_rooms` - A puzzle can be used in multiple game rooms (reusable, though spec says on-demand)

**Validations**:
- `size` must be one of [9, 16, 25, 36, 49, 100]
- `grid` must be JSON array of length `size * size`
- `solution` must be JSON array of length `size * size`
- `clues_count` must match non-zero values in `grid`
- `sub_grid_size` must equal `√size` (integer)
- `solution` must contain all integers 1..N exactly N times per row, column, sub-grid

**Indexes**:
- `size` - Filter puzzles by size
- `difficulty` - Filter by difficulty
- `inserted_at` - Sort by creation time

**Example**:
```elixir
%Puzzle{
  id: "550e8400-e29b-41d4-a716-446655440000",
  size: 16,
  difficulty: :medium,
  grid: [0, 0, 3, 4, ...],  # 256 elements, ~45% filled
  solution: [1, 2, 3, 4, ...],  # 256 elements, fully solved
  clues_count: 115,
  sub_grid_size: 4,
  inserted_at: ~N[2025-10-02 12:00:00],
  updated_at: ~N[2025-10-02 12:00:00]
}
```

---

### GameRoom (Enhanced)

**Purpose**: Represents a multiplayer game room with enhanced support for multi-size puzzles.

**Schema**: `lib/sudoku_versus/game_rooms/game_room.ex`

**Modified Attributes**:
| Field | Type | Change | Description |
|-------|------|--------|-------------|
| `puzzle_id` | `binary_id` | Existing | FK to puzzles table |
| All other fields | Various | Unchanged | Existing game room fields |

**Enhanced Relationships**:
- `belongs_to :puzzle, Puzzle` - Must preload puzzle to access size, difficulty

**Migration Required**:
- No schema changes needed (puzzle_id FK already exists)
- Existing 16×16 puzzles work as-is
- New puzzles created with explicit size

---

### Move (No Changes)

**Purpose**: Records player moves in a game with validation status.

**Schema**: `lib/sudoku_versus/game_rooms/move.ex`

**Validation Enhancement**:
- Use `puzzle.solution[index]` for O(1) correctness check
- Index calculation: `row * puzzle.size + col`
- Return boolean without recomputing solution

**No schema changes required**

---

### PlayerSession (No Changes)

**Purpose**: Tracks player participation and progress in a game room.

**Schema**: `lib/sudoku_versus/game_rooms/player_session.ex`

**No changes required** - works with any puzzle size

---

## State Transitions

### Puzzle Generation State Machine

```
[User Creates Room]
       ↓
   [GENERATING] ← Loading spinner shown
       ↓
 [Rust NIF Called]
       ↓
 ┌─────────────┐
 │ Success?    │
 └─────────────┘
    ↓        ↓
  [YES]    [NO]
    ↓        ↓
[COMPLETE] [RETRY] → max 3 attempts → [ERROR]
    ↓
[Puzzle Saved to DB]
    ↓
[Room Created]
```

**States**:
- **GENERATING**: NIF task running, UI blocked with spinner
- **COMPLETE**: Puzzle and solution ready, saved to DB
- **RETRY**: Generation failed, attempting again (auto)
- **ERROR**: Max retries exceeded, show error to user

**Timeouts by Size**:
- 9×9: 50ms + 50ms buffer = 100ms total
- 16×16: 100ms + 100ms buffer = 200ms total
- 25×25: 500ms + 500ms buffer = 1s total
- 36×36: 1s + 1s buffer = 2s total
- 49×49: 2s + 2s buffer = 4s total
- 100×100: 5s + 5s buffer = 10s total

---

## Data Flow

### Puzzle Generation Flow

```
LiveView (GameLive.Index)
       ↓ handle_event("create_room", %{size, difficulty})
Puzzles Context
       ↓ generate_puzzle_async(size, difficulty)
Task.async
       ↓ Puzzles.Generator.generate(size, difficulty)
Rust NIF (dirty_cpu)
       ↓ backtracking algorithm
{grid, solution}
       ↓ return to Elixir
Puzzles.create_puzzle(%{grid, solution, size, ...})
       ↓ Ecto insert
Database (puzzles table)
       ↓ puzzle_id
GameRooms.create_room(%{puzzle_id, ...})
       ↓ Ecto insert
Database (game_rooms table)
       ↓
LiveView redirects to game room
```

### Move Validation Flow

```
LiveView (GameLive.Show)
       ↓ handle_event("submit_move", %{row, col, value})
Puzzles.Validator.validate_move(puzzle, row, col, value)
       ↓ calculate index = row * size + col
       ↓ lookup solution[index]
       ↓ compare value == solution[index]
{:ok, is_correct}
       ↓
Moves.create_move(%{is_correct, ...})
       ↓
Update player session (score, streak)
       ↓
Broadcast move to room via PubSub
       ↓
LiveView updates UI
```

---

## Database Schema Changes

### Migration: Add Multi-Size Puzzle Support

**File**: `priv/repo/migrations/XXX_add_puzzle_size_support.exs`

**Changes**:
```elixir
defmodule SudokuVersus.Repo.Migrations.AddPuzzleSizeSupport do
  use Ecto.Migration

  def change do
    # Add size column to puzzles (default 16 for backward compatibility)
    alter table(:puzzles) do
      add :size, :integer, null: false, default: 16
      add :sub_grid_size, :integer, null: false, default: 4
      add :clues_count, :integer, null: false, default: 0
    end

    # Add indexes for filtering
    create index(:puzzles, [:size])
    create index(:puzzles, [:difficulty])
    create index(:puzzles, [:size, :difficulty])

    # Update existing puzzles to have correct metadata
    execute("""
      UPDATE puzzles
      SET clues_count = (
        SELECT COUNT(*)
        FROM jsonb_array_elements(grid) AS elem
        WHERE elem::int > 0
      )
      WHERE clues_count = 0
    """)
  end
end
```

**Backward Compatibility**:
- Existing 16×16 puzzles get `size=16, sub_grid_size=4` automatically
- No data migration needed (grid/solution already JSONB)
- Existing game rooms continue working

---

## Query Patterns

### Common Queries

**Generate Puzzle** (not stored, on-demand):
```elixir
# In Puzzles context
def generate_puzzle(size, difficulty) do
  case Puzzles.Generator.generate(size, difficulty) do
    {:ok, %{grid: grid, solution: solution}} ->
      %Puzzle{}
      |> Puzzle.changeset(%{
        size: size,
        difficulty: difficulty,
        grid: grid,
        solution: solution,
        clues_count: count_clues(grid),
        sub_grid_size: trunc(:math.sqrt(size))
      })
      |> Repo.insert()

    {:error, reason} -> {:error, reason}
  end
end
```

**Validate Move** (O(1) lookup):
```elixir
def validate_move(%Puzzle{} = puzzle, row, col, value) do
  index = row * puzzle.size + col
  correct_value = Enum.at(puzzle.solution, index)
  {:ok, value == correct_value}
end
```

**Load Puzzle with Solution** (preload):
```elixir
def get_puzzle_with_solution!(id) do
  Puzzle
  |> Repo.get!(id)
  # Solution already in struct, no join needed
end
```

---

## Performance Considerations

### Storage Size Estimates

| Puzzle Size | Grid Elements | Storage (JSONB) | Notes |
|-------------|---------------|-----------------|-------|
| 9×9         | 81            | ~500 bytes      | Minimal |
| 16×16       | 256           | ~1.5 KB         | Current |
| 25×25       | 625           | ~4 KB           | Medium |
| 36×36       | 1,296         | ~8 KB           | Large |
| 49×49       | 2,401         | ~15 KB          | Very large |
| 100×100     | 10,000        | ~60 KB          | Maximum |

**Total per puzzle**: 2× storage (grid + solution)

**Database Growth**:
- 1000 games/day × 60KB max = 60MB/day worst case
- Typical (mostly 9×9, 16×16): ~5MB/day
- Monthly: ~150MB growth
- **Acceptable** without archival strategy

### Query Performance

**Puzzle Lookup** (by ID):
- O(1) with primary key index
- <1ms response time
- Solution included in same row (no JOIN)

**Move Validation**:
- O(1) array index lookup
- In-memory operation
- <1ms response time
- Meets <5ms requirement easily

---

## Constraints & Business Rules

### Puzzle Generation Rules

1. **Size Constraint**: Only [9, 16, 25, 36, 49, 100] supported
2. **Difficulty Constraint**: Clue percentage must match difficulty tier
3. **Uniqueness Constraint**: Puzzle must have exactly one solution
4. **Solvability Constraint**: Puzzle must be solvable via logical deduction (easy/medium)
5. **Performance Constraint**: Generation must complete within size-specific timeout

### Move Validation Rules

1. **Range Constraint**: Move value must be 1..N where N=size
2. **Empty Cell Constraint**: Can only fill empty cells (grid[index] == 0)
3. **Correctness Constraint**: Value must match solution[index]
4. **Immutable Clue Constraint**: Cannot overwrite pre-filled cells

### Data Integrity Rules

1. **Grid-Solution Sync**: Solution must be valid solution for grid
2. **Clue Count Accuracy**: clues_count must match non-zero grid values
3. **Sub-Grid Size**: Must equal √size (integer perfect square)
4. **Foreign Key Integrity**: GameRoom.puzzle_id must reference valid Puzzle

---

## Testing Data Fixtures

### Fixture: Small Puzzle (9×9)
```elixir
@puzzle_9x9 %{
  size: 9,
  difficulty: :easy,
  grid: [5,3,0, 0,7,0, 0,0,0,
         6,0,0, 1,9,5, 0,0,0,
         ...],  # 81 elements, ~55% filled
  solution: [5,3,4, 6,7,8, 9,1,2,
             6,7,2, 1,9,5, 3,4,8,
             ...],  # 81 elements, complete
  clues_count: 45,
  sub_grid_size: 3
}
```

### Fixture: Large Puzzle (100×100)
```elixir
@puzzle_100x100 %{
  size: 100,
  difficulty: :expert,
  grid: [1, 0, 0, 0, ...],  # 10,000 elements, ~22% filled
  solution: [1, 2, 3, 4, ...],  # 10,000 elements, complete
  clues_count: 2200,
  sub_grid_size: 10
}
```

---

**Status**: ✅ Data Model Complete | **Next**: Contracts & Quickstart
