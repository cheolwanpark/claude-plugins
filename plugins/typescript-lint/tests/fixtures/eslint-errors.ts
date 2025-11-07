// File with ESLint errors that should trigger blocking

// Error: unused variable
const unusedVariable = 'this will trigger no-unused-vars error'

// Error: console.log (no-console rule)
console.log('this will trigger no-console error')

function testFunction() {
  return 42
}

export { testFunction }
