# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     SudokuVersus.Repo.insert!(%SudokuVersus.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias SudokuVersus.Repo
alias SudokuVersus.{Accounts, Games}
alias SudokuVersus.Accounts.User
alias SudokuVersus.Games.{Puzzle, GameRoom}

IO.puts("🌱 Starting seeds...")

# Clear existing data (optional - remove this in production)
IO.puts("Clearing existing data...")
Repo.delete_all(Games.Move)
Repo.delete_all(Games.PlayerSession)
Repo.delete_all(GameRoom)
Repo.delete_all(Puzzle)
Repo.delete_all(User)

# Create sample users
IO.puts("Creating sample users...")

users =
  Enum.map(1..10, fn i ->
    {:ok, user} =
      Accounts.create_guest_user(%{
        username: "player#{i}"
      })

    IO.puts("  ✓ Created user: #{user.username}")
    user
  end)

# Create puzzles for different difficulties and grid sizes
IO.puts("\nGenerating puzzles...")

puzzles =
  for difficulty <- [:easy, :medium, :hard, :expert],
      grid_size <- [9, 16],
      i <- 1..3 do
    IO.puts("  Generating #{difficulty} #{grid_size}x#{grid_size} puzzle #{i}...")
    {:ok, puzzle} = Games.create_puzzle(difficulty, grid_size)
    IO.puts("    ✓ Created #{difficulty} #{grid_size}x#{grid_size} puzzle (#{puzzle.clues_count} clues)")
    puzzle
  end

IO.puts("\nTotal puzzles created: #{length(puzzles)}")

# Create sample game rooms
IO.puts("\nCreating sample game rooms...")

room_names = [
  "Beginner's Paradise 🎮",
  "Speed Runners ⚡",
  "Expert Challenge 🔥",
  "Casual Friday 😎",
  "MMO Madness 16x16 🎯",
  "Classic 9x9 Battle ⚔️",
  "Weekend Warriors 🏆",
  "Late Night Session 🌙"
]

rooms =
  Enum.zip([1..8, room_names])
  |> Enum.map(fn {i, name} ->
    creator = Enum.random(users)
    puzzle = Enum.random(puzzles)

    {:ok, room} =
      Games.create_game_room(%{
        name: name,
        creator_id: creator.id,
        puzzle_id: puzzle.id,
        visibility: if(rem(i, 3) == 0, do: :private, else: :public)
      })

    IO.puts("  ✓ Created room: #{room.name} (#{puzzle.grid_size}x#{puzzle.grid_size}, #{puzzle.difficulty})")
    room
  end)

IO.puts("\n✅ Seeds completed successfully!")
IO.puts("Summary:")
IO.puts("  • #{length(users)} users created")
IO.puts("  • #{length(puzzles)} puzzles generated")
IO.puts("  • #{length(rooms)} game rooms created")
IO.puts("\nYou can now start the server with: mix phx.server")
