package wiki

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// Destination refers to a native library folder, never a filesystem path.
type Destination struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

var folderID = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func RootDestination() Destination { return Destination{Name: "My files"} }

// ListFolders reads only library metadata. No notebook content or library writes.
// Folders in trash, below deleted/missing ancestors, or in cycles are excluded.
func ListFolders(dir string) ([]Destination, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("cannot read library folders: %w", err)
	}
	type metadata struct {
		Type    string `json:"type"`
		Name    string `json:"visibleName"`
		Parent  string `json:"parent"`
		Deleted bool   `json:"deleted"`
	}
	all := map[string]metadata{}
	for _, entry := range entries {
		id := strings.TrimSuffix(entry.Name(), ".metadata")
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !strings.HasSuffix(entry.Name(), ".metadata") || !folderID.MatchString(id) {
			continue
		}
		info, err := entry.Info()
		if err != nil || info.Size() > 65536 {
			continue
		}
		data, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err != nil {
			continue
		}
		var m metadata
		if json.Unmarshal(data, &m) == nil && m.Type == "CollectionType" && !m.Deleted && m.Name != "" {
			all[id] = m
		}
	}
	folders := []Destination{RootDestination()}
	for id := range all {
		parts := []string{}
		seen := map[string]bool{}
		current := id
		valid := true
		for current != "" {
			m, ok := all[current]
			if !ok || seen[current] || len(parts) >= 64 {
				valid = false
				break
			}
			seen[current] = true
			parts = append(parts, m.Name)
			current = m.Parent
		}
		if !valid {
			continue
		}
		for i, j := 0, len(parts)-1; i < j; i, j = i+1, j-1 {
			parts[i], parts[j] = parts[j], parts[i]
		}
		folders = append(folders, Destination{ID: id, Name: "My files / " + strings.Join(parts, " / ")})
	}
	// Identical user folder names must remain distinguishable in the picker.
	counts := map[string]int{}
	for _, f := range folders {
		counts[f.Name]++
	}
	for i := range folders {
		if counts[folders[i].Name] > 1 {
			folders[i].Name += " · " + folders[i].ID[:8]
		}
	}
	sort.Slice(folders[1:], func(i, j int) bool {
		a, b := folders[i+1], folders[j+1]
		if a.Name == b.Name {
			return a.ID < b.ID
		}
		return strings.ToLower(a.Name) < strings.ToLower(b.Name)
	})
	return folders, nil
}

func ResolveDestination(dir, id string) (Destination, error) {
	if id == "" {
		return RootDestination(), nil
	}
	if !folderID.MatchString(id) {
		return Destination{}, fmt.Errorf("invalid destination folder")
	}
	folders, err := ListFolders(dir)
	if err != nil {
		return Destination{}, err
	}
	for _, f := range folders {
		if f.ID == id {
			return f, nil
		}
	}
	return Destination{}, fmt.Errorf("the saved folder is no longer available; choose a Save to folder again")
}

func (s *Store) SetDestination(dir, id string) error {
	destination, err := ResolveDestination(dir, id)
	if err != nil {
		return err
	}
	previous := s.Destination
	s.Destination = destination
	if err := s.Save(); err != nil {
		s.Destination = previous
		return err
	}
	return nil
}
