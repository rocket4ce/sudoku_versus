# Research: High-Performance Puzzle Generation

**Feature**: 005-necesito-crear-mas
**Date**: 2025-10-02
**Status**: Complete

## Research Questions

### 1. Rust NIF Integration with Elixir/Phoenix

**Decision**: Use Rustler library for safe Elixir-Rust NIF bindings

**Rationale**:
- **Rustler** is the de-facto standard for Rust NIFs in Elixir (used by major projects like ex_aws, jason alternatives)
- Provides safe, automatic type conversion between Elixir and Rust
- Handles resource management and prevents common NIF memory leaks
- Supports dirty schedulers for CPU-intensive operations (critical for large puzzle generation)
- Active maintenance and strong community support
- Works seamlessly with Mix build system

**Alternatives Considered**:
- **Pure Elixir**: Rejected - too slow for 100×100 puzzle generation (would take 10-30 seconds vs target 5s)
- **Port/GenServer approach**: Rejected - higher overhead, no shared memory, serialization costs
- **Zig NIFs**: Rejected - less mature tooling, smaller ecosystem, Rust has better Sudoku algorithm libraries
- **C NIFs**: Rejected - Rust provides memory safety without GC pauses, better error handling

**Implementation Notes**:
- Use `dirty_cpu` schedulers for puzzle generation (blocks BEAM scheduler appropriately)
- Keep NIF functions focused: `generate_puzzle(size, difficulty) -> {grid, solution}`
- Return results as Elixir terms (lists of lists) for easy Ecto serialization
- Add Rustler to mix.exs dependencies with proper compiler flags

---

### 2. Puzzle Generation Algorithm for Multi-Size Support

**Decision**: Backtracking algorithm with constraint propagation, optimized per grid size

**Rationale**:
- **Backtracking with constraint propagation** is the proven standard for Sudoku generation
- Scales to arbitrary NxN grids with proper optimization
- Can pre-compute solution during generation (single pass)
- Difficulty control via cell removal strategy (random vs strategic)
- Rust implementation enables brute-force performance for large grids

**Algorithm Stages**:
1. **Solution Generation**: Fill grid using backtracking with constraint checks
2. **Puzzle Extraction**: Remove cells strategically based on difficulty
3. **Uniqueness Validation**: Verify exactly one solution exists (via solver check)
4. **Encoding**: Return both partial grid (puzzle) and complete grid (solution)

**Optimization Strategies by Size**:
- **9×9, 16×16**: Standard backtracking (fast enough)
- **25×25**: Add constraint propagation heuristics
- **36×36+**: Pre-generate sub-grid templates, use parallel backtracking
- **100×100**: Divide-and-conquer with sub-grid independence checks

**Alternatives Considered**:
- **SAT solver approach**: Rejected - slower for large grids, harder to control difficulty
- **Genetic algorithms**: Rejected - non-deterministic timing, can't guarantee generation time
- **Dancing Links (DLX)**: Considered for validation, but backtracking is simpler and fast enough with Rust

---

### 3. Solution Storage Format for O(1) Validation

**Decision**: Store solutions as PostgreSQL JSONB array (one-dimensional with index mapping)

**Rationale**:
- **JSONB** provides efficient storage and native PostgreSQL indexing
- **Flat array** `[1,2,3,...,N²]` with index calculation `row*N + col` gives O(1) lookup
- Ecto can serialize/deserialize JSONB automatically to Elixir lists
- No need for separate solution table (solution always paired with puzzle)
- PostgreSQL JSONB faster than TEXT for array operations
- Typical size: 100×100 = 10,000 integers ≈ 40KB JSONB, well within limits

**Storage Schema**:
```elixir
# puzzles table
{
  id: uuid,
  size: integer,              # 9, 16, 25, 36, 49, 100
  difficulty: enum,           # easy, medium, hard, expert
  grid: jsonb,                # partial grid [0=empty, 1-N=values]
  solution: jsonb,            # complete grid [1-N values]
  clues_count: integer,       # number of pre-filled cells
  ...
}
```

**Alternatives Considered**:
- **Binary encoding**: Rejected - harder to debug, minimal storage savings
- **Separate solutions table**: Rejected - adds JOIN overhead, no benefit
- **ETS cache**: Rejected - spec requires on-demand generation, no pre-caching
- **Compressed TEXT**: Rejected - slower deserialization than JSONB

---

### 4. Symbol Sets for Large Puzzles

**Decision**: Use numeric representation for all sizes, UI maps to display symbols

**Rationale**:
- **Internally**: Always store 1..N integers (1-9, 1-16, 1-25, ..., 1-100)
- **UI Layer**: Maps integers to display characters (1-9, A-G, custom glyphs for 100×100)
- Simplifies Rust generation code (always integer arithmetic)
- Avoids encoding issues, easier validation
- Frontend can customize symbol display per culture/preference

**Display Mapping**:
| Grid Size | Internal Range | Display Symbols |
|-----------|---------------|-----------------|
| 9×9       | 1-9          | 1-9             |
| 16×16     | 1-16         | 1-9, A-G        |
| 25×25     | 1-25         | 1-9, A-P        |
| 36×36     | 1-36         | 1-9, A-Z        |
| 49×49     | 1-49         | 1-9, A-Z, α-ν   |
| 100×100   | 1-100        | 1-100 (numeric) |

**Alternatives Considered**:
- **Store symbols as strings**: Rejected - wastes space, complicates Rust code
- **Unicode symbol sets**: Rejected - input complexity, accessibility issues
- **Custom glyph fonts**: Considered for future UI enhancement, not MVP

---

### 5. Difficulty Scaling Across Sizes

**Decision**: Fixed percentage of clues per difficulty, adjusted by grid size

**Rationale**:
- **Easy**: 50-60% of cells filled
- **Medium**: 35-45% of cells filled
- **Hard**: 25-35% of cells filled
- **Expert**: 20-25% of cells filled

Percentages scale automatically with grid size to maintain similar perceived difficulty.

**Validation**:
- Must have exactly one unique solution (verified during generation)
- Clues must be strategically placed (not random clustering)
- Grid must be solvable using logical deduction (no guessing required for easy/medium)

**Alternatives Considered**:
- **Absolute clue counts**: Rejected - doesn't scale (25 clues easy for 9×9, impossible for 100×100)
- **Difficulty by technique**: Rejected - too complex to implement, hard to define for large grids
- **User rating**: Considered for future tuning, not MVP

---

### 6. Concurrency and Performance Patterns

**Decision**: Async Task with timeout per request, pool-based NIF scheduling

**Rationale**:
- **Each puzzle generation = async Task** with size-based timeout
- Task runs on dirty_cpu scheduler (doesn't block BEAM)
- LiveView shows loading spinner during Task execution
- If timeout: return error, let user retry
- No queue needed for 10 concurrent (dirty schedulers handle this)

**Pattern**:
```elixir
# In Puzzles context
def generate_puzzle_async(size, difficulty) do
  timeout = timeout_for_size(size)  # 50ms to 5s
  Task.async(fn ->
    Puzzles.Generator.generate(size, difficulty)
  end)
  |> Task.await(timeout)
end
```

**Error Handling**:
- Timeout: Show "Generation timed out, please try again"
- Generation failure: Retry with different seed automatically (max 3 attempts)
- Validation failure: Log error, retry generation

**Alternatives Considered**:
- **GenServer pool**: Rejected - overkill, dirty schedulers sufficient
- **Queue system**: Rejected - spec says 10 concurrent is acceptable limit
- **Pre-generation**: Rejected - spec requires on-demand only

---

### 7. Testing Strategy for NIF Code

**Decision**: Multi-layer testing: Rust unit tests, Elixir integration tests, property-based tests

**Test Layers**:
1. **Rust Unit Tests** (`cargo test`): Test algorithm correctness, edge cases
2. **Elixir Integration Tests**: Test NIF wrapper, type conversions, error handling
3. **Property-Based Tests** (StreamData): Verify solution validity, uniqueness
4. **Performance Tests**: Benchmark generation times per size (must meet targets)
5. **LiveView Tests**: Test UI interaction, loading states, error messages

**Critical Test Cases**:
- Valid puzzle/solution for all sizes (9×9 through 100×100)
- Difficulty requirements met (clue counts)
- Solution uniqueness verified
- Move validation correctness (100% accuracy)
- Performance targets met (each size within timeout)
- Concurrent generation (10 parallel requests)

**Alternatives Considered**:
- **Only integration tests**: Rejected - Rust bugs harder to debug without unit tests
- **Manual testing only**: Rejected - performance regression risk, TDD violation

---

## Technology Stack Summary

| Component | Technology | Version | Justification |
|-----------|-----------|---------|---------------|
| Backend Runtime | Elixir | 1.15+ | Project standard |
| Web Framework | Phoenix | 1.8.0 | Project standard |
| Real-time UI | LiveView | 1.1.0 | Project standard |
| Database | PostgreSQL | Latest | Project standard, JSONB support |
| NIF Bindings | Rustler | ~0.30 | Industry standard for Rust NIFs |
| Puzzle Generation | Rust | 1.70+ | Performance, memory safety |
| Testing | ExUnit + cargo test | Built-in | Multi-layer testing |
| Property Testing | StreamData | Latest | Solution verification |

---

## Performance Validation Plan

**Benchmarking Approach**:
1. Create benchmark script: `mix run priv/scripts/benchmark_puzzles.exs`
2. Generate 10 puzzles per size/difficulty combination
3. Measure: min, max, avg, p95, p99 generation times
4. Verify all targets met before Phase 2 completion

**Acceptance Criteria**:
- 9×9: avg <50ms, p99 <100ms
- 16×16: avg <100ms, p99 <200ms
- 25×25: avg <500ms, p99 <1s
- 36×36: avg <1s, p99 <2s
- 49×49: avg <2s, p99 <4s
- 100×100: avg <5s, p99 <10s
- Move validation: avg <5ms for all sizes

---

## Migration Strategy

**Backward Compatibility**:
- Existing 16×16 puzzles remain valid (no migration needed)
- New `size` column added with default=16 for existing records
- Existing game rooms continue working without changes
- New UI options appear only for new room creation

**Rollout Plan**:
1. **Phase 1**: Deploy with 9×9 and 16×16 support (validate performance)
2. **Phase 2**: Enable 25×25 and 36×36 (monitor usage)
3. **Phase 3**: Enable 49×49 and 100×100 (based on demand)

**Risk Mitigation**:
- Feature flag per puzzle size (can disable problematic sizes)
- Monitor generation times via telemetry
- Auto-disable sizes if p99 exceeds 2× target

---

## Open Questions (Resolved)

All research questions have been resolved. No blockers for Phase 1 design.

---

**Status**: ✅ Research Complete | **Next Phase**: Design (Phase 1)
