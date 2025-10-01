# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Phoenix/Elixir**: `lib/app_name/`, `lib/app_name_web/`, `test/` at repository root
- **Umbrella app**: `apps/app_name/lib/`, `apps/app_name/test/`
- **Traditional web**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below use generic examples - adjust based on plan.md structure and language

## Phase 3.1: Setup
- [ ] T001 Create project structure per implementation plan
- [ ] T002 Initialize [language] project with [framework] dependencies
- [ ] T003 [P] Configure linting and formatting tools

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T004 [P] LiveView test for feature interaction in test/app_web/live/feature_live_test.exs
- [ ] T005 [P] Context function tests in test/app/context_test.exs
- [ ] T006 [P] Schema validation tests in test/app/schemas_test.exs
- [ ] T007 [P] Integration test for feature flow in test/app/integration_test.exs

**Note**: For non-Phoenix projects, adjust paths (e.g., `tests/contract/test_users_post.py` for Python)

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T008 [P] Schema definition in lib/app/context/schema.ex
- [ ] T009 [P] Context functions in lib/app/context.ex
- [ ] T010 [P] LiveView module in lib/app_web/live/feature_live.ex
- [ ] T011 LiveView template in lib/app_web/live/feature_live.html.heex
- [ ] T012 Form handling and validation
- [ ] T013 Event handlers (phx-click, phx-submit, etc.)
- [ ] T014 Error handling and flash messages

**Note**: For API endpoints, use controllers; for CLI, use Mix tasks or escript

## Phase 3.4: Integration
- [ ] T015 Add database migrations in priv/repo/migrations/
- [ ] T016 Connect context to Repo queries
- [ ] T017 Add PubSub/channels if real-time needed
- [ ] T018 Add authentication/authorization plugs if needed

## Phase 3.5: Polish
- [ ] T019 [P] Additional unit tests for edge cases
- [ ] T020 Performance review (LiveView update times, query optimization)
- [ ] T021 [P] Update documentation (README, module docs)
- [ ] T022 Run `mix precommit` and fix any issues
- [ ] T023 Manual testing and UX review

## Dependencies
- Tests (T004-T007) before implementation (T008-T014)
- T008 blocks T009, T015
- T016 blocks T018
- Implementation before polish (T019-T023)

## Parallel Example
```
# Launch T004-T007 together (different files, no dependencies):
Task: "LiveView test for feature interaction in test/app_web/live/feature_live_test.exs"
Task: "Context function tests in test/app/context_test.exs"
Task: "Schema validation tests in test/app/schemas_test.exs"
Task: "Integration test for feature flow in test/app/integration_test.exs"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts**:
   - Each contract file → contract test task [P]
   - Each endpoint → implementation task

2. **From Data Model**:
   - Each entity → model creation task [P]
   - Relationships → service layer tasks

3. **From User Stories**:
   - Each story → integration test [P]
   - Quickstart scenarios → validation tasks

4. **Ordering**:
   - Setup → Tests → Models → Services → Endpoints → Polish
   - Dependencies block parallel execution

## Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All contracts have corresponding tests
- [ ] All entities have model tasks
- [ ] All tests come before implementation
- [ ] Parallel tasks truly independent
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task