# Tasks: MMO Sudoku Multiplayer Game

**Input**: Design documents from `/Users/rocket4ce/sites/elixir/sudoku_versus/specs/002-mmo-sudoku-multiplayer/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

---

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

---

## Phase 3.1: Setup & Infrastructure

### Database & Configuration
- [ ] **T001** Create database migration for users table
  - **File**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_users.exs`
  - **Details**: Binary ID primary key, username (unique), email (unique), password_hash, is_guest, oauth_provider, oauth_provider_id (unique composite), statistics fields (total_games_played, total_puzzles_completed, total_points_earned, highest_score), timestamps
  - **Indexes**: username, email, oauth_provider+oauth_provider_id, total_points_earned DESC

- [ ] **T002** Create database migration for puzzles table
  - **File**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_puzzles.exs`
  - **Details**: Binary ID primary key, difficulty enum (easy/medium/hard/expert), grid (array of arrays), solution (array of arrays), clues_count integer, timestamps
  - **Indexes**: difficulty
  - **Check Constraints**: clues_count >= 22 AND clues_count <= 45

- [ ] **T003** Create database migration for game_rooms table
  - **File**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_game_rooms.exs`
  - **Details**: Binary ID primary key, name string, status enum (active/completed/archived), max_players integer, visibility enum (public/private), started_at, completed_at, current_players_count, total_moves_count, creator_id FK to users, puzzle_id FK to puzzles, timestamps
  - **Indexes**: status, inserted_at DESC, creator_id
  - **Dependencies**: T001, T002

- [ ] **T004** Create database migration for player_sessions table
  - **File**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_player_sessions.exs`
  - **Details**: Binary ID primary key, started_at, last_activity_at, completed_at, is_active boolean, scoring fields (current_score, current_streak, longest_streak, correct_moves_count, incorrect_moves_count, cells_filled, completed_puzzle), player_id FK to users, game_room_id FK to game_rooms, timestamps
  - **Indexes**: player_id+game_room_id (unique), game_room_id, is_active
  - **Dependencies**: T001, T003

- [ ] **T005** Create database migration for moves table
  - **File**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_moves.exs`
  - **Details**: Binary ID primary key, row integer (0-8), col integer (0-8), value integer (1-9), is_correct boolean, submitted_at, points_earned, player_id FK to users, game_room_id FK to game_rooms, player_session_id FK to player_sessions, timestamps
  - **Indexes**: game_room_id+inserted_at DESC, player_session_id, player_id
  - **Check Constraints**: row >= 0 AND row < 9, col >= 0 AND col < 9, value >= 1 AND value <= 9
  - **Dependencies**: T001, T003, T004

- [ ] **T006** Create database migration for score_records table
  - **File**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_score_records.exs`
  - **Details**: Binary ID primary key, final_score, time_elapsed_seconds, correct_moves, incorrect_moves, longest_streak, completed_puzzle boolean, difficulty enum, recorded_at, player_id FK to users, game_room_id FK to game_rooms, timestamps
  - **Indexes**: player_id+final_score DESC, difficulty+final_score DESC, recorded_at DESC
  - **Dependencies**: T001, T003

- [ ] **T007** Create database migration for leaderboard_entries materialized view
  - **File**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_leaderboard_entries.exs`
  - **Details**: Materialized view with player_id, username, display_name, avatar_url, total_score, games_completed, average_score, highest_single_score, rank, difficulty (including 'all' aggregate)
  - **Indexes**: player_id+difficulty (unique)
  - **Dependencies**: T001, T006

### Context & Schema Setup
- [ ] **T008** [P] Create User schema
  - **File**: `lib/sudoku_versus/accounts/user.ex`
  - **Details**: Ecto schema matching T001 migration, guest_changeset/2, registration_changeset/2, oauth_changeset/2, put_password_hash/1 private function
  - **Dependencies**: T001

- [ ] **T009** [P] Create Puzzle schema
  - **File**: `lib/sudoku_versus/games/puzzle.ex`
  - **Details**: Ecto schema matching T002 migration, changeset/2, validate_grid_structure/1, validate_clues_count/1
  - **Dependencies**: T002

- [ ] **T010** [P] Create GameRoom schema
  - **File**: `lib/sudoku_versus/games/game_room.ex`
  - **Details**: Ecto schema matching T003 migration, changeset/2, status_changeset/2, validate_name_format/1 (supports emojis, max 30 chars)
  - **Dependencies**: T003

- [ ] **T011** [P] Create PlayerSession schema
  - **File**: `lib/sudoku_versus/games/player_session.ex`
  - **Details**: Ecto schema matching T004 migration, changeset/2, update_stats_changeset/2, complete_changeset/1
  - **Dependencies**: T004

- [ ] **T012** [P] Create Move schema
  - **File**: `lib/sudoku_versus/games/move.ex`
  - **Details**: Ecto schema matching T005 migration, changeset/2 with validation
  - **Dependencies**: T005

- [ ] **T013** [P] Create ScoreRecord schema
  - **File**: `lib/sudoku_versus/games/score_record.ex`
  - **Details**: Ecto schema matching T006 migration, changeset/2
  - **Dependencies**: T006

- [ ] **T014** [P] Create LeaderboardEntry schema (read-only)
  - **File**: `lib/sudoku_versus/games/leaderboard_entry.ex`
  - **Details**: Read-only Ecto schema matching T007 materialized view, no changesets needed
  - **Dependencies**: T007

### Phoenix Setup
- [ ] **T015** [P] Create Phoenix.Presence module
  - **File**: `lib/sudoku_versus_web/presence.ex`
  - **Details**: Use Phoenix.Presence with pubsub_server: SudokuVersus.PubSub for player tracking per room

- [ ] **T016** [P] Update application.ex to start Presence
  - **File**: `lib/sudoku_versus/application.ex`
  - **Details**: Add SudokuVersusWeb.Presence to supervision tree

---

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

### Context Tests
- [X] **T017** [P] Write Accounts context tests for user management
  - **File**: `test/sudoku_versus/accounts_test.exs`
  - **Details**: Test guest registration, email/password registration, OAuth user creation, user lookup functions
  - **Expected**: All tests MUST FAIL initially (implementation doesn't exist yet)
  - **Covers**: create_guest_user/1, register_user/1, find_or_create_oauth_user/2, get_user_by_username/1, authenticate_user/2

- [X] **T018** [P] Write Games context tests for puzzle generation
  - **File**: `test/sudoku_versus/games/puzzle_generator_test.exs`
  - **Details**: Test generate_puzzle/1 for each difficulty, validate_move?/4, solution caching
  - **Expected**: All tests MUST FAIL initially
  - **Covers**: generate_puzzle(:easy/:medium/:hard/:expert), validate_move?(puzzle, row, col, value), cache_solution/1

- [X] **T019** [P] Write Games context tests for scoring
  - **File**: `test/sudoku_versus/games/scorer_test.exs`
  - **Details**: Test calculate_score/3, streak multipliers, speed bonuses, penalties
  - **Expected**: All tests MUST FAIL initially
  - **Covers**: calculate_score(move, session, puzzle), base_points_for_difficulty/1, calculate_streak_multiplier/1, calculate_speed_bonus/2, calculate_penalties/1

- [X] **T020** [P] Write Games context tests for game room management
  - **File**: `test/sudoku_versus/games_test.exs`
  - **Details**: Test create_game_room/1, list_active_rooms/0, join_room/2, leave_room/2, record_move/3, get_room_moves/2
  - **Expected**: All tests MUST FAIL initially
  - **Covers**: create_game_room/1, list_active_rooms/0, join_room/2, leave_room/2, record_move/3, get_room_moves/2, update_session_stats/2, refresh_leaderboard/0

### OAuth Controller Tests
- [X] **T021** [P] Write OAuth controller tests
  - **File**: `test/sudoku_versus_web/controllers/auth_controller_test.exs`
  - **Details**: Test GET /auth/:provider redirects, callback handling (success/error), logout
  - **Expected**: Tests MUST FAIL (controller doesn't exist yet)
  - **Covers**: authorize/2 for Google/GitHub, callback/2 success/error cases, logout/2
  - **Note**: Use Req.Test for mocking OAuth responses

### LiveView Tests
- [X] **T022** [P] Write room lobby LiveView tests
  - **File**: `test/sudoku_versus_web/live/game_live/index_test.exs`
  - **Details**: Test room list rendering (streams), room creation form, filtering by difficulty, room joining
  - **Expected**: Tests MUST FAIL
  - **Covers**: mount, render room list with streams, handle_event("create_room"), handle_event("filter"), room cards with player counts
  - **DOM IDs**: #room-list, #create-room-form, #filter-difficulty

- [X] **T023** [P] Write game room LiveView tests
  - **File**: `test/sudoku_versus_web/live/game_live/show_test.exs`
  - **Details**: Test game board rendering, move submission, real-time updates via PubSub, player presence, score updates, move history streams
  - **Expected**: Tests MUST FAIL
  - **Covers**: mount with PubSub subscription, render grid, handle_event("submit_move"), handle_info({:new_move}), handle_info({:presence_diff}), streams for moves/players
  - **DOM IDs**: #sudoku-grid, #move-form, #move-list, #player-list, #score-display

- [X] **T024** [P] Write leaderboard LiveView tests
  - **File**: `test/sudoku_versus_web/live/leaderboard_live/index_test.exs`
  - **Details**: Test leaderboard rendering (streams), difficulty filtering, rank display
  - **Expected**: Tests MUST FAIL
  - **Covers**: mount, render leaderboard with streams, handle_event("filter_difficulty"), top 100 players
  - **DOM IDs**: #leaderboard-list, #difficulty-filter

- [X] **T025** [P] Write authentication LiveView tests
  - **File**: `test/sudoku_versus_web/live/auth_live_test.exs`
  - **Details**: Test guest login form, registration form, OAuth button redirects
  - **Expected**: Tests MUST FAIL
  - **Covers**: Guest login LiveView, registration LiveView, form validations, OAuth initiation buttons
  - **DOM IDs**: #guest-login-form, #register-form, #google-oauth-btn, #github-oauth-btn

### Integration Tests
- [X] **T026** [P] Write end-to-end guest user flow test
  - **File**: `test/sudoku_versus_web/integration/guest_flow_test.exs`
  - **Details**: Test complete flow: guest login → create room → submit moves → see score update
  - **Expected**: Test MUST FAIL
  - **Scenario**: Guest registers → navigates to lobby → creates room "Test 🎮" → submits correct move → verifies score increases

- [X] **T027** [P] Write end-to-end multiplayer flow test
  - **File**: `test/sudoku_versus_web/integration/multiplayer_flow_test.exs`
  - **Details**: Test real-time synchronization between two players in same room
  - **Expected**: Test MUST FAIL
  - **Scenario**: User A creates room → User B joins → User A submits move → User B sees move in real-time via PubSub

- [X] **T028** [P] Write presence tracking integration test
  - **File**: `test/sudoku_versus_web/integration/presence_test.exs`
  - **Details**: Test player join/leave detection via Phoenix.Presence
  - **Expected**: Test MUST FAIL
  - **Scenario**: User joins room → presence count = 1 → User leaves → presence count = 0

---

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Accounts Context
- [ ] **T029** [P] Implement Accounts context module
  - **File**: `lib/sudoku_versus/accounts.ex`
  - **Details**: Implement create_guest_user/1, register_user/1, get_user_by_username/1, authenticate_user/2
  - **Verify**: T017 tests now pass
  - **Dependencies**: T008, T017

- [ ] **T030** [P] Implement OAuth module with Req
  - **File**: `lib/sudoku_versus/accounts/oauth.ex`
  - **Details**: Implement authorize_url/1, fetch_token/2, fetch_user_info/2 for Google and GitHub using Req library
  - **Verify**: T021 tests now pass
  - **Dependencies**: T017, T021

- [ ] **T031** Implement find_or_create_oauth_user/2 in Accounts context
  - **File**: `lib/sudoku_versus/accounts.ex`
  - **Details**: Create or update user from OAuth provider data
  - **Verify**: T021 OAuth callback tests pass
  - **Dependencies**: T029, T030

### Games Context - Puzzle Generation
- [ ] **T032** [P] Implement PuzzleGenerator module
  - **File**: `lib/sudoku_versus/games/puzzle_generator.ex`
  - **Details**: Implement generate_puzzle/1 with backtracking algorithm, validate_move?/4, cache_solution/1
  - **Verify**: T018 tests now pass
  - **Dependencies**: T009, T018
  - **Note**: Include initialize_empty_grid/0, fill_diagonal_boxes/1, solve_recursive/1, remove_numbers/2, clues_for_difficulty/1

- [ ] **T033** [P] Implement Scorer module
  - **File**: `lib/sudoku_versus/games/scorer.ex`
  - **Details**: Implement calculate_score/3 with base points (500-5000 by difficulty), streak multipliers (1.0-2.0), speed bonuses, penalties
  - **Verify**: T019 tests now pass
  - **Dependencies**: T011, T019

### Games Context - Room Management
- [ ] **T034** Implement Games context base functions
  - **File**: `lib/sudoku_versus/games.ex`
  - **Details**: Implement create_game_room/1, list_active_rooms/0, get_game_room/1 with preloading
  - **Verify**: T020 room creation/listing tests pass
  - **Dependencies**: T010, T020

- [ ] **T035** Implement join_room/2 and leave_room/2
  - **File**: `lib/sudoku_versus/games.ex`
  - **Details**: Create player_session on join, update session on leave, increment/decrement room player counts
  - **Verify**: T020 join/leave tests pass
  - **Dependencies**: T011, T034

- [ ] **T036** Implement record_move/3 with validation
  - **File**: `lib/sudoku_versus/games.ex`
  - **Details**: Validate move against puzzle solution, record in moves table, update player_session stats, calculate and apply score
  - **Verify**: T020 move recording tests pass
  - **Dependencies**: T012, T032, T033, T035

- [ ] **T037** Implement get_room_moves/2 for history
  - **File**: `lib/sudoku_versus/games.ex`
  - **Details**: Query moves for room with preloaded player, ordered by inserted_at DESC, limit 50
  - **Verify**: T020 move history tests pass
  - **Dependencies**: T012, T036

- [ ] **T038** [P] Implement LeaderboardRefresher GenServer
  - **File**: `lib/sudoku_versus/games/leaderboard_refresher.ex`
  - **Details**: GenServer that refreshes materialized view every 60 seconds
  - **Verify**: T020 leaderboard refresh test passes
  - **Dependencies**: T014

- [ ] **T039** Implement refresh_leaderboard/0 and get_leaderboard/2
  - **File**: `lib/sudoku_versus/games.ex`
  - **Details**: Execute REFRESH MATERIALIZED VIEW CONCURRENTLY, query leaderboard by difficulty with rank ordering
  - **Verify**: T020 leaderboard query tests pass
  - **Dependencies**: T014, T038

- [ ] **T040** Update application.ex to start LeaderboardRefresher
  - **File**: `lib/sudoku_versus/application.ex`
  - **Details**: Add SudokuVersus.Games.LeaderboardRefresher to supervision tree
  - **Dependencies**: T038

### OAuth Controller
- [ ] **T041** [P] Implement AuthController
  - **File**: `lib/sudoku_versus_web/controllers/auth_controller.ex`
  - **Details**: Implement authorize/2, callback/2, logout/2 actions
  - **Verify**: T021 tests now pass
  - **Dependencies**: T030, T031, T021

- [ ] **T042** Add OAuth routes to router
  - **File**: `lib/sudoku_versus_web/router.ex`
  - **Details**: Add scope "/auth" with routes: GET /:provider, GET /:provider/callback, DELETE /logout
  - **Dependencies**: T041

### LiveView - Room Lobby
- [ ] **T043** Create GameLive.Index module (room lobby)
  - **File**: `lib/sudoku_versus_web/live/game_live/index.ex`
  - **Details**: Implement mount/3, handle_event("create_room"), handle_event("filter"), stream rooms list, create room form with to_form/2
  - **Verify**: T022 tests now pass
  - **Dependencies**: T010, T034, T022
  - **Note**: Use streams for room list, track @rooms_count separately

- [ ] **T044** Create room lobby template
  - **File**: `lib/sudoku_versus_web/live/game_live/index.html.heex`
  - **Details**: Room list with streams (#room-list, phx-update="stream"), create room form (#create-room-form), difficulty filter (#filter-difficulty)
  - **Dependencies**: T043

### LiveView - Game Room
- [ ] **T045** Create GameLive.Show module (game room)
  - **File**: `lib/sudoku_versus_web/live/game_live/show.ex`
  - **Details**: Implement mount/3 with PubSub subscription + Presence tracking, render grid as regular assign (not stream), handle_event("submit_move"), handle_info({:new_move}), handle_info({:presence_diff}), streams for moves and players
  - **Verify**: T023 tests now pass
  - **Dependencies**: T012, T015, T036, T037, T023
  - **Note**: Grid is fixed 81 cells (regular assign), moves/players use streams

- [ ] **T046** Create game room template
  - **File**: `lib/sudoku_versus_web/live/game_live/show.html.heex`
  - **Details**: Sudoku grid (#sudoku-grid), move form (#move-form), move history stream (#move-list), player list stream (#player-list), score display (#score-display)
  - **Dependencies**: T045

### LiveView - Leaderboard
- [ ] **T047** [P] Create LeaderboardLive.Index module
  - **File**: `lib/sudoku_versus_web/live/leaderboard_live/index.ex`
  - **Details**: Implement mount/3, handle_event("filter_difficulty"), stream leaderboard entries, track @leaderboard_count
  - **Verify**: T024 tests now pass
  - **Dependencies**: T014, T039, T024

- [ ] **T048** Create leaderboard template
  - **File**: `lib/sudoku_versus_web/live/leaderboard_live/index.html.heex`
  - **Details**: Leaderboard list with streams (#leaderboard-list), difficulty filter (#difficulty-filter), rank/score display
  - **Dependencies**: T047

### LiveView - Authentication
- [ ] **T049** [P] Create AuthLive modules (guest login, registration)
  - **File**: `lib/sudoku_versus_web/live/auth_live/guest.ex`, `lib/sudoku_versus_web/live/auth_live/register.ex`
  - **Details**: Guest login form, registration form with validations, OAuth buttons
  - **Verify**: T025 tests now pass
  - **Dependencies**: T029, T025

- [ ] **T050** Create auth templates
  - **File**: `lib/sudoku_versus_web/live/auth_live/guest.html.heex`, `lib/sudoku_versus_web/live/auth_live/register.html.heex`
  - **Details**: Guest login form (#guest-login-form), registration form (#register-form), OAuth buttons (#google-oauth-btn, #github-oauth-btn)
  - **Dependencies**: T049

### Router Configuration
- [ ] **T051** Add LiveView routes to router
  - **File**: `lib/sudoku_versus_web/router.ex`
  - **Details**: Add routes for /, /game (lobby), /game/:id (room), /leaderboard, /login, /register with appropriate live_session scopes
  - **Dependencies**: T043, T045, T047, T049

---

## Phase 3.4: Integration & Real-Time Features

### PubSub Integration
- [ ] **T052** Add PubSub broadcasting to record_move/3
  - **File**: `lib/sudoku_versus/games.ex`
  - **Details**: After recording move, broadcast {:new_move, move_id} to "game_room:#{room_id}" topic
  - **Verify**: T027 multiplayer test passes (real-time sync)
  - **Dependencies**: T036, T045

- [ ] **T053** Add Presence tracking to GameLive.Show mount
  - **File**: `lib/sudoku_versus_web/live/game_live/show.ex`
  - **Details**: Track player presence on mount when connected?(socket), handle presence_diff for player count updates
  - **Verify**: T028 presence test passes
  - **Dependencies**: T015, T045

### Session Management
- [ ] **T054** [P] Create authentication plug
  - **File**: `lib/sudoku_versus_web/plugs/authenticate.ex`
  - **Details**: Load current_user from session, assign to conn/socket
  - **Dependencies**: T029

- [ ] **T055** Add authentication to live_session in router
  - **File**: `lib/sudoku_versus_web/router.ex`
  - **Details**: Protect /game routes with authentication, redirect to /login if not authenticated
  - **Dependencies**: T054

---

## Phase 3.5: Polish & Testing

### Edge Cases & Error Handling
- [ ] **T056** [P] Add error handling for invalid moves
  - **File**: `lib/sudoku_versus_web/live/game_live/show.ex`
  - **Details**: Handle incorrect moves with penalty countdown (10 seconds), display error flash, prevent submission during penalty
  - **Verify**: Manual testing + update T023 with penalty tests
  - **Dependencies**: T045

- [ ] **T057** [P] Add reconnection handling
  - **File**: `lib/sudoku_versus_web/live/game_live/show.ex`
  - **Details**: Handle disconnects gracefully, re-subscribe to PubSub on reconnect, sync state from database
  - **Dependencies**: T045

- [ ] **T058** [P] Add empty state handling for streams
  - **File**: `lib/sudoku_versus_web/live/game_live/index.html.heex`, `lib/sudoku_versus_web/live/game_live/show.html.heex`
  - **Details**: Display "No rooms yet" when @rooms_count == 0, "No moves yet" when moves stream empty
  - **Dependencies**: T044, T046

### Performance Optimization
- [ ] **T059** [P] Add database indexes validation
  - **File**: Run query analysis on production-like dataset
  - **Details**: Verify all indexes from data-model.md are created, test query performance on large datasets (1000+ rooms, 100k+ moves)
  - **Dependencies**: T001-T007

- [ ] **T060** [P] Add query preloading to avoid N+1
  - **File**: `lib/sudoku_versus/games.ex`
  - **Details**: Verify all queries preload associations before template access (game_room.creator, move.player, etc.)
  - **Dependencies**: T034, T037

- [ ] **T061** Profile move validation performance
  - **File**: `lib/sudoku_versus/games/puzzle_generator.ex`
  - **Details**: Benchmark validate_move?/4, ensure <1ms average, verify solution caching is working
  - **Dependencies**: T032

### Documentation
- [ ] **T062** [P] Add module documentation
  - **File**: All `lib/sudoku_versus/**/*.ex` and `lib/sudoku_versus_web/**/*.ex` files
  - **Details**: Add @moduledoc with examples, document all public functions with @doc and @spec
  - **Dependencies**: All implementation tasks

- [ ] **T063** [P] Update README with feature overview
  - **File**: `README.md`
  - **Details**: Add MMO Sudoku section with features, architecture diagram, getting started
  - **Dependencies**: T062

- [ ] **T064** [P] Create seeds.exs for development
  - **File**: `priv/repo/seeds.exs`
  - **Details**: Generate 10 puzzles per difficulty, create 5 sample rooms, create 10 sample users
  - **Dependencies**: T032, T029, T034

### Final Validation
- [ ] **T065** Run mix precommit and fix issues
  - **Command**: `mix precommit`
  - **Details**: Ensure all tests pass, code is formatted, no compiler warnings
  - **Dependencies**: All previous tasks

- [ ] **T066** Execute quickstart.md scenarios
  - **File**: Follow `specs/002-mmo-sudoku-multiplayer/quickstart.md`
  - **Details**: Manually test all scenarios: guest flow, multiplayer flow, presence tracking, OAuth (if configured)
  - **Dependencies**: T065

- [ ] **T067** [P] Performance validation
  - **Details**: Verify <100ms move validation, <200ms broadcast latency, 100+ concurrent rooms, 1000+ concurrent users
  - **Tools**: Use :timer.tc/1 for validation timing, Apache Bench for load testing
  - **Dependencies**: T065

---

## Dependencies Summary

```
Setup (T001-T016)
  ↓
Tests First (T017-T028) ⚠️ ALL MUST FAIL BEFORE PROCEEDING
  ↓
Core Implementation (T029-T051)
  - Accounts: T029 → T030 → T031
  - Games Logic: T032, T033 (parallel)
  - Games Context: T034 → T035 → T036 → T037
  - Leaderboard: T038 → T039 → T040
  - OAuth: T041 → T042
  - LiveViews: T043 → T044, T045 → T046, T047 → T048, T049 → T050 (parallel groups)
  - Router: T051 (depends on all LiveViews)
  ↓
Integration (T052-T055)
  - PubSub: T052, T053
  - Auth: T054 → T055
  ↓
Polish (T056-T067)
  - Most tasks parallel except T065 → T066 → T067
```

---

## Parallel Execution Examples

### Example 1: Tests First Phase (after setup complete)
```bash
# All test files are independent, run in parallel:
# T017-T028 can all run simultaneously
Task T017: "Write Accounts context tests in test/sudoku_versus/accounts_test.exs"
Task T018: "Write puzzle generation tests in test/sudoku_versus/games/puzzle_generator_test.exs"
Task T019: "Write scoring tests in test/sudoku_versus/games/scorer_test.exs"
Task T020: "Write game room tests in test/sudoku_versus/games_test.exs"
Task T021: "Write OAuth controller tests in test/sudoku_versus_web/controllers/auth_controller_test.exs"
Task T022: "Write lobby LiveView tests in test/sudoku_versus_web/live/game_live/index_test.exs"
Task T023: "Write game room LiveView tests in test/sudoku_versus_web/live/game_live/show_test.exs"
Task T024: "Write leaderboard LiveView tests in test/sudoku_versus_web/live/leaderboard_live/index_test.exs"
Task T025: "Write auth LiveView tests in test/sudoku_versus_web/live/auth_live_test.exs"
Task T026: "Write guest flow integration test in test/sudoku_versus_web/integration/guest_flow_test.exs"
Task T027: "Write multiplayer flow test in test/sudoku_versus_web/integration/multiplayer_flow_test.exs"
Task T028: "Write presence tracking test in test/sudoku_versus_web/integration/presence_test.exs"
```

### Example 2: Schema Creation (after migrations)
```bash
# All schemas are independent, run in parallel:
# T008-T014 can all run simultaneously
Task T008: "Create User schema in lib/sudoku_versus/accounts/user.ex"
Task T009: "Create Puzzle schema in lib/sudoku_versus/games/puzzle.ex"
Task T010: "Create GameRoom schema in lib/sudoku_versus/games/game_room.ex"
Task T011: "Create PlayerSession schema in lib/sudoku_versus/games/player_session.ex"
Task T012: "Create Move schema in lib/sudoku_versus/games/move.ex"
Task T013: "Create ScoreRecord schema in lib/sudoku_versus/games/score_record.ex"
Task T014: "Create LeaderboardEntry schema in lib/sudoku_versus/games/leaderboard_entry.ex"
```

### Example 3: Core Logic Implementation (after tests fail)
```bash
# Parallel within groups:
Task T029: "Implement Accounts context in lib/sudoku_versus/accounts.ex"
Task T032: "Implement PuzzleGenerator in lib/sudoku_versus/games/puzzle_generator.ex"
Task T033: "Implement Scorer in lib/sudoku_versus/games/scorer.ex"

# Then after T034:
Task T038: "Implement LeaderboardRefresher in lib/sudoku_versus/games/leaderboard_refresher.ex"
Task T041: "Implement AuthController in lib/sudoku_versus_web/controllers/auth_controller.ex"
```

---

## Task Validation Checklist

- [x] All contracts (OAuth endpoints) have corresponding tests (T021)
- [x] All entities (7 schemas) have model tasks (T008-T014)
- [x] All tests come before implementation (Phase 3.2 before 3.3)
- [x] Parallel tasks ([P]) are truly independent (different files)
- [x] Each task specifies exact file path
- [x] No [P] task modifies same file as another [P] task
- [x] TDD approach enforced: tests → verify failure → implement → verify pass

---

## Notes

- **CRITICAL**: Phase 3.2 tests MUST be written and MUST FAIL before starting Phase 3.3 implementation
- Use `mix test --failed` to rerun only failed tests during TDD
- Commit after each task completion
- Run `mix format` before committing
- Use DOM IDs in templates for testability
- LiveView streams for unbounded collections (moves, players, rooms)
- Regular assigns for fixed structures (9x9 game grid)
- Phoenix.PubSub for real-time multiplayer
- Phoenix.Presence for player tracking with auto-cleanup
- All foreign keys use binary_id type
- Preload associations before template access

---

**Total Tasks**: 67
**Estimated Timeline**: 19-28 days (single developer) or 12-16 days (2 developers with parallelization)
**Critical Path**: T001-T007 → T017-T028 → T034-T037 → T043-T046 → T052-T053 → T065-T067
