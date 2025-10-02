# Data Model: MMO Sudoku Multiplayer

**Feature**: 002-mmo-sudoku-multiplayer
**Date**: 2025-01-10
**Status**: Complete

## Purpose
Define the Ecto schemas, database tables, and relationships needed to support massive multiplayer Sudoku games with real-time move tracking, player sessions, scoring, and leaderboards.

---

## Entity Relationship Diagram

```
users (players)
  ├─── has_many: player_sessions
  ├─── has_many: moves
  ├─── has_many: score_records
  └─── has_many: created_rooms (game_rooms via creator_id)

game_rooms
  ├─── belongs_to: creator (users)
  ├─── belongs_to: puzzle
  ├─── has_many: player_sessions
  ├─── has_many: moves
  └─── has_many: score_records

puzzles
  └─── has_many: game_rooms

player_sessions
  ├─── belongs_to: player (users)
  ├─── belongs_to: game_room
  └─── has_many: moves

moves
  ├─── belongs_to: player (users)
  ├─── belongs_to: game_room
  └─── belongs_to: player_session

score_records
  ├─── belongs_to: player (users)
  └─── belongs_to: game_room

leaderboard_entries (materialized view - computed from score_records)
  └─── belongs_to: player (users)
```

---

## Schemas

### 1. Users (Players)

**Table**: `users`
**Module**: `SudokuVersus.Accounts.User`

```elixir
defmodule SudokuVersus.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :email, :string
    field :display_name, :string
    field :avatar_url, :string

    # Authentication
    field :password_hash, :string
    field :is_guest, :boolean, default: false

    # OAuth
    field :oauth_provider, :string  # "google", "github", nil
    field :oauth_provider_id, :string  # Unique ID from provider

    # Statistics (denormalized for performance)
    field :total_games_played, :integer, default: 0
    field :total_puzzles_completed, :integer, default: 0
    field :total_points_earned, :integer, default: 0
    field :highest_score, :integer, default: 0

    timestamps(type: :utc_datetime)

    has_many :player_sessions, SudokuVersus.Games.PlayerSession, foreign_key: :player_id
    has_many :moves, SudokuVersus.Games.Move, foreign_key: :player_id
    has_many :score_records, SudokuVersus.Games.ScoreRecord, foreign_key: :player_id
    has_many :created_rooms, SudokuVersus.Games.GameRoom, foreign_key: :creator_id
  end

  @doc "Changeset for guest registration"
  def guest_changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> put_change(:is_guest, true)
    |> put_change(:display_name, attrs["username"])
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/)
    |> unique_constraint(:username)
  end

  @doc "Changeset for registered user"
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> put_change(:is_guest, false)
    |> put_change(:display_name, attrs["username"])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 2, max: 20)
    |> validate_length(:password, min: 8)
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  @doc "Changeset for OAuth registration"
  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :oauth_provider, :oauth_provider_id, :avatar_url])
    |> put_change(:is_guest, false)
    |> put_change(:display_name, attrs["username"])
    |> validate_required([:username, :oauth_provider, :oauth_provider_id])
    |> unique_constraint(:username)
    |> unique_constraint([:oauth_provider, :oauth_provider_id])
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end
end
```

**Indexes**:
- `CREATE UNIQUE INDEX users_username_index ON users (username)`
- `CREATE UNIQUE INDEX users_email_index ON users (email)`
- `CREATE UNIQUE INDEX users_oauth_provider_id_index ON users (oauth_provider, oauth_provider_id)`
- `CREATE INDEX users_total_points_index ON users (total_points_earned DESC)` (for leaderboards)

---

### 2. Puzzles

**Table**: `puzzles`
**Module**: `SudokuVersus.Games.Puzzle`

```elixir
defmodule SudokuVersus.Games.Puzzle do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "puzzles" do
    field :difficulty, Ecto.Enum, values: [:easy, :medium, :hard, :expert]
    field :grid, {:array, {:array, :integer}}  # 9x9 nested array with clues (nil = empty cell)
    field :solution, {:array, {:array, :integer}}  # 9x9 complete solution
    field :clues_count, :integer  # Number of pre-filled cells

    timestamps(type: :utc_datetime)

    has_many :game_rooms, SudokuVersus.Games.GameRoom
  end

  @doc "Changeset for creating puzzle"
  def changeset(puzzle, attrs) do
    puzzle
    |> cast(attrs, [:difficulty, :grid, :solution, :clues_count])
    |> validate_required([:difficulty, :grid, :solution, :clues_count])
    |> validate_inclusion(:difficulty, [:easy, :medium, :hard, :expert])
    |> validate_grid_structure()
    |> validate_clues_count()
  end

  defp validate_grid_structure(changeset) do
    # Ensure grid is 9x9 with valid values
    case get_field(changeset, :grid) do
      grid when is_list(grid) and length(grid) == 9 ->
        if Enum.all?(grid, fn row -> is_list(row) and length(row) == 9 end) do
          changeset
        else
          add_error(changeset, :grid, "must be 9x9 structure")
        end
      _ ->
        add_error(changeset, :grid, "must be 9x9 structure")
    end
  end

  defp validate_clues_count(changeset) do
    difficulty = get_field(changeset, :difficulty)
    clues_count = get_field(changeset, :clues_count)

    valid_range = case difficulty do
      :easy -> 40..45
      :medium -> 30..35
      :hard -> 25..28
      :expert -> 22..24
      _ -> 0..0
    end

    if clues_count in valid_range do
      changeset
    else
      add_error(changeset, :clues_count, "must be in range #{inspect(valid_range)} for #{difficulty}")
    end
  end
end
```

**Indexes**:
- `CREATE INDEX puzzles_difficulty_index ON puzzles (difficulty)`

**Storage Notes**:
- Grid stored as PostgreSQL array type: `{{1,2,NULL,4,...},{...},...}`
- Solution cached for O(1) validation in application layer

---

### 3. Game Rooms

**Table**: `game_rooms`
**Module**: `SudokuVersus.Games.GameRoom`

```elixir
defmodule SudokuVersus.Games.GameRoom do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_rooms" do
    field :name, :string
    field :status, Ecto.Enum, values: [:active, :completed, :archived], default: :active
    field :max_players, :integer  # NULL = unlimited
    field :visibility, Ecto.Enum, values: [:public, :private], default: :public
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    # Denormalized counts for performance
    field :current_players_count, :integer, default: 0
    field :total_moves_count, :integer, default: 0

    belongs_to :creator, SudokuVersus.Accounts.User
    belongs_to :puzzle, SudokuVersus.Games.Puzzle

    has_many :player_sessions, SudokuVersus.Games.PlayerSession
    has_many :moves, SudokuVersus.Games.Move
    has_many :score_records, SudokuVersus.Games.ScoreRecord

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating room"
  def changeset(game_room, attrs) do
    game_room
    |> cast(attrs, [:name, :max_players, :visibility, :creator_id, :puzzle_id])
    |> validate_required([:name, :creator_id, :puzzle_id])
    |> validate_length(:name, min: 1, max: 30)
    |> validate_name_format()
    |> validate_number(:max_players, greater_than: 0)
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:puzzle_id)
  end

  defp validate_name_format(changeset) do
    # Allow alphanumeric, spaces, and emojis
    case get_field(changeset, :name) do
      nil -> changeset
      name ->
        if String.length(name) <= 30 and Regex.match?(~r/^[\p{L}\p{N}\p{Emoji}\s]+$/u, name) do
          changeset
        else
          add_error(changeset, :name, "must be alphanumeric or emojis, max 30 characters")
        end
    end
  end

  @doc "Changeset for updating room status"
  def status_changeset(game_room, attrs) do
    game_room
    |> cast(attrs, [:status, :completed_at])
    |> validate_required([:status])
  end
end
```

**Indexes**:
- `CREATE INDEX game_rooms_status_index ON game_rooms (status)`
- `CREATE INDEX game_rooms_created_at_index ON game_rooms (inserted_at DESC)`
- `CREATE INDEX game_rooms_creator_id_index ON game_rooms (creator_id)`

---

### 4. Player Sessions

**Table**: `player_sessions`
**Module**: `SudokuVersus.Games.PlayerSession`

```elixir
defmodule SudokuVersus.Games.PlayerSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "player_sessions" do
    field :started_at, :utc_datetime
    field :last_activity_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :is_active, :boolean, default: true

    # Scoring tracking
    field :current_score, :integer, default: 0
    field :current_streak, :integer, default: 0
    field :longest_streak, :integer, default: 0
    field :correct_moves_count, :integer, default: 0
    field :incorrect_moves_count, :integer, default: 0
    field :cells_filled, :integer, default: 0
    field :completed_puzzle, :boolean, default: false

    belongs_to :player, SudokuVersus.Accounts.User
    belongs_to :game_room, SudokuVersus.Games.GameRoom

    has_many :moves, SudokuVersus.Games.Move

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating session"
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:player_id, :game_room_id, :started_at])
    |> put_change(:started_at, DateTime.utc_now())
    |> put_change(:last_activity_at, DateTime.utc_now())
    |> validate_required([:player_id, :game_room_id])
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:game_room_id)
    |> unique_constraint([:player_id, :game_room_id])
  end

  @doc "Changeset for updating session stats"
  def update_stats_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :current_score,
      :current_streak,
      :longest_streak,
      :correct_moves_count,
      :incorrect_moves_count,
      :cells_filled,
      :last_activity_at
    ])
    |> put_change(:last_activity_at, DateTime.utc_now())
  end

  @doc "Changeset for completing session"
  def complete_changeset(session) do
    session
    |> cast(%{}, [])
    |> put_change(:completed_at, DateTime.utc_now())
    |> put_change(:completed_puzzle, true)
    |> put_change(:is_active, false)
  end
end
```

**Indexes**:
- `CREATE UNIQUE INDEX player_sessions_player_room_index ON player_sessions (player_id, game_room_id)`
- `CREATE INDEX player_sessions_game_room_id_index ON player_sessions (game_room_id)`
- `CREATE INDEX player_sessions_is_active_index ON player_sessions (is_active)`

---

### 5. Moves

**Table**: `moves`
**Module**: `SudokuVersus.Games.Move`

```elixir
defmodule SudokuVersus.Games.Move do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "moves" do
    field :row, :integer  # 0-8
    field :col, :integer  # 0-8
    field :value, :integer  # 1-9
    field :is_correct, :boolean
    field :submitted_at, :utc_datetime
    field :points_earned, :integer, default: 0

    belongs_to :player, SudokuVersus.Accounts.User
    belongs_to :game_room, SudokuVersus.Games.GameRoom
    belongs_to :player_session, SudokuVersus.Games.PlayerSession

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for recording move"
  def changeset(move, attrs) do
    move
    |> cast(attrs, [:row, :col, :value, :is_correct, :points_earned, :player_id, :game_room_id, :player_session_id])
    |> put_change(:submitted_at, DateTime.utc_now())
    |> validate_required([:row, :col, :value, :player_id, :game_room_id, :player_session_id])
    |> validate_number(:row, greater_than_or_equal_to: 0, less_than: 9)
    |> validate_number(:col, greater_than_or_equal_to: 0, less_than: 9)
    |> validate_number(:value, greater_than: 0, less_than_or_equal_to: 9)
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:game_room_id)
    |> foreign_key_constraint(:player_session_id)
  end
end
```

**Indexes**:
- `CREATE INDEX moves_game_room_id_index ON moves (game_room_id, inserted_at DESC)`
- `CREATE INDEX moves_player_session_id_index ON moves (player_session_id)`
- `CREATE INDEX moves_player_id_index ON moves (player_id)`

---

### 6. Score Records

**Table**: `score_records`
**Module**: `SudokuVersus.Games.ScoreRecord`

```elixir
defmodule SudokuVersus.Games.ScoreRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "score_records" do
    field :final_score, :integer
    field :time_elapsed_seconds, :integer
    field :correct_moves, :integer
    field :incorrect_moves, :integer
    field :longest_streak, :integer
    field :completed_puzzle, :boolean
    field :difficulty, Ecto.Enum, values: [:easy, :medium, :hard, :expert]
    field :recorded_at, :utc_datetime

    belongs_to :player, SudokuVersus.Accounts.User
    belongs_to :game_room, SudokuVersus.Games.GameRoom

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for recording final score"
  def changeset(score_record, attrs) do
    score_record
    |> cast(attrs, [
      :final_score,
      :time_elapsed_seconds,
      :correct_moves,
      :incorrect_moves,
      :longest_streak,
      :completed_puzzle,
      :difficulty,
      :player_id,
      :game_room_id
    ])
    |> put_change(:recorded_at, DateTime.utc_now())
    |> validate_required([
      :final_score,
      :time_elapsed_seconds,
      :correct_moves,
      :difficulty,
      :player_id,
      :game_room_id
    ])
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:game_room_id)
  end
end
```

**Indexes**:
- `CREATE INDEX score_records_player_id_index ON score_records (player_id, final_score DESC)`
- `CREATE INDEX score_records_difficulty_index ON score_records (difficulty, final_score DESC)`
- `CREATE INDEX score_records_recorded_at_index ON score_records (recorded_at DESC)`

---

### 7. Leaderboard Entries (Materialized View)

**View**: `leaderboard_entries`
**Module**: `SudokuVersus.Games.LeaderboardEntry` (read-only schema)

```elixir
defmodule SudokuVersus.Games.LeaderboardEntry do
  use Ecto.Schema

  @primary_key false

  schema "leaderboard_entries" do
    field :player_id, :binary_id
    field :username, :string
    field :display_name, :string
    field :avatar_url, :string
    field :total_score, :integer
    field :games_completed, :integer
    field :average_score, :float
    field :highest_single_score, :integer
    field :rank, :integer
    field :difficulty, Ecto.Enum, values: [:easy, :medium, :hard, :expert, :all]
  end
end
```

**SQL Definition** (migration):
```sql
CREATE MATERIALIZED VIEW leaderboard_entries AS
  SELECT
    u.id AS player_id,
    u.username,
    u.display_name,
    u.avatar_url,
    SUM(sr.final_score) AS total_score,
    COUNT(*) FILTER (WHERE sr.completed_puzzle = true) AS games_completed,
    AVG(sr.final_score) AS average_score,
    MAX(sr.final_score) AS highest_single_score,
    sr.difficulty,
    RANK() OVER (PARTITION BY sr.difficulty ORDER BY SUM(sr.final_score) DESC) AS rank
  FROM users u
  INNER JOIN score_records sr ON sr.player_id = u.id
  WHERE sr.completed_puzzle = true
  GROUP BY u.id, u.username, u.display_name, u.avatar_url, sr.difficulty

  UNION ALL

  SELECT
    u.id AS player_id,
    u.username,
    u.display_name,
    u.avatar_url,
    SUM(sr.final_score) AS total_score,
    COUNT(*) FILTER (WHERE sr.completed_puzzle = true) AS games_completed,
    AVG(sr.final_score) AS average_score,
    MAX(sr.final_score) AS highest_single_score,
    'all'::difficulty_enum AS difficulty,
    RANK() OVER (ORDER BY SUM(sr.final_score) DESC) AS rank
  FROM users u
  INNER JOIN score_records sr ON sr.player_id = u.id
  WHERE sr.completed_puzzle = true
  GROUP BY u.id, u.username, u.display_name, u.avatar_url;

CREATE UNIQUE INDEX leaderboard_entries_player_difficulty_index
  ON leaderboard_entries (player_id, difficulty);
```

**Refresh Strategy**:
```elixir
# In SudokuVersus.Games context
def refresh_leaderboard do
  Repo.query!("REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_entries")
end
```

**Background Job** (every 60 seconds):
```elixir
defmodule SudokuVersus.Games.LeaderboardRefresher do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    schedule_refresh()
    {:ok, state}
  end

  def handle_info(:refresh, state) do
    SudokuVersus.Games.refresh_leaderboard()
    schedule_refresh()
    {:noreply, state}
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, 60_000)  # 60 seconds
  end
end
```

---

## Migration Order

1. **users** (no dependencies)
2. **puzzles** (no dependencies)
3. **game_rooms** (depends on: users, puzzles)
4. **player_sessions** (depends on: users, game_rooms)
5. **moves** (depends on: users, game_rooms, player_sessions)
6. **score_records** (depends on: users, game_rooms)
7. **leaderboard_entries** (materialized view, depends on: users, score_records)

---

## Database Constraints

### Foreign Keys
All foreign key columns have `ON DELETE` behavior:
- `users.id` → `CASCADE` (delete user deletes all their data)
- `game_rooms.id` → `CASCADE` (delete room deletes sessions, moves, scores)
- `puzzles.id` → `RESTRICT` (cannot delete puzzle if rooms exist)

### Check Constraints
- `moves.row >= 0 AND moves.row < 9`
- `moves.col >= 0 AND moves.col < 9`
- `moves.value >= 1 AND moves.value <= 9`
- `puzzles.clues_count >= 22 AND puzzles.clues_count <= 45`

---

## Query Patterns

### Common Queries

**Get active rooms with player count:**
```elixir
from r in GameRoom,
  where: r.status == :active,
  preload: [:creator, :puzzle],
  order_by: [desc: r.inserted_at],
  select: r
```

**Get moves for room (with streams):**
```elixir
from m in Move,
  where: m.game_room_id == ^room_id,
  order_by: [desc: m.inserted_at],
  limit: 50,
  preload: [:player],
  select: m
```

**Get player session with stats:**
```elixir
from s in PlayerSession,
  where: s.player_id == ^player_id and s.game_room_id == ^room_id,
  select: s
|> Repo.one()
```

**Get leaderboard (top 100):**
```elixir
from l in LeaderboardEntry,
  where: l.difficulty == ^difficulty,
  order_by: [asc: l.rank],
  limit: 100,
  select: l
```

---

## Next Steps
1. Generate migrations for all schemas
2. Create context modules (`SudokuVersus.Games`, `SudokuVersus.Accounts`)
3. Update `AGENTS.md` with schema-specific guidance
4. Proceed to Phase 2: Task planning
