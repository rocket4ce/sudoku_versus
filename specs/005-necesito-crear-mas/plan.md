
# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

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
[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context
**Language/Version**: [e.g., Elixir 1.18.1, Python 3.11, or NEEDS CLARIFICATION]
**Framework/Version**: [e.g., Phoenix 1.8.0, Phoenix LiveView 1.1.0, or NEEDS CLARIFICATION]
**Primary Dependencies**: [e.g., Ecto 3.13, Req, Bandit 1.5, or NEEDS CLARIFICATION]
**Storage**: [e.g., PostgreSQL with Ecto, ETS, files, or N/A]
**Testing**: [e.g., ExUnit, Phoenix.LiveViewTest, LazyHTML, or NEEDS CLARIFICATION]
**Target Platform**: [e.g., Web browser (LiveView), server deployment, or NEEDS CLARIFICATION]
**Project Type**: [single/web/mobile - determines source structure; SudokuVersus is web]
**Performance Goals**: [domain-specific, e.g., <100ms LiveView updates, 1000 concurrent users, or NEEDS CLARIFICATION]
**Constraints**: [domain-specific, e.g., real-time multiplayer, <200ms latency, offline-capable, or NEEDS CLARIFICATION]
**Scale/Scope**: [domain-specific, e.g., 10k concurrent games, 50k users, or NEEDS CLARIFICATION]

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Reference**: `.specify/memory/constitution.md`

### Principle I: Phoenix v1.8 Best Practices
- [ ] Uses LiveView for interactive features (no unnecessary JavaScript)
- [ ] Templates use `~H` or `.html.heex` (no `~E`)
- [ ] Forms use `to_form/2` pattern (no raw changesets in templates)
- [ ] Navigation uses `<.link navigate={}>` / `<.link patch={}>` (no deprecated functions)
- [ ] Collections use LiveView streams (no memory-intensive list assigns)
- [ ] Ecto associations preloaded before template access (no N+1 queries)

### Principle II: Elixir 1.18 Idiomatic Code
- [ ] List access uses `Enum.at/2` or pattern matching (no `list[i]` syntax)
- [ ] Block expression results properly bound (no lost rebindings in if/case)
- [ ] Struct field access uses dot notation or proper APIs (no map access syntax)
- [ ] No `String.to_atom/1` on user input (memory leak prevention)
- [ ] Predicate functions named with `?` suffix (not `is_` prefix)

### Principle III: Test-First Development
- [ ] Tests planned before implementation (TDD approach documented)
- [ ] LiveView tests use `element/2`, `has_element/2` (no raw HTML assertions)
- [ ] Key template elements have unique DOM IDs for testing
- [ ] `mix precommit` will pass (compilation, format, tests)

### Principle IV: LiveView-Centric Architecture
- [ ] Interactive UI driven by LiveView (JavaScript only when necessary)
- [ ] JS hooks (if any) in `assets/js/`, not inline (no `<script>` tags in HEEx)
- [ ] Stream usage follows proper patterns (phx-update="stream", proper IDs)
- [ ] Empty states and counts tracked separately (streams don't support these)

### Principle V: Clean & Modular Design
- [ ] Clear separation: contexts (logic), schemas (data), LiveViews (presentation)
- [ ] HTTP requests use `Req` library (not :httpoison, :tesla, :httpc)
- [ ] Complex logic extracted to context functions (focused LiveView callbacks)
- [ ] Router scopes properly aliased (no redundant module prefixes)
- [ ] YAGNI followed (start simple, add complexity only when needed)

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
- [ ] Phase 0: Research complete (/plan command)
- [ ] Phase 1: Design complete (/plan command)
- [ ] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [ ] Initial Constitution Check: PASS
- [ ] Post-Design Constitution Check: PASS
- [ ] All NEEDS CLARIFICATION resolved
- [ ] Complexity deviations documented

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
