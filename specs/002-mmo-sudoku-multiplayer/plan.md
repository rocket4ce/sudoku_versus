
# Implementation Plan: MMO Sudoku Multiplayer Game

**Branch**: `002-mmo-sudoku-multiplayer` | **Date**: 2025-10-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/Users/rocket4ce/sites/elixir/sudoku_versus/specs/002-mmo-sudoku-multiplayer/spec.md`

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

Build a massive multiplayer online Sudoku game where unlimited players can collaborate in real-time to solve puzzles from 9x9 to 100x100 grids across six difficulty levels. Features include: custom room names with emoji support, multiple authentication methods (traditional/OAuth/guest), sophisticated scoring algorithm, 10-second penalty cooldown for errors, complete move history with timeline replay, public leaderboards and statistics, and auto-scaling architecture to handle unlimited growth. All player data is publicly visible.

**Technical Approach**: Phoenix LiveView-centric architecture with PubSub for real-time multiplayer synchronization, PostgreSQL for persistence, streams for efficient collection rendering, and horizontal scaling capability for unlimited concurrency.

## Technical Context
**Language/Version**: Elixir 1.18.1
**Framework/Version**: Phoenix 1.8.0, Phoenix LiveView 1.1.0
**Primary Dependencies**: Ecto 3.13 (database), Phoenix.PubSub (real-time), Req (HTTP if OAuth), Bandit 1.5 (web server)
**Storage**: PostgreSQL with Ecto for all game state, moves, players, scores, and sessions
**Testing**: ExUnit, Phoenix.LiveViewTest, LazyHTML for test assertions
**Target Platform**: Web browsers (via LiveView), deployed on scalable infrastructure (e.g., Fly.io, AWS)
**Project Type**: Phoenix web application (LiveView-first)
**Performance Goals**: <100ms move validation, <200ms real-time broadcast to all players in room, support unlimited players per room
**Constraints**: Real-time multiplayer (no page refreshes), must handle connection drops gracefully (30s reconnect window), auto-scaling architecture, all data publicly visible
**Scale/Scope**: Baseline 100+ concurrent rooms and 1000+ concurrent players with auto-scaling beyond these limits, unlimited players per room, complete move history stored indefinitely

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Reference**: `.specify/memory/constitution.md`

### Principle I: Phoenix v1.8 Best Practices
- [x] Uses LiveView for interactive features (no unnecessary JavaScript)
  - Game rooms, move submissions, real-time updates all via LiveView
  - No custom JavaScript except potentially for timeline scrubbing UI
- [x] Templates use `~H` or `.html.heex` (no `~E`)
  - All templates will be `.html.heex` files
- [x] Forms use `to_form/2` pattern (no raw changesets in templates)
  - Room creation form, auth forms use `to_form/2`
- [x] Navigation uses `<.link navigate={}>` / `<.link patch={}>` (no deprecated functions)
  - Room list to game room navigation, rankings navigation
- [x] Collections use LiveView streams (no memory-intensive list assigns)
  - **CRITICAL**: Room lists, move history, player lists, rankings ALL use streams
  - Prevents memory issues with unlimited players and large game history
- [x] Ecto associations preloaded before template access (no N+1 queries)
  - Preload game_room.creator, move.player, session.player

### Principle II: Elixir 1.18 Idiomatic Code
- [x] List access uses `Enum.at/2` or pattern matching (no `list[i]` syntax)
  - All puzzle grid access via proper Enum functions
- [x] Block expression results properly bound (no lost rebindings in if/case)
  - Socket updates always rebind: `socket = if condition, do: update(socket)`
- [x] Struct field access uses dot notation or proper APIs (no map access syntax)
  - Use `player.username`, `Ecto.Changeset.get_field(changeset, :field)`
- [x] No `String.to_atom/1` on user input (memory leak prevention)
  - Room names, usernames stored as strings only
- [x] Predicate functions named with `?` suffix (not `is_` prefix)
  - `valid_move?/2`, `penalty_active?/1`, `game_complete?/1`

### Principle III: Test-First Development
- [x] Tests planned before implementation (TDD approach documented)
  - Test scenarios defined in tasks.md (Phase 3.2 before 3.3)
- [x] LiveView tests use `element/2`, `has_element/2` (no raw HTML assertions)
  - Test room creation, move submission, real-time updates via LiveViewTest
- [x] Key template elements have unique DOM IDs for testing
  - `id="create-room-form"`, `id="sudoku-grid"`, `id="move-list"`, etc.
- [x] `mix precommit` will pass (compilation, format, tests)
  - All code formatted, tested, no warnings before commits

### Principle IV: LiveView-Centric Architecture
- [x] Interactive UI driven by LiveView (JavaScript only when necessary)
  - Real-time via PubSub broadcasts to LiveView
  - Minimal JS: potentially timeline scrubber only
- [x] JS hooks (if any) in `assets/js/`, not inline (no `<script>` tags in HEEx)
  - Timeline hook (if needed) in `assets/js/hooks/timeline.js`
- [x] Stream usage follows proper patterns (phx-update="stream", proper IDs)
  - Rooms list: `<div id="rooms" phx-update="stream">` with `@streams.rooms`
  - Moves history: `<div id="moves" phx-update="stream">` with `@streams.moves`
  - Players online: `<div id="players" phx-update="stream">` with `@streams.players`
- [x] Empty states and counts tracked separately (streams don't support these)
  - `@rooms_count`, `@players_online_count`, `@moves_count` as separate assigns

### Principle V: Clean & Modular Design
- [x] Clear separation: contexts (logic), schemas (data), LiveViews (presentation)
  - `SudokuVersus.Games` context: game logic, puzzle generation, scoring
  - `SudokuVersus.Accounts` context: user management, auth
  - `SudokuVersusWeb.GameLive` LiveViews: UI and user interactions
- [x] HTTP requests use `Req` library (not :httpoison, :tesla, :httpc)
  - OAuth provider requests (if needed) via `Req`
- [x] Complex logic extracted to context functions (focused LiveView callbacks)
  - Scoring calculation in `Games.calculate_score/2`
  - Puzzle generation in `Games.generate_puzzle/2`
  - Move validation in `Games.validate_move/3`
- [x] Router scopes properly aliased (no redundant module prefixes)
  - `scope "/", SudokuVersusWeb` then `live "/game", GameLive`
- [x] YAGNI followed (start simple, add complexity only when needed)
  - Start with basic 9x9, add larger grids after
  - Guest auth first, OAuth can be added later

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
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths. The delivered plan must not include Option labels.
-->
```
# [REMOVE IF UNUSED] Option 1: Phoenix/Elixir Web Application (DEFAULT for SudokuVersus)
lib/
├── sudoku_versus/           # Business logic contexts
│   ├── context_name/
│   │   ├── schema_name.ex   # Ecto schemas
│   │   └── ...
│   └── ...
├── sudoku_versus_web/       # Web interface layer
│   ├── live/                # LiveView modules
│   │   └── feature_live.ex
│   ├── components/          # Reusable components
│   │   └── core_components.ex
│   ├── controllers/         # Traditional controllers (if needed)
│   └── ...
└── sudoku_versus.ex         # Main application file

test/
├── sudoku_versus/           # Context tests
│   └── context_name_test.exs
├── sudoku_versus_web/       # LiveView & controller tests
│   ├── live/
│   │   └── feature_live_test.exs
│   └── ...
└── support/                 # Test helpers

assets/                      # Frontend assets
├── js/
│   ├── app.js
│   └── hooks/               # LiveView JS hooks
├── css/
│   └── app.css
└── vendor/

priv/
├── repo/
│   ├── migrations/          # Database migrations
│   └── seeds.exs
└── static/                  # Compiled assets

# [REMOVE IF UNUSED] Option 2: Umbrella Application (for complex multi-app projects)
apps/
├── app_name/
│   ├── lib/
│   └── test/
├── app_name_web/
│   ├── lib/
│   └── test/
└── ...

# [REMOVE IF UNUSED] Option 3: CLI/Script Project (non-web Elixir)
lib/
├── module_name/
│   ├── core.ex
│   └── cli.ex
└── module_name.ex

test/
└── module_name_test.exs
```

**Structure Decision**: [Document the selected structure. For SudokuVersus, use Option 1: Phoenix/Elixir Web Application with contexts in `lib/sudoku_versus/`, web layer in `lib/sudoku_versus_web/`, and tests mirroring the lib structure.]

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
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each contract → contract test task [P]
- Each entity → model creation task [P]
- Each user story → integration test task
- Implementation tasks to make tests pass

**Ordering Strategy**:
- TDD order: Tests before implementation
- Dependency order: Models before services before UI
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 25-30 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 2: Task Generation Approach

**Purpose**: Describe how tasks.md will be structured when the `/tasks` command is executed.

### Task Breakdown Strategy

Tasks will follow **Test-Driven Development (TDD)** principles per Constitution Principle III:

1. **Phase 3.1: Setup & Infrastructure** (1-2 days)
   - Database migrations (users, puzzles, game_rooms, player_sessions, moves, score_records, leaderboard view)
   - Context modules scaffolding (Accounts, Games)
   - Phoenix.Presence setup
   - Router configuration

2. **Phase 3.2: Core Game Logic - TDD First** (2-3 days)
   - Puzzle generation algorithm (backtracking) - **Test first**
   - Move validation logic - **Test first**
   - Scoring calculation - **Test first**
   - Each logic module gets comprehensive test suite before implementation

3. **Phase 3.3: Core Game Logic - Implementation** (2-3 days)
   - Implement puzzle generator using tests from 3.2
   - Implement move validator using tests from 3.2
   - Implement scorer using tests from 3.2
   - Verify all tests pass

4. **Phase 3.4: Authentication System - TDD & Implementation** (2-3 days)
   - Guest registration tests → implementation
   - Email/password registration tests → implementation
   - OAuth integration (Google/GitHub) tests → implementation
   - Session management tests → implementation

5. **Phase 3.5: Game Room Management - TDD & Implementation** (3-4 days)
   - Room creation/listing LiveView tests → implementation
   - Room join/leave tests → implementation
   - Phoenix.PubSub room topics tests → implementation
   - Phoenix.Presence player tracking tests → implementation

6. **Phase 3.6: Real-Time Gameplay - TDD & Implementation** (4-5 days)
   - Game board rendering LiveView tests → implementation
   - Move submission LiveView tests → implementation
   - PubSub broadcast tests → implementation
   - LiveView streams (moves, players) tests → implementation
   - Score updates tests → implementation

7. **Phase 3.7: Leaderboards & Stats - TDD & Implementation** (2-3 days)
   - Leaderboard materialized view tests
   - Background refresh GenServer tests → implementation
   - Leaderboard LiveView tests → implementation
   - Player stats display tests → implementation

8. **Phase 3.8: Polish & Performance** (2-3 days)
   - Performance profiling (meet <100ms validation, <200ms broadcast)
   - UI/UX improvements
   - Error handling edge cases
   - Mobile responsive design

9. **Phase 3.9: Integration Testing** (1-2 days)
   - End-to-end scenarios (guest flow, multiplayer flow, OAuth flow)
   - Cross-browser testing
   - Load testing (simulate 100+ rooms, 1000+ players)

### Task Structure Template

Each task will follow this format:
```markdown
### Task N: [Title]
- **Priority**: High/Medium/Low
- **Estimated Time**: X hours
- **Dependencies**: Task M (if any)
- **Files**: List of files to create/modify
- **Tests First** (if TDD phase):
  - [ ] Write test: [test description]
  - [ ] Verify test fails (red)
- **Implementation**:
  - [ ] Implement: [implementation step]
  - [ ] Verify test passes (green)
  - [ ] Refactor if needed
- **Verification**:
  - [ ] `mix test` passes
  - [ ] `mix format` applied
  - [ ] No compiler warnings
```

### Parallel Work Opportunities

Tasks that can be executed in parallel (by different developers):
- Phase 3.2 + 3.4: Core logic testing and Auth testing
- Phase 3.5 + 3.7: Room management and Leaderboards (minimal overlap)
- Phase 3.6 + 3.8: Gameplay implementation and Polish (late-stage)

### Acceptance Criteria

All tasks complete when:
- ✅ All 9 acceptance scenarios from spec.md pass
- ✅ All 8 edge cases from spec.md handled
- ✅ Performance requirements met (<100ms validation, <200ms broadcast)
- ✅ Scale baseline achieved (100+ rooms, 1000+ players without degradation)
- ✅ `mix precommit` passes (all tests green, code formatted, no warnings)
- ✅ All 5 constitution principles validated in implementation
- ✅ quickstart.md successfully onboards new developer

### Estimated Timeline

- **Total Tasks**: ~45-55 individual tasks across 9 phases
- **Total Effort**: 19-28 days (assuming 1 full-time developer)
- **Critical Path**: Phase 3.1 → 3.2-3.3 → 3.6 → 3.9
- **Parallel Reduction**: With 2 developers, estimate 12-16 days

---

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md with structure described above)
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
- [x] Phase 0: Research complete (/plan command) ✅
- [x] Phase 1: Design complete (/plan command) ✅
- [x] Phase 2: Task planning complete (/plan command - describe approach only) ✅
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS ✅ (All 5 principles aligned with MMO Sudoku design)
- [x] Post-Design Constitution Check: PASS ✅ (Design artifacts maintain constitutional compliance)
- [x] All NEEDS CLARIFICATION resolved ✅ (5 clarifications addressed in spec Session 2025-10-01)
- [x] Complexity deviations documented ✅ (None - all design follows YAGNI, starts simple)

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
