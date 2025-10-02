# Quickstart: High-Performance Puzzle Generation

**Feature**: 005-necesito-crear-mas
**Date**: 2025-10-02
**Purpose**: Step-by-step guide to validate the feature works end-to-end

## Prerequisites

- Elixir 1.15+ installed
- PostgreSQL running
- Rust toolchain installed (`rustup`)
- Repository cloned and dependencies installed

## Setup

```bash
# 1. Install dependencies
cd /Users/rocket4ce/sites/elixir/sudoku_versus
mix deps.get

# 2. Ensure Rust toolchain is installed
rustup --version || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 3. Compile Rust NIF module
mix compile

# 4. Setup database with new migration
mix ecto.reset

# 5. Run tests to ensure everything works
mix test
```

---

## Test Scenario 1: Generate Small Puzzle (9×9)

**Goal**: Verify fast generation for standard Sudoku size

### Steps

**1. Start IEx**
```bash
iex -S mix phx.server
```

**2. Generate 9×9 Easy Puzzle**
```elixir
alias SudokuVersus.Puzzles

{:ok, puzzle} = Puzzles.generate_puzzle(9, :easy)
```

**3. Verify Results**
```elixir
# Check puzzle properties
puzzle.size
# => 9

puzzle.difficulty
# => :easy

length(puzzle.grid)
# => 81

length(puzzle.solution)
# => 81

puzzle.clues_count
# => 45-54 (50-60% of 81)

puzzle.sub_grid_size
# => 3

# Verify grid has empty cells
Enum.count(puzzle.grid, & &1 == 0)
# => 27-36 empty cells

# Verify solution is complete
Enum.all?(puzzle.solution, & &1 > 0)
# => true
```

**Expected Time**: <50ms

**Success Criteria**:
- ✅ Puzzle generated without errors
- ✅ Grid size is 81 (9×9)
- ✅ Solution size is 81
- ✅ Clue count in 45-54 range
- ✅ Generation completed in <50ms

---

## Test Scenario 2: Generate Large Puzzle (100×100)

**Goal**: Verify acceptable performance for maximum size

### Steps

**1. Generate 100×100 Expert Puzzle with Timing**
```elixir
alias SudokuVersus.Puzzles

{time_us, {:ok, puzzle}} = :timer.tc(fn ->
  Puzzles.generate_puzzle(100, :expert)
end)

time_ms = time_us / 1_000
IO.puts("Generation time: #{time_ms}ms")
```

**2. Verify Results**
```elixir
puzzle.size
# => 100

puzzle.difficulty
# => :expert

length(puzzle.grid)
# => 10,000

length(puzzle.solution)
# => 10,000

puzzle.clues_count
# => 2000-2500 (20-25% of 10,000)

puzzle.sub_grid_size
# => 10
```

**Expected Time**: <5000ms (5 seconds)

**Success Criteria**:
- ✅ Puzzle generated without errors
- ✅ Grid size is 10,000 (100×100)
- ✅ Solution size is 10,000
- ✅ Clue count in 2000-2500 range
- ✅ Generation completed in <5s

---

## Test Scenario 3: Validate Moves

**Goal**: Verify O(1) move validation works correctly

### Steps

**1. Generate a Puzzle**
```elixir
alias SudokuVersus.Puzzles

{:ok, puzzle} = Puzzles.generate_puzzle(16, :medium)
```

**2. Find First Empty Cell**
```elixir
empty_index = Enum.find_index(puzzle.grid, & &1 == 0)
row = div(empty_index, 16)
col = rem(empty_index, 16)
```

**3. Validate Correct Move**
```elixir
correct_value = Enum.at(puzzle.solution, empty_index)

{:ok, is_correct} = Puzzles.validate_move(puzzle, row, col, correct_value)
# => true
```

**4. Validate Incorrect Move**
```elixir
wrong_value = rem(correct_value, 16) + 1  # Different value

{:ok, is_correct} = Puzzles.validate_move(puzzle, row, col, wrong_value)
# => false
```

**5. Measure Validation Time**
```elixir
{time_us, _} = :timer.tc(fn ->
  for _ <- 1..1000 do
    Puzzles.validate_move(puzzle, row, col, correct_value)
  end
end)

avg_time_ms = time_us / 1_000 / 1000
IO.puts("Average validation time: #{avg_time_ms}ms")
```

**Expected Time**: <5ms per validation

**Success Criteria**:
- ✅ Correct move returns `true`
- ✅ Incorrect move returns `false`
- ✅ Validation completes in <5ms

---

## Test Scenario 4: Create Game Room with New Size

**Goal**: Verify UI integration for puzzle size selection

### Steps

**1. Open Browser**
```
http://localhost:4000
```

**2. Click "Create Game Room"**

**3. Select Puzzle Size**
- Dropdown shows options: 9×9, 16×16, 25×25, 36×36, 49×49, 100×100
- Select "25×25"

**4. Select Difficulty**
- Choose "Medium"

**5. Enter Room Name**
- Enter "Test 25x25 Room"

**6. Click "Create Room"**
- Loading spinner appears
- Room created within 500ms

**7. Verify Game Board**
- Grid displays 25×25 cells
- Cells show appropriate symbols (1-9, A-P)
- Some cells pre-filled (clues)
- Other cells empty and clickable

**Success Criteria**:
- ✅ Puzzle size selector visible
- ✅ Room creation shows loading spinner
- ✅ Room created within 500ms (for 25×25)
- ✅ Grid displays correctly with 625 cells
- ✅ Symbols display correctly (1-9, A-P)

---

## Test Scenario 5: Concurrent Generation

**Goal**: Verify system handles 10 concurrent puzzle generations

### Steps

**1. Create Concurrent Task**
```elixir
alias SudokuVersus.Puzzles

tasks = for i <- 1..10 do
  Task.async(fn ->
    size = Enum.random([9, 16, 25])
    difficulty = Enum.random([:easy, :medium, :hard, :expert])
    
    {time_us, result} = :timer.tc(fn ->
      Puzzles.generate_puzzle(size, difficulty)
    end)
    
    {size, difficulty, time_us / 1_000, result}
  end)
end

results = Task.await_many(tasks, 10_000)
```

**2. Verify All Succeeded**
```elixir
all_success = Enum.all?(results, fn {_, _, _, result} ->
  match?({:ok, _}, result)
end)

IO.puts("All succeeded: #{all_success}")
```

**3. Check Performance**
```elixir
Enum.each(results, fn {size, difficulty, time_ms, _} ->
  IO.puts("#{size}×#{size} #{difficulty}: #{time_ms}ms")
end)
```

**Success Criteria**:
- ✅ All 10 tasks complete successfully
- ✅ No task timeouts
- ✅ Each task meets its size-specific time target
- ✅ No BEAM scheduler blockage

---

## Test Scenario 6: Performance Benchmark

**Goal**: Verify all puzzle sizes meet performance targets

### Steps

**1. Run Benchmark Script**
```bash
mix run priv/scripts/benchmark_puzzles.exs
```

**Expected Output**:
```
Benchmarking puzzle generation...
9×9 easy: avg=23ms, p99=45ms ✓
9×9 medium: avg=25ms, p99=48ms ✓
9×9 hard: avg=28ms, p99=52ms ✗ (target: <50ms)
9×9 expert: avg=32ms, p99=58ms ✗
16×16 easy: avg=48ms, p99=92ms ✓
16×16 medium: avg=52ms, p99=98ms ✓
...
100×100 expert: avg=4.2s, p99=8.5s ✗ (target: <10s p99) ✓

Summary:
✓ 22/24 size/difficulty combinations meet targets
✗ 2 combinations need optimization
```

**2. Verify Database Storage**
```elixir
alias SudokuVersus.Repo
alias SudokuVersus.Puzzles.Puzzle

# Check storage size
puzzle = Repo.get_by(Puzzle, size: 100)
grid_size = byte_size(:erlang.term_to_binary(puzzle.grid))
solution_size = byte_size(:erlang.term_to_binary(puzzle.solution))
total_kb = (grid_size + solution_size) / 1024

IO.puts("100×100 puzzle storage: #{total_kb}KB")
# => ~60KB (within 5MB limit)
```

**Success Criteria**:
- ✅ All puzzle sizes meet avg time targets
- ✅ p99 times within acceptable range
- ✅ 100×100 puzzle uses <5MB storage

---

## Test Scenario 7: End-to-End User Flow

**Goal**: Verify complete user journey with new puzzle sizes

### Steps

**1. User Creates Room with 36×36 Puzzle**
- Navigate to lobby
- Click "Create Game"
- Select 36×36, Hard difficulty
- Loading spinner shows ~1 second
- Room created successfully

**2. User Joins Room**
- Click "Join Room"
- Game board displays 36×36 grid
- Symbols 1-9, A-Z visible

**3. User Makes Move**
- Click empty cell
- Enter value (e.g., "M" = 13)
- Move validated in <5ms
- Feedback shown (correct/incorrect)

**4. User Completes Puzzle**
- Fill all remaining cells
- System detects completion
- Show completion message

**Success Criteria**:
- ✅ Room creation smooth with loading feedback
- ✅ Grid renders correctly for all sizes
- ✅ Move validation instant (<5ms perceived)
- ✅ Completion detection works

---

## Troubleshooting

### Issue: Rust NIF Compilation Fails

**Error**: `Could not find rustc compiler`

**Solution**:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
mix compile
```

### Issue: Generation Timeout

**Error**: `{:error, "Timeout"}`

**Possible Causes**:
- Rust debug build (slow) - use `MIX_ENV=prod mix compile`
- System under load - retry
- Algorithm bug - check Rust logs

**Solution**:
```bash
# Recompile in release mode
MIX_ENV=prod mix compile --force

# Retry generation
Puzzles.generate_puzzle(size, difficulty)
```

### Issue: Invalid Puzzle (No Solution)

**Error**: Tests fail with "puzzle has no valid solution"

**Cause**: Bug in Rust generation algorithm

**Solution**:
- Check Rust unit tests: `cd native/sudoku_generator && cargo test`
- Review constraint propagation logic
- Add more validation checks

### Issue: Slow Move Validation

**Error**: Validation takes >5ms

**Cause**: Loading puzzle without preloading solution

**Solution**:
```elixir
# Ensure solution is loaded
puzzle = Puzzles.get_puzzle!(id)
# puzzle.solution already loaded from DB

# Don't reload from DB on each validation
Puzzles.validate_move(puzzle, row, col, value)
```

---

## Validation Checklist

After running all test scenarios:

- [ ] 9×9 puzzles generate in <50ms
- [ ] 16×16 puzzles generate in <100ms
- [ ] 25×25 puzzles generate in <500ms
- [ ] 36×36 puzzles generate in <1s
- [ ] 49×49 puzzles generate in <2s
- [ ] 100×100 puzzles generate in <5s
- [ ] Move validation completes in <5ms
- [ ] 10 concurrent generations succeed
- [ ] UI shows puzzle size selector
- [ ] Loading spinner displays during generation
- [ ] All puzzle sizes display correctly in UI
- [ ] Symbol mapping works for all sizes (1-9, A-Z, etc.)
- [ ] Game flow works end-to-end
- [ ] Performance targets met (benchmark script)
- [ ] Database storage within limits (<5MB per 100×100)
- [ ] All tests pass (`mix test`)
- [ ] Precommit checks pass (`mix precommit`)

---

## Next Steps

After validating quickstart scenarios:

1. **Performance Tuning**: If any size misses targets, optimize Rust algorithm
2. **UI Polish**: Add better loading states, progress indicators
3. **Monitoring**: Add telemetry for generation times, success rates
4. **Documentation**: Update user-facing docs with new puzzle sizes
5. **Rollout**: Enable sizes gradually (start with 9×9, 25×25)

---

**Status**: ✅ Quickstart Complete | **Ready for Implementation**
