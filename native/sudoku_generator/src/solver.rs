/// Fast Sudoku solver with constraint checking and solution validation
use std::collections::HashSet;

/// Validates if a complete grid is a valid Sudoku solution
pub fn is_valid_solution(grid: &[i32], size: usize) -> bool {
    if grid.len() != size * size {
        return false;
    }

    // Check all rows
    for row in 0..size {
        if !is_valid_row(grid, size, row) {
            return false;
        }
    }

    // Check all columns
    for col in 0..size {
        if !is_valid_col(grid, size, col) {
            return false;
        }
    }

    // Check all sub-grids
    let sub_grid_size = (size as f64).sqrt() as usize;
    for box_row in (0..size).step_by(sub_grid_size) {
        for box_col in (0..size).step_by(sub_grid_size) {
            if !is_valid_box(grid, size, box_row, box_col, sub_grid_size) {
                return false;
            }
        }
    }

    true
}

/// Checks if placing a value at (row, col) violates Sudoku constraints
pub fn check_constraints(grid: &[i32], size: usize, row: usize, col: usize, value: i32) -> bool {
    if value < 1 || value > size as i32 {
        return false;
    }

    // Check row constraint
    for c in 0..size {
        if c != col && grid[row * size + c] == value {
            return false;
        }
    }

    // Check column constraint
    for r in 0..size {
        if r != row && grid[r * size + col] == value {
            return false;
        }
    }

    // Check sub-grid constraint
    let sub_grid_size = (size as f64).sqrt() as usize;
    let box_row = (row / sub_grid_size) * sub_grid_size;
    let box_col = (col / sub_grid_size) * sub_grid_size;

    for r in box_row..(box_row + sub_grid_size) {
        for c in box_col..(box_col + sub_grid_size) {
            if (r != row || c != col) && grid[r * size + c] == value {
                return false;
            }
        }
    }

    true
}

// Private helper functions

fn is_valid_row(grid: &[i32], size: usize, row: usize) -> bool {
    let mut seen = HashSet::new();
    for col in 0..size {
        let value = grid[row * size + col];
        if value < 1 || value > size as i32 || !seen.insert(value) {
            return false;
        }
    }
    seen.len() == size
}

fn is_valid_col(grid: &[i32], size: usize, col: usize) -> bool {
    let mut seen = HashSet::new();
    for row in 0..size {
        let value = grid[row * size + col];
        if value < 1 || value > size as i32 || !seen.insert(value) {
            return false;
        }
    }
    seen.len() == size
}

fn is_valid_box(grid: &[i32], size: usize, start_row: usize, start_col: usize, box_size: usize) -> bool {
    let mut seen = HashSet::new();
    for row in start_row..(start_row + box_size) {
        for col in start_col..(start_col + box_size) {
            let value = grid[row * size + col];
            if value < 1 || value > size as i32 || !seen.insert(value) {
                return false;
            }
        }
    }
    seen.len() == box_size * box_size
}
