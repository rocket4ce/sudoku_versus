
# Implementation Plan: High-Performance Puzzle Generation with Multi-Size Support

**Branch**: `005-necesito-crear-mas` | **Date**: 2025-10-06 | **Spec**: [spec.md](./spec.md)
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
High-performance puzzle generation system using Rust NIFs to achieve ultra-fast generation times (<50ms for 9×9, <5s for 100×100) with support for multiple grid sizes (9×9 through 100×100). Features numeric-only symbol sets, pre-computed solutions for O(1) move validation, and desktop-first UI optimizations for large grids. Maintains strict input validation blocking invalid characters and supports concurrent generation of up to 10 puzzles.

## Technical Context
**Language/Version**: Elixir 1.15+ with Rust NIFs via Rustler
**Framework/Version**: Phoenix 1.8+, Phoenix LiveView 1.1+
**Primary Dependencies**: Ecto 3.13, Postgrex, Req 0.5, Bandit 1.5, Rustler (for NIF integration)
**Storage**: PostgreSQL with Ecto for puzzle persistence
**Testing**: ExUnit, Phoenix.LiveViewTest, LazyHTML
**Target Platform**: Web browser (Phoenix LiveView), server deployment
**Project Type**: web (Phoenix/Elixir Web Application)
**Performance Goals**: Puzzle generation <50ms (9×9) to <5s (100×100), move validation <5ms, 10 concurrent generations
**Constraints**: Desktop-first UI for large grids, numeric-only symbols, block invalid input completely
**Scale/Scope**: Support puzzle sizes 9×9 through 100×100, real-time multiplayer validation

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Reference**: `.specify/memory/constitution.md`

### Principle I: Phoenix v1.8 Best Practices
- [x] Uses LiveView for interactive features (puzzle UI, room creation forms)
- [x] Templates use `~H` or `.html.heex` (existing game templates already compliant)
- [x] Forms use `to_form/2` pattern (game creation forms will follow this pattern)
- [x] Navigation uses `<.link navigate={}>` / `<.link patch={}>` (existing navigation compliant)
- [x] Collections use LiveView streams (puzzle grids will use streams for large sizes)
- [x] Ecto associations preloaded before template access (puzzle-solution relationships)

### Principle II: Elixir 1.18 Idiomatic Code
- [x] List access uses `Enum.at/2` or pattern matching (grid cell access patterns)
- [x] Block expression results properly bound (socket updates in LiveView)
- [x] Struct field access uses dot notation or proper APIs (puzzle.grid_size, etc.)
- [x] No `String.to_atom/1` on user input (input validation blocks all non-numeric)
- [x] Predicate functions named with `?` suffix (valid_move?, puzzle_complete?)

### Principle III: Test-First Development
- [x] Tests planned before implementation (TDD approach in Phase 2 tasks)
- [x] LiveView tests use `element/2`, `has_element/2` (puzzle grid interaction tests)
- [x] Key template elements have unique DOM IDs for testing (puzzle cells, forms)
- [x] `mix precommit` will pass (all new code follows standards)

### Principle IV: LiveView-Centric Architecture
- [x] Interactive UI driven by LiveView (puzzle grid interactions via LiveView)
- [x] JS hooks (if any) in `assets/js/`, not inline (minimal JS for large grid navigation)
- [x] Stream usage follows proper patterns (puzzle cells as stream items for large grids)
- [x] Empty states and counts tracked separately (puzzle completion tracking)

### Principle V: Clean & Modular Design
- [x] Clear separation: Games context (logic), Puzzle schema (data), GameLive (presentation)
- [x] HTTP requests use `Req` library (not applicable for this feature)
- [x] Complex logic extracted to context functions (puzzle generation in Games context)
- [x] Router scopes properly aliased (existing game routes properly scoped)
- [x] YAGNI followed (start with essential sizes, add complexity only as needed)

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
├── sudoku_versus/           # Business logic contexts
│   ├── games/               # Enhanced games context
│   │   ├── puzzle.ex        # Enhanced puzzle schema with multi-size support
│   │   ├── solution.ex      # New solution schema for pre-computed solutions
│   │   ├── puzzle_config.ex # New configuration schema for grid sizes
│   │   └── generator.ex     # NIF interface to Rust puzzle generator
│   └── ...
├── sudoku_versus_web/       # Web interface layer
│   ├── live/
│   │   └── game_live/
│   │       ├── show.ex      # Enhanced with multi-size puzzle display
│   │       └── form_component.ex # Enhanced room creation form
│   ├── components/
│   │   ├── core_components.ex
│   │   └── puzzle_components.ex # New puzzle grid components
│   └── ...
└── sudoku_versus.ex

native/
├── sudoku_generator/        # Rust NIF for high-performance generation
│   ├── src/
│   │   ├── lib.rs           # NIF interface
│   │   ├── generator.rs     # Core puzzle generation logic
│   │   └── solver.rs        # Solution computation
│   └── Cargo.toml

test/
├── sudoku_versus/
│   ├── games/
│   │   ├── puzzle_test.exs
│   │   ├── solution_test.exs
│   │   ├── puzzle_config_test.exs
│   │   └── generator_test.exs
│   └── ...
├── sudoku_versus_web/
│   ├── live/
│   │   └── game_live/
│   │       └── show_test.exs # Enhanced with multi-size grid tests
│   └── ...
└── support/

priv/
├── repo/
│   ├── migrations/
│   │   ├── xxx_add_solution_table.exs
│   │   ├── xxx_add_puzzle_config_table.exs
│   │   └── xxx_enhance_puzzle_schema.exs
│   └── seeds.exs
└── static/

assets/
├── js/
│   ├── app.js
│   └── hooks/
│       └── puzzle_grid_hook.js # Optional hook for large grid navigation
├── css/
│   ├── app.css
│   └── puzzle_grid.css     # Styles for multi-size grids
└── vendor/
```

**Structure Decision**: Phoenix/Elixir Web Application with enhanced Games context for multi-size puzzle support, new Rust NIF module for high-performance generation, and extended web layer components for improved UI handling of large grids.

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
1. **Database Foundation** (from data-model.md):
   - Migration tasks for Solutions, PuzzleConfigs, enhanced Puzzles/Moves tables [P]
   - Seed data tasks for PuzzleConfig records [P]
   - Schema validation tests for all enhanced entities [P]

2. **Rust NIF Implementation** (from contracts/rust_nif.md):
   - Rust puzzle generation algorithm implementation
   - NIF wrapper with proper error handling and type conversion
   - Performance benchmarking task to validate generation time targets
   - Memory usage monitoring integration

3. **Context Layer Enhancement** (from contracts/puzzles_context.md):
   - Enhanced Games.Puzzle schema with multi-size support [P]
   - New Games.Solution schema with O(1) validation [P]
   - New Games.PuzzleConfig schema with size parameters [P]
   - Enhanced Games context functions for generation and validation
   - Contract tests for each context function [P]

4. **LiveView UI Updates**:
   - Enhanced game creation form with size selection
   - Improved puzzle grid component supporting large sizes with desktop-first responsive design
   - Input validation component blocking invalid characters (numeric-only, 1-N range)
   - Loading states during puzzle generation with size-specific timeouts
   - Error handling for generation failures and timeouts

5. **Integration & Validation** (from quickstart.md):
   - End-to-end test scenarios for each supported puzzle size
   - Performance validation tests ensuring generation time targets met
   - Concurrent generation tests (10 simultaneous requests)
   - Move validation accuracy tests across all sizes
   - UI regression tests for existing functionality

**Ordering Strategy**:
- **Phase A**: Database migrations and schemas (foundational, can run in parallel)
- **Phase B**: Rust NIF implementation (blocks generation, but not schemas)
- **Phase C**: Context layer enhancements (depends on schemas and NIF)
- **Phase D**: LiveView UI updates (depends on context layer)
- **Phase E**: Integration tests and validation (depends on full stack)

**Parallel Execution Opportunities**:
- All migration files can be created simultaneously [P]
- All schema files can be developed in parallel [P]
- Contract tests can be written alongside implementation [P]
- UI components can be developed while NIF is being implemented [P]

**Estimated Output**: 30-35 numbered, ordered tasks in tasks.md

**Performance Gates**:
- NIF benchmarks must pass before UI tasks begin
- All generation time targets must be met before integration phase
- Memory usage limits validated before deployment preparation

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved (all clarifications completed in spec)
- [x] Complexity deviations documented (no violations found)

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
