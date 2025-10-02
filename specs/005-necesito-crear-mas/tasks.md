# Tasks: High-Performance Puzzle Generation with Multi-Size Support

**Input**: Design documents from `/specs/005-necesito-crear-mas/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

## Execution Flow (main)
```
1. Load plan.md from feature directory ✅
   → Tech stack: Elixir 1.15+, Phoenix 1.8.0, Rustler (NIF), PostgreSQL
   → Structure: Phoenix web app with contexts and LiveView
2. Load optional design documents ✅
   → data-model.md: Puzzle (enhanced), GameRoom (enhanced)
   → contracts/: puzzles_context.md, rust_nif.md
   → research.md: Rust NIF, backtracking algorithm, JSONB storage
3. Generate tasks by category ✅
   → Setup: Rust toolchain, Rustler dependency, database migration
   → Tests: NIF wrapper tests, context tests, LiveView tests
   → Core: Rust NIF module, Puzzles context, LiveView enhancements
   → Integration: Database migration, GameRoom integration
   → Polish: Performance benchmarks, documentation
4. Apply task rules ✅
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...) ✅
6. Generate dependency graph ✅
7. Create parallel execution examples ✅
8. Validate task completeness ✅
   → All contracts have tests ✅
   → All entities have models ✅
   → All endpoints implemented ✅
9. Return: SUCCESS (tasks ready for execution) ✅
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Phoenix/Elixir**: `lib/sudoku_versus/`, `lib/sudoku_versus_web/`, `test/` at repository root
- **Rust NIF**: `native/sudoku_generator/` for Rust code
- **Database**: `priv/repo/migrations/` for Ecto migrations

---

## Phase 3.1: Setup

- [x] **T001** Initialize Rust NIF project structure using `mix rustler.new`
  - **Files**: `native/sudoku_generator/Cargo.toml`, `native/sudoku_generator/src/lib.rs`
  - **Action**: Run `mix rustler.new sudoku_generator` to generate NIF project
  - **Validation**: `cargo --version` succeeds, Cargo.toml exists
  - **Status**: ✅ COMPLETED - Created Rust NIF structure with Cargo.toml and lib.rs

- [x] **T002** Add Rustler dependency to mix.exs
  - **Files**: `mix.exs`
  - **Action**: Add `{:rustler, "~> 0.30"}` to deps, configure rustler settings
  - **Validation**: `mix deps.get` succeeds, Rustler compiles
  - **Status**: ✅ COMPLETED - Added Rustler 0.37.1, configured rust_crates in project config

- [x] **T003** Configure Rust compiler for dirty schedulers and optimization
  - **Files**: `native/sudoku_generator/Cargo.toml`
  - **Action**: Set `opt-level = 3`, enable LTO, configure profile.release
  - **Validation**: `cargo build --release` succeeds
  - **Status**: ✅ COMPLETED - Configured release profile with opt-level=3, LTO enabled

- [x] **T004** Create database migration for puzzle size support
  - **Files**: `priv/repo/migrations/20251002051708_add_puzzle_size_support.exs`
  - **Action**: Add `size`, `sub_grid_size` columns to puzzles table, update indexes
  - **Validation**: `mix ecto.migrate` succeeds, schema updated
  - **Status**: ✅ COMPLETED - Migration created with size fields, constraints, and indexes

---

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [ ] **T005** [P] Rust NIF wrapper integration tests in `test/sudoku_versus/puzzles/generator_test.exs`
  - **Files**: `test/sudoku_versus/puzzles/generator_test.exs`
  - **Tests**:
    - Generate 9×9 easy puzzle in <50ms
    - Generate 16×16 medium puzzle in <100ms
    - Generate 25×25 hard puzzle in <500ms
    - Generate 36×36 expert puzzle in <1s
    - Generate 49×49 easy puzzle in <2s
    - Generate 100×100 expert puzzle in <5s
    - Return error for invalid size (10)
    - Return error for invalid difficulty (:impossible)
    - Grid and solution have correct lengths
    - Solution is valid Sudoku (all constraints met)
  - **Status**: MUST FAIL (no implementation yet)

- [ ] **T006** [P] Move validation tests in `test/sudoku_versus/puzzles/validator_test.exs`
  - **Files**: `test/sudoku_versus/puzzles/validator_test.exs`
  - **Tests**:
    - Validate correct move returns true
    - Validate incorrect move returns false
    - Validate move completes in <5ms
    - Return error for row < 0
    - Return error for row >= size
    - Return error for col < 0
    - Return error for col >= size
    - Return error for value < 1
    - Return error for value > size
  - **Status**: MUST FAIL (no implementation yet)

- [ ] **T007** [P] Puzzles context function tests in `test/sudoku_versus/puzzles_test.exs`
  - **Files**: `test/sudoku_versus/puzzles_test.exs`
  - **Tests**:
    - `generate_puzzle/2` creates valid puzzle
    - `generate_puzzle/2` saves to database
    - `get_puzzle!/1` retrieves with grid and solution
    - `get_puzzle!/1` raises for non-existent ID
    - `validate_move/4` delegates to Validator
    - `list_puzzles_by_size_and_difficulty/2` filters correctly
    - `list_puzzles_by_size_and_difficulty/2` limits to 50
    - `list_puzzles_by_size_and_difficulty/2` orders by inserted_at DESC
  - **Status**: MUST FAIL (no implementation yet)

- [ ] **T008** [P] Enhanced GameRoom context tests in `test/sudoku_versus/game_rooms_test.exs`
  - **Files**: `test/sudoku_versus/game_rooms_test.exs`
  - **Tests**:
    - Create room with 9×9 puzzle
    - Create room with 16×16 puzzle
    - Create room with 25×25 puzzle
    - Create room with 36×36 puzzle
    - Create room with 49×49 puzzle
    - Create room with 100×100 puzzle
    - Preload puzzle associations correctly
  - **Status**: Enhancement to existing tests

- [ ] **T009** [P] LiveView game room creation tests in `test/sudoku_versus_web/live/game_live/index_test.exs`
  - **Files**: `test/sudoku_versus_web/live/game_live/index_test.exs`
  - **Tests**:
    - Render puzzle size selector (#puzzle-size-select)
    - Render difficulty selector (#difficulty-select)
    - Show loading spinner during generation (#puzzle-loading-spinner)
    - Create room with 9×9 puzzle
    - Create room with 16×16 puzzle
    - Create room with 100×100 puzzle
    - Show error on generation timeout
    - Redirect to game room on success
  - **Status**: Enhancement to existing tests

- [ ] **T010** [P] LiveView move validation tests in `test/sudoku_versus_web/live/game_live/show_test.exs`
  - **Files**: `test/sudoku_versus_web/live/game_live/show_test.exs`
  - **Tests**:
    - Submit correct move updates UI
    - Submit incorrect move shows error
    - Move validation uses new O(1) lookup
    - Score updates correctly
    - Streak updates correctly
  - **Status**: Enhancement to existing tests

- [ ] **T011** [P] Property-based tests for puzzle validity in `test/sudoku_versus/puzzles/property_test.exs`
  - **Files**: `test/sudoku_versus/puzzles/property_test.exs`
  - **Tests**:
    - All generated puzzles have exactly one solution
    - Solution satisfies all Sudoku constraints
    - Clue count matches difficulty percentage
    - Grid values are subset of solution values
    - Sub-grid size is √N for all sizes
  - **Status**: MUST FAIL (no implementation yet)

---

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Rust NIF Module

- [ ] **T012** [P] Implement core Sudoku generation algorithm in Rust
  - **Files**: `native/sudoku_generator/src/generator.rs`
  - **Action**: Implement backtracking with constraint propagation
  - **Functions**:
    - `generate_solution(size: usize) -> Vec<i32>`
    - `create_puzzle(solution: Vec<i32>, difficulty: i32) -> Vec<i32>`
    - `count_solutions(grid: &[i32]) -> usize`
  - **Validation**: Cargo tests pass

- [ ] **T013** [P] Implement fast Sudoku solver in Rust
  - **Files**: `native/sudoku_generator/src/solver.rs`
  - **Action**: Implement fast constraint checking and solution validation
  - **Functions**:
    - `is_valid_solution(grid: &[i32], size: usize) -> bool`
    - `check_constraints(grid: &[i32], row: usize, col: usize, value: i32) -> bool`
  - **Validation**: Cargo tests pass

- [ ] **T014** [P] Implement difficulty calculation in Rust
  - **Files**: `native/sudoku_generator/src/difficulty.rs`
  - **Action**: Calculate clue counts and cell removal strategy
  - **Functions**:
    - `calculate_clue_count(size: usize, difficulty: i32) -> usize`
    - `remove_cells_strategically(grid: &mut Vec<i32>, target_clues: usize)`
  - **Validation**: Cargo tests pass

- [ ] **T015** Implement NIF interface with dirty schedulers
  - **Files**: `native/sudoku_generator/src/lib.rs`
  - **Action**: Expose `generate/3` NIF function with DirtyCpu scheduling
  - **Functions**:
    - `#[rustler::nif(schedule = "DirtyCpu")] fn generate(size: i32, difficulty: i32, seed: u64) -> Result<PuzzleResult, String>`
  - **Dependencies**: T012, T013, T014 (uses their functions)
  - **Validation**: `mix compile` succeeds, NIF loads

- [ ] **T016** Add Rust unit tests for all NIF functions
  - **Files**: `native/sudoku_generator/src/tests.rs`
  - **Action**: Test each function with edge cases
  - **Dependencies**: T012-T015
  - **Validation**: `cargo test` passes

### Elixir Schemas

- [ ] **T017** [P] Enhance Puzzle schema with size support
  - **Files**: `lib/sudoku_versus/puzzles/puzzle.ex`
  - **Action**: Add `size`, `sub_grid_size` fields, update validations
  - **Fields**: `size`, `sub_grid_size`, `grid`, `solution`, `clues_count`
  - **Validations**: size in [9,16,25,36,49,100], grid/solution length checks
  - **Validation**: Schema compiles, tests pass

- [ ] **T018** [P] Update GameRoom schema preloads
  - **Files**: `lib/sudoku_versus/game_rooms/game_room.ex`
  - **Action**: Ensure puzzle association preloads correctly
  - **Validation**: Preload queries work in tests

### Elixir Contexts

- [ ] **T019** [P] Create Puzzles.Generator wrapper module
  - **Files**: `lib/sudoku_versus/puzzles/generator.ex`
  - **Action**: Wrap Rust NIF with Elixir API
  - **Functions**:
    - `generate(size, difficulty) -> {:ok, %{grid: list(), solution: list()}} | {:error, String.t()}`
    - Auto-generate seed using `:erlang.system_time()`
  - **Dependencies**: T015 (calls NIF)
  - **Validation**: Integration tests T005 pass

- [ ] **T020** [P] Create Puzzles.Validator module
  - **Files**: `lib/sudoku_versus/puzzles/validator.ex`
  - **Action**: Implement O(1) move validation
  - **Functions**:
    - `validate_move(puzzle, row, col, value) -> {:ok, boolean()} | {:error, String.t()}`
  - **Algorithm**: `index = row * size + col; Enum.at(solution, index) == value`
  - **Validation**: Tests T006 pass

- [ ] **T021** Implement Puzzles context with all public functions
  - **Files**: `lib/sudoku_versus/puzzles.ex`
  - **Action**: Create context module with business logic
  - **Functions**:
    - `generate_puzzle(size, difficulty)` - calls Generator, saves to DB
    - `get_puzzle!(id)` - fetch with preloads
    - `validate_move(puzzle, row, col, value)` - delegates to Validator
    - `list_puzzles_by_size_and_difficulty(size, difficulty)` - query DB
  - **Dependencies**: T017, T019, T020
  - **Validation**: Context tests T007 pass

- [ ] **T022** Update GameRooms context to support multi-size puzzles
  - **Files**: `lib/sudoku_versus/game_rooms.ex`
  - **Action**: Update `create_room/1` to accept size parameter, call `Puzzles.generate_puzzle/2`
  - **Dependencies**: T021
  - **Validation**: GameRoom tests T008 pass

### LiveView Enhancements

- [ ] **T023** [P] Add puzzle size selector to GameLive.Index template
  - **Files**: `lib/sudoku_versus_web/live/game_live/index.html.heex`
  - **Action**: Add `<select>` for size with options [9,16,25,36,49,100]
  - **Element ID**: `#puzzle-size-select`
  - **Validation**: Template renders, element exists

- [ ] **T024** Update GameLive.Index handle_event for room creation
  - **Files**: `lib/sudoku_versus_web/live/game_live/index.ex`
  - **Action**: Extract size from params, show loading spinner, call GameRooms.create_room
  - **Events**: `handle_event("create_room", %{"size" => size, "difficulty" => difficulty, ...}, socket)`
  - **Dependencies**: T022, T023
  - **Validation**: LiveView tests T009 pass

- [ ] **T025** Add loading spinner component for puzzle generation
  - **Files**: `lib/sudoku_versus_web/live/game_live/index.html.heex`
  - **Action**: Show spinner during puzzle generation with `phx-update="ignore"`
  - **Element ID**: `#puzzle-loading-spinner`
  - **Dependencies**: T024
  - **Validation**: Spinner shows/hides correctly

- [ ] **T026** Update GameLive.Show to use new validation
  - **Files**: `lib/sudoku_versus_web/live/game_live/show.ex`
  - **Action**: Replace move validation with `Puzzles.validate_move/4`
  - **Event**: `handle_event("submit_move", ...)`
  - **Dependencies**: T021
  - **Validation**: LiveView tests T010 pass

---

## Phase 3.4: Integration

- [ ] **T027** Run database migration and verify schema
  - **Files**: Database
  - **Action**: `mix ecto.migrate`, verify puzzles table has new columns
  - **Dependencies**: T004
  - **Validation**: Migration succeeds, rollback succeeds

- [ ] **T028** Seed database with sample puzzles for all sizes
  - **Files**: `priv/repo/seeds.exs`
  - **Action**: Generate 1 puzzle per size/difficulty combination (24 total)
  - **Dependencies**: T021, T027
  - **Validation**: `mix run priv/repo/seeds.exs` succeeds

- [ ] **T029** Update GameRoom PubSub broadcasts to include puzzle size
  - **Files**: `lib/sudoku_versus/game_rooms.ex`
  - **Action**: Include `puzzle.size` in broadcast messages
  - **Dependencies**: T022
  - **Validation**: PubSub broadcasts correctly

- [ ] **T030** Update Move creation to use new validation
  - **Files**: `lib/sudoku_versus/game_rooms/moves.ex`
  - **Action**: Replace validation logic with `Puzzles.validate_move/4`
  - **Dependencies**: T021
  - **Validation**: Move creation tests pass

---

## Phase 3.5: Polish

- [ ] **T031** [P] Add performance benchmarks for puzzle generation
  - **Files**: `test/sudoku_versus/puzzles/benchmark_test.exs`
  - **Action**: Benchmark generation times for all sizes, assert < target times
  - **Benchmarks**:
    - 9×9: <50ms
    - 16×16: <100ms
    - 25×25: <500ms
    - 36×36: <1s
    - 49×49: <2s
    - 100×100: <5s
  - **Dependencies**: T021
  - **Validation**: All benchmarks pass

- [ ] **T032** [P] Add performance benchmarks for move validation
  - **Files**: `test/sudoku_versus/puzzles/validation_benchmark_test.exs`
  - **Action**: Benchmark validation time for all sizes, assert <5ms
  - **Dependencies**: T021
  - **Validation**: Validation completes in <5ms for all sizes

- [ ] **T033** [P] Add concurrency stress tests
  - **Files**: `test/sudoku_versus/puzzles/concurrency_test.exs`
  - **Action**: Generate 10 puzzles concurrently, verify no performance degradation
  - **Dependencies**: T021
  - **Validation**: 10 concurrent generations complete successfully

- [ ] **T034** [P] Update module documentation with examples
  - **Files**: `lib/sudoku_versus/puzzles.ex`, `lib/sudoku_versus/puzzles/generator.ex`, `lib/sudoku_versus/puzzles/validator.ex`
  - **Action**: Add @moduledoc and @doc with usage examples
  - **Validation**: `mix docs` generates correct documentation

- [ ] **T035** [P] Update README with puzzle generation feature
  - **Files**: `README.md`
  - **Action**: Document new puzzle sizes, generation times, usage
  - **Validation**: README is clear and accurate

- [ ] **T036** [P] Update AGENTS.md with Rust NIF guidelines
  - **Files**: `AGENTS.md`
  - **Action**: Add guidelines for NIF usage, Rustler patterns, dirty schedulers
  - **Dependencies**: None (documentation only)
  - **Validation**: Guidelines are clear and follow project conventions

- [ ] **T037** Run `mix precommit` and fix any issues
  - **Files**: All modified files
  - **Action**: Run formatter, linter, all tests
  - **Dependencies**: All previous tasks
  - **Validation**: `mix precommit` passes with no errors

- [ ] **T038** Manual testing across all puzzle sizes
  - **Action**: Test room creation, move submission, validation for each size
  - **Dependencies**: T037
  - **Validation**: All features work correctly in browser

---

## Dependencies Graph

```
Setup Phase:
T001 → T002 → T003
T004 (independent)

Tests Phase (all parallel, no dependencies):
T005, T006, T007, T008, T009, T010, T011

Rust Implementation:
T012, T013, T014 (parallel) → T015 → T016

Elixir Schemas:
T017, T018 (parallel)

Elixir Contexts:
T015 → T019 (Generator wrapper)
T020 (Validator - parallel with T019)
T017, T019, T020 → T021 (Puzzles context)
T021 → T022 (GameRooms context)

LiveView:
T023 (parallel with T024 preparation)
T022 → T024 → T025
T021 → T026

Integration:
T004 → T027
T021, T027 → T028
T022 → T029
T021 → T030

Polish:
T021 → T031, T032, T033, T034 (all parallel)
T035, T036 (parallel, independent)
All above → T037 → T038
```

---

## Parallel Execution Examples

### Tests Phase (T005-T011)
All test files are independent and can run in parallel:

```bash
# Terminal 1: NIF wrapper tests
mix test test/sudoku_versus/puzzles/generator_test.exs

# Terminal 2: Validator tests
mix test test/sudoku_versus/puzzles/validator_test.exs

# Terminal 3: Context tests
mix test test/sudoku_versus/puzzles_test.exs

# Terminal 4: GameRoom tests
mix test test/sudoku_versus/game_rooms_test.exs

# Terminal 5: LiveView index tests
mix test test/sudoku_versus_web/live/game_live/index_test.exs

# Terminal 6: LiveView show tests
mix test test/sudoku_versus_web/live/game_live/show_test.exs

# Terminal 7: Property tests
mix test test/sudoku_versus/puzzles/property_test.exs
```

### Rust Implementation (T012-T014)
Core algorithm files are independent:

```bash
# Terminal 1: Generator
cargo test --test generator

# Terminal 2: Solver
cargo test --test solver

# Terminal 3: Difficulty
cargo test --test difficulty
```

### Polish Phase (T031-T036)
Documentation and benchmarks are independent:

```bash
# Terminal 1: Generation benchmarks
mix test test/sudoku_versus/puzzles/benchmark_test.exs

# Terminal 2: Validation benchmarks
mix test test/sudoku_versus/puzzles/validation_benchmark_test.exs

# Terminal 3: Concurrency tests
mix test test/sudoku_versus/puzzles/concurrency_test.exs

# Terminal 4: Module docs
mix docs

# Terminal 5: README
# Edit README.md

# Terminal 6: AGENTS.md
# Edit AGENTS.md
```

---

## Task Execution Checklist

### Before Starting
- [ ] All design documents reviewed (plan.md, data-model.md, contracts/, research.md)
- [ ] Rust toolchain installed (`rustup --version`)
- [ ] PostgreSQL running and accessible
- [ ] Current branch is `005-necesito-crear-mas`

### During Execution
- [ ] Commit after each task completion
- [ ] Verify tests fail before implementing (TDD)
- [ ] Run affected tests after each implementation task
- [ ] Keep task descriptions updated if scope changes

### After Completion
- [ ] All tests pass (`mix test`)
- [ ] Performance benchmarks meet targets
- [ ] `mix precommit` passes
- [ ] Manual testing confirms feature works
- [ ] Documentation is complete and accurate

---

## Notes

### YAGNI Principle
- Start with 9×9 and 16×16 sizes (existing use case)
- Add 25×25, 36×36 incrementally if time permits
- 49×49 and 100×100 are stretch goals (nice-to-have)

### Performance Monitoring
- Log generation times for each size in production
- Alert if any generation exceeds 2× target time
- Monitor dirty scheduler utilization

### Error Handling
- Retry generation automatically (max 3 attempts)
- Show user-friendly error messages in LiveView
- Log NIF errors for debugging

### Testing Strategy
- TDD: Write failing tests first, then implement
- Property-based tests verify puzzle correctness
- Benchmarks ensure performance targets met
- Integration tests validate end-to-end flow

---

## Validation Checklist
*GATE: Checked before marking tasks complete*

- [x] All contracts have corresponding tests (T005-T011)
- [x] All entities have model tasks (T017-T018)
- [x] All tests come before implementation (Phase 3.2 before 3.3)
- [x] Parallel tasks truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task
- [x] Dependencies correctly ordered in graph
- [x] Performance targets documented in tasks

**Status**: ✅ READY FOR EXECUTION
