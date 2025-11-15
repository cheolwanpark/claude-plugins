package main

import (
	"fmt"
)

func main() {
	message := "Hello, World!"
	fmt.Println(message)
	fmt.Println(helper())
}

func helper() string {
	return "I am a helper"
}
