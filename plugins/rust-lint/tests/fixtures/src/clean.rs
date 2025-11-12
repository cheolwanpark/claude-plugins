// Clean Rust file with no formatting or clippy issues

/// Adds two numbers together
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

/// Multiplies two numbers
pub fn multiply(x: i32, y: i32) -> i32 {
    x * y
}

/// Checks if a number is even
pub fn is_even(n: i32) -> bool {
    n % 2 == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
        assert_eq!(add(-1, 1), 0);
    }

    #[test]
    fn test_multiply() {
        assert_eq!(multiply(3, 4), 12);
        assert_eq!(multiply(0, 5), 0);
    }

    #[test]
    fn test_is_even() {
        assert!(is_even(2));
        assert!(is_even(0));
        assert!(!is_even(1));
        assert!(!is_even(-3));
    }
}
