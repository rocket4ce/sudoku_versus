mod difficulty;
mod generator;
mod solver;

#[derive(Debug, rustler::NifStruct)]
#[module = "SudokuVersus.Puzzles.GeneratorResult"]
pub struct PuzzleResult {
    pub grid: Vec<i32>,
    pub solution: Vec<i32>,
}

/// Main NIF function to generate a Sudoku puzzle
/// Uses DirtyCpu scheduler for computationally intensive work
#[rustler::nif(schedule = "DirtyCpu", name = "generate_nif")]
pub fn generate(size: i32, difficulty: i32, seed: u64) -> Result<PuzzleResult, String> {
    // Validate inputs
    if !is_valid_size(size) {
        return Err(format!("Invalid size: {}. Must be one of: 9, 16, 25, 36, 49, 100", size));
    }

    if !difficulty::is_valid_difficulty(difficulty) {
        return Err(format!("Invalid difficulty: {}. Must be 0-3 (easy, medium, hard, expert)", difficulty));
    }

    let size_usize = size as usize;

    // Generate complete solution
    let solution = generator::generate_solution(size_usize, seed);

    // Validate solution
    if !solver::is_valid_solution(&solution, size_usize) {
        return Err("Generated invalid solution".to_string());
    }

    // Create puzzle by removing cells
    let grid = generator::create_puzzle(solution.clone(), difficulty, size_usize, seed + 1);

    Ok(PuzzleResult { grid, solution })
}

fn is_valid_size(size: i32) -> bool {
    matches!(size, 9 | 16 | 25 | 36 | 49 | 100)
}

rustler::init!("Elixir.SudokuVersus.Puzzles.Generator");

#[cfg(test)]
mod tests {
    use super::*;
    use crate::difficulty::{calculate_clue_count, calculate_metrics, is_valid_difficulty, difficulty_name};
    use crate::generator::{generate_solution, create_puzzle, count_solutions};
    use crate::solver::{is_valid_solution, check_constraints};

    // ============================================================================
    // NIF Interface Tests (testing logic, NIF tested via Elixir)
    // ============================================================================

    #[test]
    fn test_is_valid_size_function() {
        assert!(super::is_valid_size(9));
        assert!(super::is_valid_size(100));
        assert!(!super::is_valid_size(10));
        assert!(!super::is_valid_size(8));
    }

    #[test]
    fn test_full_puzzle_generation_9x9() {
        // Test the complete flow without NIF wrapper
        let size = 9;
        let difficulty = 0;
        let seed = 12345u64;

        let solution = generate_solution(size, seed);
        assert_eq!(solution.len(), 81);
        assert!(is_valid_solution(&solution, size));

        let grid = create_puzzle(solution.clone(), difficulty, size, seed + 1);
        assert_eq!(grid.len(), 81);

        // Verify grid values are from solution
        for i in 0..81 {
            if grid[i] != 0 {
                assert_eq!(grid[i], solution[i]);
            }
        }
    }

    #[test]
    fn test_full_puzzle_generation_16x16() {
        let size = 16;
        let solution = generate_solution(size, 54321);
        assert_eq!(solution.len(), 256);
        assert!(is_valid_solution(&solution, size));
    }

    // ============================================================================
    // Difficulty Module Tests
    // ============================================================================

    #[test]
    fn test_is_valid_difficulty() {
        assert!(is_valid_difficulty(0));
        assert!(is_valid_difficulty(3));
        assert!(!is_valid_difficulty(-1));
        assert!(!is_valid_difficulty(4));
    }

    #[test]
    fn test_difficulty_name() {
        assert_eq!(difficulty_name(0), "easy");
        assert_eq!(difficulty_name(3), "expert");
    }

    #[test]
    fn test_calculate_clue_count() {
        let easy = calculate_clue_count(9, 0);
        let expert = calculate_clue_count(9, 3);
        assert!(easy > expert, "Easy should have more clues");
    }

    #[test]
    fn test_calculate_metrics() {
        let m = calculate_metrics(9, 1);
        assert!(m.clue_percentage >= 0.35 && m.clue_percentage <= 0.45);
    }

    // ============================================================================
    // Generator Module Tests
    // ============================================================================

    #[test]
    fn test_generate_solution_9x9() {
        let sol = generate_solution(9, 12345);
        assert_eq!(sol.len(), 81);
        assert!(is_valid_solution(&sol, 9));
    }

    #[test]
    fn test_generate_solution_deterministic() {
        let s1 = generate_solution(9, 99999);
        let s2 = generate_solution(9, 99999);
        assert_eq!(s1, s2);
    }

    #[test]
    fn test_create_puzzle_has_empty_cells() {
        let sol = generate_solution(9, 12345);
        let puzzle = create_puzzle(sol, 1, 9, 67890);
        let zeros = puzzle.iter().filter(|&&x| x == 0).count();
        assert!(zeros > 0);
        assert!(zeros < 81);
    }

    #[test]
    fn test_create_puzzle_difficulty_affects_clues() {
        let sol = generate_solution(9, 12345);
        let easy = create_puzzle(sol.clone(), 0, 9, 11111);
        let expert = create_puzzle(sol, 3, 9, 22222);
        let easy_clues = easy.iter().filter(|&&x| x != 0).count();
        let expert_clues = expert.iter().filter(|&&x| x != 0).count();
        assert!(easy_clues > expert_clues);
    }

    #[test]
    fn test_count_solutions_complete() {
        let sol = generate_solution(9, 12345);
        assert_eq!(count_solutions(&sol, 9), 1);
    }

    // ============================================================================
    // Solver Module Tests
    // ============================================================================

    #[test]
    fn test_is_valid_solution_valid_4x4() {
        let valid = vec![1,2,3,4, 3,4,1,2, 2,1,4,3, 4,3,2,1];
        assert!(is_valid_solution(&valid, 4));
    }

    #[test]
    fn test_is_valid_solution_invalid_length() {
        assert!(!is_valid_solution(&vec![1,2,3], 4));
    }

    #[test]
    fn test_is_valid_solution_duplicate_row() {
        let dup = vec![1,1,3,4, 3,4,1,2, 2,3,4,1, 4,2,1,3];
        assert!(!is_valid_solution(&dup, 4));
    }

    #[test]
    fn test_check_constraints_valid() {
        let grid = vec![1,2,3,4, 3,4,0,2, 2,1,4,3, 4,3,2,1];
        assert!(check_constraints(&grid, 4, 1, 2, 1));
    }

    #[test]
    fn test_check_constraints_invalid_value() {
        let grid = vec![0; 16];
        assert!(!check_constraints(&grid, 4, 0, 0, 0));
        assert!(!check_constraints(&grid, 4, 0, 0, 5));
    }

    #[test]
    fn test_check_constraints_row_conflict() {
        let grid = vec![1,2,3,4, 3,4,0,2, 2,1,4,3, 4,3,2,1];
        assert!(!check_constraints(&grid, 4, 1, 2, 3)); // 3 already in row
    }
}
