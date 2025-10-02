# Quickstart: MMO Sudoku Multiplayer

**Feature**: 002-mmo-sudoku-multiplayer
**Date**: 2025-01-10

## Purpose
Guide for developers to set up, run, and test the MMO Sudoku multiplayer feature locally.

---

## Prerequisites

- **Elixir**: 1.18.1 or higher
- **Erlang/OTP**: 27.0 or higher
- **PostgreSQL**: 15.0 or higher
- **Node.js**: 18.0 or higher (for assets)
- **Git**: Version control

---

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd sudoku_versus
```

### 2. Install Dependencies

```bash
# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies for assets
cd assets && npm install && cd ..

# Install assets build tools
mix assets.setup
```

### 3. Configure Database

```bash
# Create config/dev.secret.exs (gitignored)
cat > config/dev.secret.exs <<EOF
import Config

config :sudoku_versus, SudokuVersus.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sudoku_versus_dev",
  port: 5432
EOF

# Create database
mix ecto.create

# Run migrations
mix ecto.migrate
```

### 4. Seed Database (Optional)

```bash
# Generate sample puzzles and rooms
mix run priv/repo/seeds.exs
```

---

## OAuth Configuration (Optional)

To test OAuth login flows, configure provider credentials:

### Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable "Google+ API"
4. Create OAuth 2.0 credentials:
   - **Application type**: Web application
   - **Authorized redirect URIs**: `http://localhost:4000/auth/google/callback`
5. Copy Client ID and Client Secret

### GitHub OAuth

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Create a new OAuth App:
   - **Homepage URL**: `http://localhost:4000`
   - **Authorization callback URL**: `http://localhost:4000/auth/github/callback`
3. Copy Client ID and Client Secret

### Set Environment Variables

```bash
# Add to .env (gitignored) or export directly
export GOOGLE_CLIENT_ID="your-google-client-id"
export GOOGLE_CLIENT_SECRET="your-google-client-secret"
export GITHUB_CLIENT_ID="your-github-client-id"
export GITHUB_CLIENT_SECRET="your-github-client-secret"
export APP_URL="http://localhost:4000"

# Load environment variables
source .env
```

**Note**: Guest and registered user login work without OAuth configuration. OAuth is optional for local development.

---

## Running the Application

### Start Phoenix Server

```bash
# Start server with IEx console
iex -S mix phx.server

# Or start server without console
mix phx.server
```

Server runs at: **http://localhost:4000**

### Verify Setup

1. Visit `http://localhost:4000`
2. You should see the landing page
3. Click "Play as Guest" or "Sign Up"
4. Create or join a game room
5. Submit moves and verify real-time updates

---

## Development Workflow

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/sudoku_versus/games_test.exs

# Run tests with coverage
mix test --cover

# Run tests in watch mode (requires mix_test_watch)
mix test.watch
```

### Code Quality Checks

```bash
# Run precommit checks (format, compile, test)
mix precommit

# Format code
mix format

# Check for compiler warnings
mix compile --warnings-as-errors

# Run static analysis (if Credo installed)
mix credo --strict
```

### Database Operations

```bash
# Create new migration
mix ecto.gen.migration create_table_name

# Run pending migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Check migration status
mix ecto.migrations
```

### Asset Development

```bash
# Watch and rebuild assets automatically (runs in separate terminal)
cd assets
npm run watch

# Build assets for production
npm run deploy
```

---

## Testing the Feature

### Test Scenarios

#### 1. Guest User Flow
```bash
# In browser:
1. Visit http://localhost:4000
2. Click "Play as Guest"
3. Enter username (e.g., "TestPlayer123")
4. Click "Create Room"
5. Enter room name (e.g., "Test Game 🎮")
6. Select difficulty: Easy
7. Click "Create"
8. Verify game board renders with puzzle
9. Submit a correct move (click cell, enter number)
10. Verify move appears in move history
11. Verify score updates
```

#### 2. Registered User Flow
```bash
# In browser:
1. Visit http://localhost:4000
2. Click "Sign Up"
3. Enter username, email, password
4. Click "Register"
5. Verify redirect to game lobby
6. Create or join room
7. Play game, verify stats saved
```

#### 3. OAuth Flow (if configured)
```bash
# In browser:
1. Visit http://localhost:4000
2. Click "Sign in with Google" or "Sign in with GitHub"
3. Authorize application on provider site
4. Verify redirect back to app
5. Verify user created with OAuth provider info
```

#### 4. Multiplayer Real-Time Flow
```bash
# Open two browser windows/tabs:

Window 1:
1. Login as User A
2. Create room "Multiplayer Test"
3. Submit move at row 0, col 2, value 5

Window 2:
1. Login as User B (different user)
2. Join room "Multiplayer Test"
3. Verify User A's move appears in real-time
4. Verify User A appears in player list
5. Submit move at row 1, col 3, value 8

Window 1:
6. Verify User B's move appears in real-time
7. Verify player count shows 2
```

#### 5. Presence Tracking
```bash
# Open two browser windows:

Window 1:
1. Join room "Presence Test"
2. Verify player count = 1

Window 2:
1. Join same room "Presence Test"
2. Verify player count = 2 (in both windows)

Window 1:
3. Close tab

Window 2:
4. Verify player count = 1 (User A disconnected)
```

---

## IEx Console Helpers

```elixir
# Start IEx with application
iex -S mix

# Generate a new puzzle
alias SudokuVersus.Games
puzzle = Games.generate_puzzle(:easy)

# Create a game room
user = SudokuVersus.Repo.get_by(SudokuVersus.Accounts.User, username: "testuser")
room = Games.create_game_room(%{
  name: "Console Test Room",
  creator_id: user.id,
  puzzle_id: puzzle.id
})

# List active rooms
Games.list_active_rooms()

# Get room with player count
Games.get_game_room_with_stats(room.id)

# Validate a move
Games.validate_move(puzzle, 0, 0, 5)

# Refresh leaderboard manually
Games.refresh_leaderboard()

# Query leaderboard
Games.get_leaderboard(:all, limit: 10)
```

---

## Debugging Tips

### Phoenix LiveView Debugging

```elixir
# In LiveView module, add debug logging
require Logger

def handle_event("submit_move", params, socket) do
  Logger.debug("Received move: #{inspect(params)}")
  Logger.debug("Current assigns: #{inspect(socket.assigns)}")
  # ...
end

# Or use IEx.pry for breakpoints
require IEx

def handle_event("submit_move", params, socket) do
  IEx.pry()  # Execution pauses here in IEx console
  # ...
end
```

### PubSub Message Tracing

```elixir
# Subscribe to all game room topics for debugging
Phoenix.PubSub.subscribe(SudokuVersus.PubSub, "game_room:*")

# In IEx, listen for messages
flush()  # Shows all messages received by shell process
```

### Database Query Logging

```elixir
# Enable SQL logging in config/dev.exs (default: enabled)
config :sudoku_versus, SudokuVersus.Repo,
  log: :debug  # Shows all SQL queries in console
```

### Performance Profiling

```elixir
# Profile a function
:fprof.trace([:start])
Games.generate_puzzle(:hard)
:fprof.trace([:stop])
:fprof.profile()
:fprof.analyse()

# Or use :eprof
:eprof.start()
:eprof.profile([], fn -> Games.generate_puzzle(:hard) end)
:eprof.analyze()
```

---

## Common Issues

### Issue: Database Connection Error

```
** (DBConnection.ConnectionError) connection not available
```

**Solution**:
1. Verify PostgreSQL is running: `pg_ctl status` or `brew services list`
2. Check credentials in `config/dev.secret.exs`
3. Recreate database: `mix ecto.drop && mix ecto.create && mix ecto.migrate`

### Issue: OAuth Redirect Mismatch

```
redirect_uri_mismatch error
```

**Solution**:
1. Verify redirect URI in provider console matches exactly: `http://localhost:4000/auth/google/callback`
2. Check `APP_URL` environment variable is set correctly
3. Restart Phoenix server after changing environment variables

### Issue: Assets Not Loading

```
Cannot find module 'app.js'
```

**Solution**:
```bash
cd assets
rm -rf node_modules
npm install
npm run deploy
cd ..
mix phx.server
```

### Issue: Port Already in Use

```
** (RuntimeError) could not start Phoenix.Endpoint because port 4000 is already in use
```

**Solution**:
```bash
# Find process using port 4000
lsof -i :4000

# Kill process
kill -9 <PID>

# Or use different port
PORT=4001 mix phx.server
```

---

## Project Structure

```
lib/
├── sudoku_versus/              # Core business logic (contexts)
│   ├── accounts/               # User management, auth
│   │   ├── user.ex            # User schema
│   │   └── oauth.ex           # OAuth integration
│   ├── games/                  # Game logic
│   │   ├── game_room.ex       # Room schema
│   │   ├── puzzle.ex          # Puzzle schema
│   │   ├── player_session.ex  # Session schema
│   │   ├── move.ex            # Move schema
│   │   ├── score_record.ex    # Score schema
│   │   ├── puzzle_generator.ex # Puzzle generation
│   │   └── scorer.ex          # Scoring logic
│   ├── accounts.ex            # Accounts context
│   └── games.ex               # Games context
├── sudoku_versus_web/          # Web layer (controllers, LiveViews)
│   ├── components/            # Reusable components
│   ├── controllers/           # REST controllers (auth)
│   │   └── auth_controller.ex
│   ├── live/                  # LiveView modules
│   │   ├── game_live/
│   │   │   ├── index.ex      # Room list
│   │   │   ├── show.ex       # Game room
│   │   │   └── components.ex # Game components
│   │   └── auth_live/
│   │       ├── login.ex
│   │       └── register.ex
│   ├── presence.ex            # Phoenix.Presence
│   └── router.ex              # Routes
└── sudoku_versus.ex           # Application entry

test/
├── sudoku_versus/             # Context tests
│   ├── accounts_test.exs
│   └── games_test.exs
├── sudoku_versus_web/         # Web layer tests
│   ├── controllers/
│   │   └── auth_controller_test.exs
│   └── live/
│       └── game_live_test.exs
└── support/                   # Test helpers
    ├── fixtures.ex
    └── conn_case.ex

priv/
├── repo/
│   ├── migrations/            # Database migrations
│   └── seeds.exs              # Seed data
└── static/                    # Static assets

specs/
└── 002-mmo-sudoku-multiplayer/
    ├── spec.md                # Feature specification
    ├── plan.md                # Implementation plan
    ├── research.md            # Technical research
    ├── data-model.md          # Database design
    ├── contracts/             # API contracts
    └── quickstart.md          # This file
```

---

## Next Steps

1. Review `spec.md` for complete feature requirements
2. Review `data-model.md` for database schema details
3. Review `contracts/rest-api.md` for OAuth API contracts
4. Run `mix test` to ensure all tests pass
5. Start implementing tasks from `tasks.md` (generated via `/tasks` command)

---

## Useful Commands Reference

```bash
# Development
mix phx.server              # Start server
iex -S mix phx.server       # Start with IEx console
mix test                    # Run tests
mix test.watch              # Run tests in watch mode
mix format                  # Format code
mix precommit               # Run all quality checks

# Database
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.rollback           # Rollback migration
mix ecto.reset              # Reset database
mix ecto.gen.migration <name>  # Generate migration

# Code Generation
mix phx.gen.context <context> <schema> <fields>  # Generate context
mix phx.gen.live <context> <schema> <fields>     # Generate LiveView
mix phx.gen.schema <schema> <fields>             # Generate schema only

# Production
mix assets.deploy           # Build assets for production
MIX_ENV=prod mix release    # Build production release
```

---

## Support

For questions or issues:
1. Check this quickstart guide
2. Review feature specification in `spec.md`
3. Check `AGENTS.md` for project guidelines
4. Open an issue on the project repository

---

**Happy coding! 🎮🧩**
