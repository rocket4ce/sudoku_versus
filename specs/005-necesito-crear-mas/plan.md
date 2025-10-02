
# Implementation Plan: High-Performance Puzzle Generation with Multi-Size Support

**Branch**: `005-necesito-crear-mas` | **Date**: 2025-10-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-necesito-crear-mas/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Implement ultra-fast puzzle generation system using Rust NIF to enable instant game creation with puzzles ranging from 9×9 to 100×100. Pre-compute complete solutions during generation for O(1) move validation. Support multiple puzzle sizes with appropriate symbol sets (digits, letters, extended ranges) while maintaining all difficulty levels. Target: 9×9 <50ms, 16×16 <100ms, 25×25 <500ms, 36×36 <1s, 49×49 <2s, 100×100 <5s generation times; <5ms move validation across all sizes.

## Technical Context
**Language/Version**: Elixir 1.15+ (project uses ~> 1.15)
**Framework/Version**: Phoenix 1.8.0, Phoenix LiveView 1.1.0
**Primary Dependencies**: Ecto 3.13, Postgrex, Req 0.5, Bandit 1.5, Rustler (for NIF integration)
**Storage**: PostgreSQL with Ecto (storing puzzles and solutions as JSON arrays)
**Testing**: ExUnit, Phoenix.LiveViewTest, LazyHTML
**Target Platform**: Web browser (LiveView real-time UI), server deployment with Rust NIF modules
**Project Type**: web (Phoenix/Elixir web application with contexts and LiveView)
**Performance Goals**: Puzzle generation: 9×9 <50ms, 16×16 <100ms, 25×25 <500ms, 36×36 <1s, 49×49 <2s, 100×100 <5s; Move validation <5ms for all sizes; 10 concurrent puzzle generations without degradation
**Constraints**: Real-time multiplayer, blocking UI during puzzle generation with spinner, on-demand generation only (no caching), solutions must be stored for O(1) validation
**Scale/Scope**: Support 6 puzzle sizes (9×9, 16×16, 25×25, 36×36, 49×49, 100×100), 4 difficulty levels each, 10 concurrent generation requests, memory <5MB per 100×100 puzzle

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Reference**: `.specify/memory/constitution.md`

### Principle I: Phoenix v1.8 Best Practices
- [x] Uses LiveView for interactive features (no unnecessary JavaScript) - **Game room creation UI remains LiveView, loading spinner during generation**
- [x] Templates use `~H` or `.html.heex` (no `~E`) - **All templates use HEEx format**
- [x] Forms use `to_form/2` pattern (no raw changesets in templates) - **Game room creation form follows to_form pattern**
- [x] Navigation uses `<.link navigate={}>` / `<.link patch={}>` (no deprecated functions) - **No navigation changes needed**
- [x] Collections use LiveView streams (no memory-intensive list assigns) - **Existing game room list already uses streams**
- [x] Ecto associations preloaded before template access (no N+1 queries) - **Puzzle and solution relationships will be preloaded**

### Principle II: Elixir 1.18 Idiomatic Code
- [x] List access uses `Enum.at/2` or pattern matching (no `list[i]` syntax) - **Rust NIF handles array indexing, Elixir code uses proper patterns**
- [x] Block expression results properly bound (no lost rebindings in if/case) - **All conditional blocks return assigned values**
- [x] Struct field access uses dot notation or proper APIs (no map access syntax) - **Using puzzle.grid, puzzle.solution fields**
- [x] No `String.to_atom/1` on user input (memory leak prevention) - **User inputs validated, Ecto enums used for difficulty/size**
- [x] Predicate functions named with `?` suffix (not `is_` prefix) - **E.g., valid_move?, puzzle_complete?**

### Principle III: Test-First Development
- [x] Tests planned before implementation (TDD approach documented) - **Contract tests, unit tests for NIF wrapper, LiveView tests for UI**
- [x] LiveView tests use `element/2`, `has_element/2` (no raw HTML assertions) - **Testing loading spinner, puzzle size selector with element IDs**
- [x] Key template elements have unique DOM IDs for testing - **#puzzle-size-select, #difficulty-select, #puzzle-loading-spinner**
- [x] `mix precommit` will pass (compilation, format, tests) - **All tests written to pass precommit gate**

### Principle IV: LiveView-Centric Architecture
- [x] Interactive UI driven by LiveView (JavaScript only when necessary) - **No JS needed, Rust NIF called server-side**
- [x] JS hooks (if any) in `assets/js/`, not inline (no `<script>` tags in HEEx) - **No JS hooks required for this feature**
- [x] Stream usage follows proper patterns (phx-update="stream", proper IDs) - **Existing room list streams maintained**
- [x] Empty states and counts tracked separately (streams don't support these) - **N/A for this feature**

### Principle V: Clean & Modular Design
- [x] Clear separation: contexts (logic), schemas (data), LiveViews (presentation) - **Puzzles context with Puzzle schema, GameLive handles presentation**
- [x] HTTP requests use `Req` library (not :httpoison, :tesla, :httpc) - **No HTTP requests in this feature**
- [x] Complex logic extracted to context functions (focused LiveView callbacks) - **Puzzles.generate_puzzle/2, Puzzles.validate_move/3 in context**
- [x] Router scopes properly aliased (no redundant module prefixes) - **No router changes needed**
- [x] YAGNI followed (start simple, add complexity only when needed) - **Start with 9×9 and 16×16, incrementally add larger sizes**

**Status**: ✅ PASS - All constitutional principles satisfied. No violations requiring justification.

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
lib/
├── sudoku_versus/
│   ├── puzzles/                    # NEW: Puzzle generation context
│   │   ├── puzzle.ex              # Enhanced Puzzle schema with size support
│   │   ├── generator.ex           # Elixir wrapper for Rust NIF
│   │   └── validator.ex           # Move validation using pre-computed solutions
│   ├── game_rooms/                # EXISTING: Game room management
│   │   ├── game_room.ex          # Enhanced with new puzzle size field
│   │   └── ...
│   └── ...
├── sudoku_versus_web/
│   ├── live/
│   │   └── game_live/
│   │       ├── index.ex          # MODIFIED: Add puzzle size selector
│   │       └── show.ex           # MODIFIED: Use new validation
│   └── components/
│       └── core_components.ex    # EXISTING: Reusable components
└── sudoku_versus.ex

native/                             # NEW: Rust NIF module
├── sudoku_generator/
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs                # NIF interface
│   │   ├── generator.rs          # Core puzzle generation algorithms
│   │   └── solver.rs             # Fast solution computation
│   └── ...

test/
├── sudoku_versus/
│   ├── puzzles/
│   │   ├── generator_test.exs    # NEW: NIF wrapper tests
│   │   └── validator_test.exs    # NEW: Validation tests
│   └── game_rooms/
│       └── game_room_test.exs    # MODIFIED: Test new sizes
├── sudoku_versus_web/
│   └── live/
│       └── game_live/
│           ├── index_test.exs    # MODIFIED: Test size selector
│           └── show_test.exs     # MODIFIED: Test validation
└── support/
    └── fixtures.ex               # MODIFIED: Add puzzle fixtures

priv/
└── repo/
    └── migrations/
        └── XXX_add_puzzle_size_support.exs  # NEW: Migration

mix.exs                             # MODIFIED: Add Rustler dependency
```

**Structure Decision**: Phoenix/Elixir Web Application (standard for SudokuVersus). New Puzzles context in `lib/sudoku_versus/puzzles/` for puzzle generation and validation logic. Rust NIF modules in `native/sudoku_generator/` for high-performance generation. Enhanced existing GameRoom context and GameLive to support new puzzle sizes. All tests mirror lib structure following TDD principles.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh copilot`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
The /tasks command will generate tasks following TDD principles, organized by layer and dependency order:

**Layer 1: Foundation (Rust NIF)**
1. Setup Rustler dependency and configure mix.exs
2. Create Rust NIF project structure (native/sudoku_generator/)
3. Write Rust unit tests for generation algorithm (9×9, 16×16)
4. Implement Rust NIF generate function (backtracking algorithm)
5. Write Rust unit tests for large sizes (25×25, 36×36, 49×49, 100×100)
6. Optimize Rust algorithm for performance targets

**Layer 2: Elixir Context (Domain Logic)**
7. Create migration for puzzle size support (add size, sub_grid_size, clues_count columns)
8. Write Puzzle schema tests (validations, relationships)
9. Implement enhanced Puzzle schema with size support
10. Write Generator wrapper tests (Elixir → Rust NIF)
11. Implement Generator wrapper module (handles Task.async, timeouts)
12. Write Validator tests (move validation, O(1) lookup)
13. Implement Validator module (validate_move/4 function)
14. Write Puzzles context tests (generate_puzzle, get_puzzle, list operations)
15. Implement Puzzles context (public API functions)

**Layer 3: Web Integration (LiveView)**
16. Write GameLive.Index tests for puzzle size selector
17. Modify GameLive.Index mount to load available sizes
18. Implement puzzle size selector UI in index.html.heex
19. Write GameLive.Index tests for room creation with loading spinner
20. Implement room creation with async puzzle generation + spinner
21. Write GameLive.Show tests for enhanced move validation
22. Modify GameLive.Show to use new Puzzles.validate_move/4
23. Write tests for multi-size grid display
24. Implement responsive grid rendering for all sizes (CSS + templates)
25. Implement symbol mapping for display (1-9, A-Z, extended sets)

**Layer 4: Performance & Polish**
26. Create benchmark script (priv/scripts/benchmark_puzzles.exs)
27. Run benchmarks and verify all targets met
28. Add telemetry events for puzzle generation timing
29. Write quickstart validation tests
30. Execute quickstart scenarios and document results

**Ordering Strategy**:
- **TDD First**: All test tasks precede implementation tasks
- **Bottom-Up Dependencies**: Rust → Elixir context → LiveView
- **Parallel Opportunities**: Tasks marked [P] can run concurrently
  - Rust tests + Elixir schema tests (different languages)
  - Multiple context function implementations (pure functions)
  - UI tests for different LiveViews (isolated)
- **Sequential Critical Path**: NIF → Generator → Context → UI

**Task Metadata**:
- Total estimated tasks: 30
- Parallel groups: 3-4 tasks per group (Rust, Schema, Context, UI)
- Serial dependencies: ~6 critical path stages
- Estimated completion: 2-3 days with proper parallelization

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

**Status**: ✅ No violations - Table remains empty

All constitutional principles are satisfied without deviations. No complexity justification required.


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command) - ✅ research.md created
- [x] Phase 1: Design complete (/plan command) - ✅ data-model.md, contracts/, quickstart.md, AGENTS.md updated
- [x] Phase 2: Task planning complete (/plan command - describe approach only) - ✅ 30-task approach documented
- [ ] Phase 3: Tasks generated (/tasks command) - Waiting for /tasks command
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS - All 5 principles satisfied
- [x] Post-Design Constitution Check: PASS - No violations introduced
- [x] All NEEDS CLARIFICATION resolved - Technical Context fully populated
- [x] Complexity deviations documented - No deviations; complexity tracking table empty (no violations)

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
