package main

import "fmt"

func main() {
	// This will trigger go vet: Printf format %d has arg of wrong type string
	fmt.Printf("Number: %d\n", "not a number")

	// This will trigger go vet: assignment to unused variable
	x := 42

	// This will trigger go vet: unreachable code
	return
	fmt.Println("This will never execute")
}
