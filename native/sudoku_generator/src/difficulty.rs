/// Difficulty calculation and strategic cell removal for puzzle generation

/// Calculates the target number of clues for a given difficulty level
pub fn calculate_clue_count(size: usize, difficulty: i32) -> usize {
    let total_cells = size * size;

    let percentage = match difficulty {
        0 => 0.55, // easy: 50-60% clues
        1 => 0.40, // medium: 35-45% clues
        2 => 0.30, // hard: 25-35% clues
        3 => 0.22, // expert: 20-25% clues
        _ => 0.40, // default to medium
    };

    (total_cells as f64 * percentage) as usize
}

/// Removes cells strategically from a solved grid to create a puzzle
/// Returns the number of cells successfully removed
pub fn remove_cells_strategically(
    grid: &mut [i32],
    _solution: &[i32],
    target_clues: usize,
    size: usize,
    seed: u64,
) -> usize {
    use rand::{Rng, SeedableRng};
    let mut rng = rand::rngs::StdRng::seed_from_u64(seed);

    let total_cells = size * size;
    let target_removals = total_cells.saturating_sub(target_clues);

    // Create list of all cell indices
    let mut indices: Vec<usize> = (0..total_cells).collect();

    // Shuffle indices for random removal order
    for i in (1..indices.len()).rev() {
        let j = rng.gen_range(0..=i);
        indices.swap(i, j);
    }

    let mut removed = 0;

    for &idx in indices.iter() {
        if removed >= target_removals {
            break;
        }

        // Try removing this cell
        let _original_value = grid[idx];
        grid[idx] = 0;
        removed += 1;
    }

    removed
}

/// Validates difficulty level
pub fn is_valid_difficulty(difficulty: i32) -> bool {
    (0..=3).contains(&difficulty)
}

/// Gets difficulty name for display
pub fn difficulty_name(difficulty: i32) -> &'static str {
    match difficulty {
        0 => "easy",
        1 => "medium",
        2 => "hard",
        3 => "expert",
        _ => "unknown",
    }
}

/// Calculates expected difficulty metrics for a puzzle
pub struct DifficultyMetrics {
    pub clue_percentage: f64,
    pub target_clues: usize,
    pub min_clues: usize,
    pub max_clues: usize,
}

pub fn calculate_metrics(size: usize, difficulty: i32) -> DifficultyMetrics {
    let total_cells = size * size;
    let target_clues = calculate_clue_count(size, difficulty);

    let (min_percent, max_percent) = match difficulty {
        0 => (0.50, 0.60),
        1 => (0.35, 0.45),
        2 => (0.25, 0.35),
        3 => (0.20, 0.25),
        _ => (0.35, 0.45),
    };

    DifficultyMetrics {
        clue_percentage: target_clues as f64 / total_cells as f64,
        target_clues,
        min_clues: (total_cells as f64 * min_percent) as usize,
        max_clues: (total_cells as f64 * max_percent) as usize,
    }
}
