/*
		DO NOT MAKE CHANGES WITHOUT TESTING.
	    YOU WILL REGRET IT AGAIN.
*/
package main

/*
#include <stdlib.h>
*/
import "C"
import "unsafe"
import (
	"encoding/json"
	"fmt"
	"gopkg.in/yaml.v2"
	"os"
	"strings"
)

type FrontMatter struct {
	Title   string   `yaml:"title"`
	Publish bool     `yaml:"publish"`
	Tags    []string `yaml:"tags"`
	// Add other fields as needed
}

//export ProcessFrontmatter
func ProcessFrontmatter(filePath *C.char) *C.char {
	a := C.GoString(filePath)

	data, err := os.ReadFile(a)
	if err != nil {
		fmt.Println("Error reading file:", err)
		return nil
	}
	frontMatterStart := 0
	frontMatterEnd := 0
	lines := strings.Split(string(data), "\n")
	for i, line := range lines {
		line = strings.TrimSpace(line)
		if i == 0 && line == "---" {
			fmt.Println("frontmatter detected")
			frontMatterStart = i + 1
		} else if frontMatterStart > 0 && line == "---" {
			frontMatterEnd = i
			break
		}
	}

	if frontMatterStart == 0 || frontMatterEnd == 0 {
		fmt.Println("No front matter found.")
		return nil
	}

	frontMatterLines := lines[frontMatterStart:frontMatterEnd]
	frontMatterString := strings.Join(frontMatterLines, "\n")

	// 4. Parse YAML (or your chosen format)
	var fm FrontMatter
	err = yaml.Unmarshal([]byte(frontMatterString), &fm)
	if err != nil {
		fmt.Println("Error parsing YAML:", err)
		return nil // Or return an error indicator
	}

	// // 5. Marshal the frontmatter back into a yaml string.
	processedFrontMatter, err := json.Marshal(&fm)
	if err != nil {
		fmt.Println("Error marshalling frontmatter back to YAML", err)
		return nil
	}

	cString := C.CString((string(processedFrontMatter)))
	defer C.free(unsafe.Pointer(cString))
	// defer C.free(unsafe.Pointer(filePath)) managed by the caller?
	return cString
}

func main() {}
