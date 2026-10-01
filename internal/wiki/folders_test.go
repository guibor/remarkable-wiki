package wiki

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

const folderA = "11111111-1111-4111-8111-111111111111"
const folderB = "22222222-2222-4222-8222-222222222222"
const folderC = "33333333-3333-4333-8333-333333333333"

func writeFolder(t *testing.T, dir, id, name, parent string, deleted bool) {
	t.Helper()
	b, _ := json.Marshal(map[string]any{"type": "CollectionType", "visibleName": name, "parent": parent, "deleted": deleted})
	if err := os.WriteFile(filepath.Join(dir, id+".metadata"), b, 0600); err != nil {
		t.Fatal(err)
	}
}

func TestFoldersAndReadOnlyEnumeration(t *testing.T) {
	dir := t.TempDir()
	writeFolder(t, dir, folderA, "Reading", "", false)
	writeFolder(t, dir, folderB, "עברית", folderA, false)
	writeFolder(t, dir, folderC, "Reading", "", false)
	before, _ := os.ReadFile(filepath.Join(dir, folderA+".metadata"))
	folders, err := ListFolders(dir)
	if err != nil || len(folders) != 4 || folders[0] != RootDestination() {
		t.Fatal(folders, err)
	}
	f, err := ResolveDestination(dir, folderB)
	if err != nil || f.Name != "My files / Reading / עברית" {
		t.Fatal(f, err)
	}
	a, _ := ResolveDestination(dir, folderA)
	c, _ := ResolveDestination(dir, folderC)
	if a.Name == c.Name {
		t.Fatal("duplicate names ambiguous", a, c)
	}
	after, _ := os.ReadFile(filepath.Join(dir, folderA+".metadata"))
	if string(before) != string(after) {
		t.Fatal("library metadata changed")
	}
	if _, err := ResolveDestination(dir, "../../etc/passwd"); err == nil {
		t.Fatal("invalid ID accepted")
	}
}

func TestExcludeUnavailableFolderTrees(t *testing.T) {
	for _, parent := range []string{"trash", folderC, folderB} {
		t.Run(parent, func(t *testing.T) {
			dir := t.TempDir()
			writeFolder(t, dir, folderA, "Parent", parent, false)
			writeFolder(t, dir, folderB, "Child", folderA, false)
			folders, err := ListFolders(dir)
			if err != nil || len(folders) != 1 {
				t.Fatal(folders, err)
			}
			if _, err := ResolveDestination(dir, folderB); err == nil {
				t.Fatal("invalid descendant selected")
			}
		})
	}
	dir := t.TempDir()
	writeFolder(t, dir, folderA, "Deleted", "", true)
	writeFolder(t, dir, folderB, "Child", folderA, false)
	if f, err := ListFolders(dir); err != nil || len(f) != 1 {
		t.Fatal(f, err)
	}
}

func TestDestinationPersistenceRenameAndDeletion(t *testing.T) {
	dir, library := t.TempDir(), t.TempDir()
	s, _ := OpenStore(dir)
	if s.Destination != RootDestination() {
		t.Fatal(s.Destination)
	}
	writeFolder(t, library, folderA, "Reading", "", false)
	if err := s.SetDestination(library, folderA); err != nil {
		t.Fatal(err)
	}
	s, err := OpenStore(dir)
	if err != nil || s.Destination.ID != folderA {
		t.Fatal(s, err)
	}
	writeFolder(t, library, folderA, "Articles", "", false)
	f, err := ResolveDestination(library, s.Destination.ID)
	if err != nil || f.Name != "My files / Articles" {
		t.Fatal(f, err)
	}
	writeFolder(t, library, folderA, "Articles", "trash", false)
	if err := s.SetDestination(library, folderA); err == nil {
		t.Fatal("trashed destination accepted")
	}
	if s.Destination.ID != folderA {
		t.Fatal("failed save changed preference")
	}
	if err := s.SetDestination(library, ""); err != nil {
		t.Fatal(err)
	}
	s, err = OpenStore(dir)
	if err != nil || s.Destination != RootDestination() {
		t.Fatal(s, err)
	}
}

func TestLegacyStoreDestinationDefaults(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "state.json"), []byte(`{"language":"he","records":{}}`), 0600); err != nil {
		t.Fatal(err)
	}
	s, err := OpenStore(dir)
	if err != nil || s.Destination != RootDestination() || s.Language != "he" {
		t.Fatal(s, err)
	}
}
