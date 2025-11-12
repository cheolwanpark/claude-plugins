// Test fixtures library for rust-lint plugin testing

pub mod clean;
pub mod clippy_errors;
pub mod fmt_errors;

// Re-export for convenience
pub use clean::*;
pub use clippy_errors::*;
pub use fmt_errors::*;
