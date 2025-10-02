# Bug Fix: Grid Not Updating on Correct Moves

## Problem Description

When players in the same game room submitted correct moves, the following issues occurred:
1. The move disappeared from the UI for the submitting player
2. The move did not appear in the other player's browser
3. The Sudoku grid remained static and never reflected correct moves

## Root Cause Analysis

The issue was in `lib/sudoku_versus_web/live/game_live/show.ex`:

1. **Static Grid**: The `@grid` assign was set once during `mount/3` from `room.puzzle.grid` and never updated
2. **Missing Grid Updates**: When a correct move was submitted, the move was recorded in the database and broadcast via PubSub, but the grid assign was not updated
3. **Incomplete Broadcast**: Only the move ID was broadcast, making it difficult for other clients to update their grids efficiently
4. **No Grid Update on Receive**: When receiving move notifications from other players, the grid was not updated

## Solution Implemented

### 1. Added Grid Update Helper Function

Created a helper function to immutably update the grid structure:

```elixir
defp update_grid(grid, row, col, value) do
  # Update the grid immutably at the given row and column
  List.update_at(grid, row, fn row_list ->
    List.update_at(row_list, col, fn _ -> value end)
  end)
end
```

### 2. Enhanced PubSub Broadcast

Changed the broadcast to include full move details instead of just the ID:

```elixir
Phoenix.PubSub.broadcast(
  SudokuVersus.PubSub,
  "game_room:#{socket.assigns.room_id}",
  {:new_move, %{
    id: move.id,
    row: move.row,
    col: move.col,
    value: move.value,
    is_correct: move.is_correct
  }}
)
```

### 3. Update Grid Locally on Submit

When a player submits a correct move, update their grid immediately:

```elixir
socket =
  if move.is_correct do
    socket
    |> assign(:grid, update_grid(socket.assigns.grid, move.row, move.col, move.value))
    |> put_flash(:info, "Correct! +#{move.points_earned} points")
  else
    apply_penalty(socket)
  end
```

### 4. Update Grid on Receiving Moves

When receiving moves from other players, update the grid:

```elixir
def handle_info({:new_move, move_data}, socket) do
  moves = Games.get_room_moves(socket.assigns.room_id, limit: 1)

  case moves do
    [move] when move.id == move_data.id ->
      socket =
        socket
        |> assign(:moves_count, socket.assigns.moves_count + 1)
        |> stream_insert(:moves, move, at: 0)

      # Update grid if move was correct
      socket =
        if move_data.is_correct do
          assign(socket, :grid, update_grid(socket.assigns.grid, move_data.row, move_data.col, move_data.value))
        else
          socket
        end

      {:noreply, socket}
    _ ->
      {:noreply, socket}
  end
end
```

### 5. Fixed Template Input

Added `name="value"` attribute to ensure the input value is properly captured:

```heex
<input
  type="number"
  name="value"
  min="1"
  max="9"
  phx-blur="submit_move"
  phx-value-row={row}
  phx-value-col={col}
  class="w-full h-full text-center bg-white focus:bg-blue-50 border-0 focus:ring-2 focus:ring-blue-500"
/>
```

## Files Modified

1. `lib/sudoku_versus_web/live/game_live/show.ex`
   - Updated `handle_event("submit_move", ...)` to update grid and broadcast full move details
   - Updated `handle_info({:new_move, ...})` to accept move data map and update grid
   - Added `update_grid/4` helper function

2. `lib/sudoku_versus_web/live/game_live/show.html.heex`
   - Added `name="value"` to grid input fields

3. `test/sudoku_versus_web/live/game_live/show_test.exs`
   - Updated broadcast assertion to match new map structure
   - Fixed `handle_info` test to send proper move data format

## Testing

All tests pass successfully:
```
mix test test/sudoku_versus_web/live/game_live/show_test.exs
Finished in 0.6 seconds
10 tests, 0 failures
```

## Expected Behavior After Fix

1. When a player submits a correct move:
   - The number appears immediately in their grid
   - The move appears in their move history
   - Their score updates

2. When another player in the same room submits a correct move:
   - The number appears in all connected players' grids
   - The move appears in all players' move history streams
   - Real-time synchronization across all clients

3. When a player submits an incorrect move:
   - The grid is NOT updated (only correct moves fill cells)
   - The player receives a penalty
   - Other players see the incorrect move in history but grid remains unchanged

## Implementation Notes

- Grid updates are only applied for correct moves (`is_correct: true`)
- The grid is stored as immutable Elixir lists, requiring proper update functions
- PubSub broadcasts include full move data to avoid unnecessary database queries
- The template renders grid cells based on `@grid` assign, which now updates reactively
- Incorrect moves do not update the grid (preserving game rules)
