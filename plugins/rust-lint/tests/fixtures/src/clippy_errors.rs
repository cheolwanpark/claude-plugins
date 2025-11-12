// File with clippy warnings for testing

/// Function with unnecessary cast (clippy warning)
pub fn unnecessary_cast_example(x: i32) -> i32 {
    x as i32  // This will trigger clippy::unnecessary_cast
}

/// Function with single match that should be if let (clippy warning)
pub fn single_match_example(opt: Option<i32>) -> i32 {
    match opt {
        Some(n) => n,
        _ => 0,
    }  // This will trigger clippy::single_match
}

/// Function with needless return (clippy warning)
pub fn needless_return_example(x: i32) -> i32 {
    return x + 1;  // This will trigger clippy::needless_return
}

/// Function with multiple clippy issues
pub fn multiple_issues(value: Option<i32>) -> i32 {
    let result = match value {
        Some(v) => v as i32,  // unnecessary_cast
        None => 0,
    };
    return result;  // needless_return
}
