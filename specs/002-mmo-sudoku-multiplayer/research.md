# Research: MMO Sudoku Multiplayer

**Feature**: 002-mmo-sudoku-multiplayer
**Date**: 2025-01-10
**Status**: Complete

## Purpose
Research technical approaches, patterns, and libraries needed to implement a massive multiplayer online Sudoku game using Phoenix LiveView, ensuring architectural decisions align with performance requirements (<100ms validation, <200ms broadcast) and scale goals (100+ rooms, 1000+ concurrent players with auto-scaling).

---

## Research Topics

### 1. Sudoku Puzzle Generation

**Question**: How to generate valid Sudoku puzzles with varying difficulty levels in Elixir?

**Findings**:
- **Algorithm**: Backtracking algorithm with constraint propagation
  1. Start with empty 9x9 grid
  2. Fill diagonal 3x3 boxes first (no conflicts possible)
  3. Use recursive backtracking to fill remaining cells
  4. Validate each placement against row/column/box constraints
  5. Remove numbers strategically to create puzzle (more removed = harder)

- **Difficulty Levels**:
  - **Easy**: 40-45 clues (pre-filled numbers)
  - **Medium**: 30-35 clues
  - **Hard**: 25-28 clues
  - **Expert**: 22-24 clues

- **Implementation**:
  ```elixir
  defmodule SudokuVersus.Games.PuzzleGenerator do
    # Generate solved grid using backtracking
    def generate_solved_grid() do
      grid = initialize_empty_grid()
      |> fill_diagonal_boxes()
      |> solve_recursive()
    end

    # Remove numbers to create puzzle
    def create_puzzle(solved_grid, difficulty) do
      clues_count = clues_for_difficulty(difficulty)
      remove_numbers(solved_grid, 81 - clues_count)
    end

    # Validate move against Sudoku rules
    def valid_move?(grid, row, col, value) do
      valid_in_row?(grid, row, value) and
      valid_in_column?(grid, col, value) and
      valid_in_box?(grid, row, col, value)
    end
  end
  ```

- **Performance**: Generation takes 10-50ms depending on difficulty, acceptable for our <100ms validation requirement. Cache generated puzzles in database.

**Decision**: Implement custom backtracking generator. No external libraries needed. Store puzzles as JSON arrays `[[1,2,3,...],[...],...]` with solution alongside for validation.

---

### 2. Real-Time Multiplayer Pattern with PubSub

**Question**: How to structure Phoenix.PubSub for real-time game synchronization with minimal latency?

**Findings**:
- **Topic Structure**: One topic per game room
  - Format: `"game_room:{room_id}"`
  - Example: `"game_room:abc123"`

- **Broadcast Pattern**:
  ```elixir
  # In LiveView when player makes move
  def handle_event("submit_move", params, socket) do
    case Games.record_move(socket.assigns.room_id, socket.assigns.player_id, params) do
      {:ok, move} ->
        # Broadcast to all players in room
        Phoenix.PubSub.broadcast(
          SudokuVersus.PubSub,
          "game_room:#{socket.assigns.room_id}",
          {:new_move, move}
        )
        {:noreply, socket}
    end
  end

  # Subscribe in mount
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SudokuVersus.PubSub, "game_room:#{room_id}")
    end
    {:ok, assign(socket, room_id: room_id)}
  end

  # Handle broadcasts
  def handle_info({:new_move, move}, socket) do
    {:noreply, stream_insert(socket, :moves, move)}
  end
  ```

- **Latency**: PubSub broadcast within same node: <5ms, across nodes: 20-50ms depending on network. Well under <200ms requirement.

- **Message Types**:
  - `{:new_move, move}` - Player submitted move
  - `{:player_joined, player}` - New player entered room
  - `{:player_left, player}` - Player left room
  - `{:game_completed, winner}` - First player completed puzzle

**Decision**: Use per-room PubSub topics. LiveViews subscribe on mount, broadcast on state changes. Keep messages small (IDs only, fetch full data via assigns if needed).

---

### 3. Phoenix.Presence for Player Tracking

**Question**: How to track online players per room and detect disconnections?

**Findings**:
- **Phoenix.Presence** provides distributed, eventually-consistent presence tracking

- **Setup**:
  ```elixir
  # lib/sudoku_versus_web/presence.ex
  defmodule SudokuVersusWeb.Presence do
    use Phoenix.Presence,
      otp_app: :sudoku_versus,
      pubsub_server: SudokuVersus.PubSub
  end

  # In application.ex
  children = [
    SudokuVersusWeb.Presence,
    ...
  ]
  ```

- **Usage Pattern**:
  ```elixir
  # Track player when joining room
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      {:ok, _} = SudokuVersusWeb.Presence.track(
        self(),
        "game_room:#{room_id}",
        socket.assigns.player_id,
        %{
          username: socket.assigns.username,
          joined_at: System.system_time(:second)
        }
      )

      Phoenix.PubSub.subscribe(SudokuVersus.PubSub, "game_room:#{room_id}")
    end

    {:ok, assign(socket, :online_players, list_presences(room_id))}
  end

  # Handle presence diffs
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply,
     socket
     |> assign(:online_players, list_presences(socket.assigns.room_id))
     |> update(:players_online_count, fn _ -> length(socket.assigns.online_players) end)
    }
  end

  defp list_presences(room_id) do
    SudokuVersusWeb.Presence.list("game_room:#{room_id}")
    |> Enum.map(fn {_id, data} -> hd(data.metas) end)
  end
  ```

- **Automatic Cleanup**: Presence automatically removes player when LiveView process terminates (disconnect, tab close, crash)

**Decision**: Use Phoenix.Presence per game room. Track by player_id. Automatically handles disconnections. Store minimal metadata (username, joined_at) in presence, full profile in database.

---

### 4. LiveView Streams for Dynamic Content

**Question**: Should game board cells use streams, or regular assigns?

**Findings**:
- **Game Board (9x9 grid)**: Use **regular assign**, NOT streams
  - Grid structure is fixed (81 cells)
  - Full grid re-renders are rare (only on initial load or board reset)
  - Cell updates happen via targeted patches, not full replacement
  - Streams add unnecessary complexity for fixed-size data

  ```elixir
  # Store as nested list assign
  assign(socket, :grid, [
    [1, 2, nil, 4, ...],  # row 0
    [nil, 5, 6, ...],     # row 1
    ...
  ])
  ```

- **Move History**: Use **streams** ✅
  - Unbounded growth (hundreds/thousands of moves per game)
  - Append-only operation (new moves added continuously)
  - Memory efficient with streams

  ```elixir
  # In mount
  moves = Games.list_recent_moves(room_id, limit: 50)
  socket = stream(socket, :moves, moves)

  # On new move
  socket = stream_insert(socket, :moves, new_move, at: 0)  # prepend latest
  ```

- **Player List**: Use **streams** ✅
  - Players join/leave dynamically (unlimited capacity)
  - Could grow to thousands of players

  ```elixir
  socket = stream(socket, :players, online_players)

  # When player joins
  socket = stream_insert(socket, :players, player)

  # When player leaves
  socket = stream_delete(socket, :players, player)
  ```

- **Room List**: Use **streams** ✅
  - 100+ concurrent rooms expected
  - Rooms created/deleted dynamically

  ```elixir
  socket = stream(socket, :rooms, active_rooms)
  ```

**Decision**:
- Game board grid: Regular assign (fixed 81 cells)
- Move history: Streams (unbounded)
- Player lists: Streams (unlimited capacity)
- Room lists: Streams (100+ items)

---

### 5. Real-Time Scoring Calculation

**Question**: When to calculate scores - per move, batched, or on-demand?

**Findings**:
- **Per-Move Calculation**: ✅ Recommended
  - Immediate feedback for player (better UX)
  - Scoring formula is lightweight:
    ```elixir
    puntos = puntos_base * multiplicador_racha + bono_velocidad - penalizaciones
    ```
    Takes <1ms to compute
  - Meets <100ms validation requirement easily

- **Implementation**:
  ```elixir
  def calculate_score(move, player_session, puzzle) do
    base_points = base_points_for_difficulty(puzzle.difficulty)

    streak_multiplier = calculate_streak_multiplier(player_session.current_streak)
    speed_bonus = calculate_speed_bonus(player_session.started_at, move.submitted_at)
    penalties = calculate_penalties(player_session.incorrect_moves_count)

    base_points * streak_multiplier + speed_bonus - penalties
  end

  defp base_points_for_difficulty(:easy), do: 500
  defp base_points_for_difficulty(:medium), do: 1500
  defp base_points_for_difficulty(:hard), do: 3000
  defp base_points_for_difficulty(:expert), do: 5000

  defp calculate_streak_multiplier(streak) when streak >= 10, do: 2.0
  defp calculate_streak_multiplier(streak) when streak >= 5, do: 1.5
  defp calculate_streak_multiplier(_), do: 1.0

  defp calculate_speed_bonus(started_at, submitted_at) do
    seconds_elapsed = DateTime.diff(submitted_at, started_at, :second)
    max(0, 1000 - seconds_elapsed * 10)  # Lose 10 points per second
  end

  defp calculate_penalties(incorrect_count) do
    incorrect_count * 100  # -100 per error
  end
  ```

- **Storage**: Store cumulative score in `player_sessions.current_score`, update on each move

- **Leaderboard Updates**: Batch leaderboard recalculations every 60 seconds (background GenServer task), not real-time per move

**Decision**: Calculate scores immediately on each move submission. Store in player_sessions table. Broadcast score updates via PubSub. Leaderboard ranking updates batched every minute.

---

### 6. OAuth Integration

**Question**: Which OAuth providers and implementation approach?

**Findings**:
- **Providers**: Google, GitHub (most common, easy integration)

- **Library Options**:
  1. **Ueberauth** (traditional approach)
     - Pros: Mature, many strategies available
     - Cons: Additional dependencies (ueberauth + ueberauth_google + ueberauth_github)

  2. **Custom with Req** (constitution-compliant) ✅
     - Pros: Minimal dependencies (Req already included), full control
     - Cons: More code to write/maintain

- **Custom Implementation**:
  ```elixir
  defmodule SudokuVersus.Accounts.OAuth do
    # Redirect user to provider
    def authorize_url(:google) do
      params = %{
        client_id: Application.get_env(:sudoku_versus, :google_client_id),
        redirect_uri: "#{app_url()}/auth/google/callback",
        response_type: "code",
        scope: "email profile"
      }
      "https://accounts.google.com/o/oauth2/v2/auth?" <> URI.encode_query(params)
    end

    # Exchange code for token
    def fetch_token(:google, code) do
      Req.post!("https://oauth2.googleapis.com/token",
        json: %{
          code: code,
          client_id: Application.get_env(:sudoku_versus, :google_client_id),
          client_secret: Application.get_env(:sudoku_versus, :google_client_secret),
          redirect_uri: "#{app_url()}/auth/google/callback",
          grant_type: "authorization_code"
        }
      )
    end

    # Fetch user info
    def fetch_user_info(:google, access_token) do
      Req.get!("https://www.googleapis.com/oauth2/v2/userinfo",
        headers: [{"Authorization", "Bearer #{access_token}"}]
      )
    end
  end
  ```

- **Token Storage**: Store OAuth provider + provider_user_id in users table, don't store access tokens (request new on each auth)

**Decision**: Implement custom OAuth with Req (aligns with constitution Principle V). Support Google and GitHub. Store provider metadata in users table. No persistent token storage.

---

### 7. Auto-Scaling Architecture

**Question**: How to design for horizontal scaling across multiple nodes?

**Findings**:
- **Stateful Components** (need coordination):
  1. **Game rooms**: Store in PostgreSQL, not in-memory
  2. **Player sessions**: Store in database, not LiveView assigns only
  3. **Active games**: Database-backed, not node-local state

- **Distributed Coordination**:
  - Phoenix.PubSub works across nodes automatically (uses pg2/pg built-in distribution)
  - Phoenix.Presence works across nodes (CRDT-based, eventually consistent)
  - Database serves as source of truth

- **Node Communication**:
  ```elixir
  # config/runtime.exs - enable distributed Erlang
  config :sudoku_versus, SudokuVersusWeb.Endpoint,
    pubsub_server: SudokuVersus.PubSub

  # PubSub broadcasts work across all connected nodes
  Phoenix.PubSub.broadcast(SudokuVersus.PubSub, topic, message)
  # This reaches subscribers on ALL nodes
  ```

- **Scaling Strategy**:
  1. **Horizontal scaling**: Add nodes behind load balancer
  2. **Session affinity**: NOT required (any node can handle any request)
  3. **Database connection pooling**: Use Ecto's built-in pooling (default pool_size: 10)
  4. **Read replicas**: For leaderboards, room lists (read-heavy operations)

- **Bottlenecks**:
  - Database writes (move submissions) - Mitigate with indexes, optimized queries
  - PubSub fan-out with 1000+ subscribers - Acceptable (Erlang handles efficiently)

**Decision**: Database-backed state (game rooms, sessions, moves in PostgreSQL). Use distributed Erlang with Phoenix.PubSub for cross-node communication. No sticky sessions required. Scale horizontally by adding nodes.

---

### 8. Performance Optimization

**Question**: How to ensure <100ms move validation and <200ms broadcast latency?

**Findings**:
- **Move Validation Optimization**:
  ```elixir
  # Cache puzzle solution as map for O(1) lookup
  defp cache_solution(puzzle) do
    puzzle.solution
    |> List.flatten()
    |> Enum.with_index()
    |> Map.new(fn {value, index} -> {index, value} end)
  end

  # Validate in <1ms
  def validate_move(cached_solution, row, col, value) do
    index = row * 9 + col
    cached_solution[index] == value
  end
  ```

- **Database Query Optimization**:
  - Index on `game_rooms.id`, `moves.game_room_id`, `moves.inserted_at`
  - Use `select` to load only needed fields: `from(m in Move, select: [:id, :row, :col, :value, :player_id])`
  - Preload associations: `Repo.preload(move, :player)`

- **Broadcast Optimization**:
  - Send minimal data in PubSub messages (IDs only, not full structs)
  - Debounce rapid updates (wait 50ms before broadcasting batch)

  ```elixir
  # Debounced broadcast
  def handle_event("submit_move", params, socket) do
    send(self(), {:broadcast_move, move})
    {:noreply, socket}
  end

  def handle_info({:broadcast_move, move}, socket) do
    Process.send_after(self(), {:do_broadcast, move}, 50)
    {:noreply, socket}
  end

  def handle_info({:do_broadcast, move}, socket) do
    Phoenix.PubSub.broadcast(..., {:new_move, move.id})
    {:noreply, socket}
  end
  ```

- **LiveView Optimization**:
  - Use `phx-debounce="300"` on input forms to reduce event spam
  - Stream updates instead of full re-renders
  - Lazy-load move history (only last 50 moves initially)

**Performance Targets**:
- Move validation: 1-5ms ✅ (well under 100ms)
- Database insert: 5-15ms ✅
- PubSub broadcast: 5-50ms ✅ (well under 200ms)
- Total latency: 11-70ms ✅ (meets requirements)

**Decision**: Cache puzzle solutions as maps. Index database tables. Use selective queries with preloading. Debounce rapid broadcasts. Stream incremental updates.

---

## Summary of Decisions

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Puzzle Generation | Custom backtracking algorithm, cache in DB | No external deps needed, 10-50ms generation acceptable |
| Real-Time Sync | Phoenix.PubSub per-room topics | <50ms latency, built-in distribution |
| Player Tracking | Phoenix.Presence per room | Auto-cleanup, distributed, minimal overhead |
| Game Board Storage | Regular assign (not streams) | Fixed 81 cells, streams unnecessary |
| Move History Storage | LiveView streams | Unbounded growth, memory efficient |
| Player Lists | LiveView streams | Unlimited capacity support |
| Room Lists | LiveView streams | 100+ rooms expected |
| Scoring Calculation | Per-move, immediate | <1ms compute, better UX |
| OAuth Implementation | Custom with Req | Constitution-compliant, minimal deps |
| Scaling Architecture | Database-backed state, distributed Erlang | Horizontal scaling, no sticky sessions |
| Performance Strategy | Cache solutions, index DB, debounce broadcasts | Meets <100ms validation, <200ms broadcast |

---

## Open Questions
*None - all technical unknowns resolved*

---

## Next Steps
Proceed to Phase 1:
1. Generate `data-model.md` with Ecto schemas
2. Create `contracts/` directory (if REST endpoints needed for OAuth callbacks)
3. Generate `quickstart.md` for developer onboarding
4. Update `AGENTS.md` with feature-specific guidance
