// File with ESLint warnings (not errors)

function testWarnings() {
  // Warning: prefer-const (should use const instead of let)
  let x = 1
  let y = 2

  return x + y
}

export { testWarnings }
