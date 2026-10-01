package wiki

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// MatchImportedPDF verifies IDs from native import notifications against the
// exact cached PDF bytes and selected parent. Never searches by title or time.
func MatchImportedPDF(library, source, parent string, candidates []string) (string, error) {
	if len(candidates) > 64 {
		return "", fmt.Errorf("too many concurrent import notifications")
	}
	srcInfo, err := os.Stat(source)
	if err != nil {
		return "", err
	}
	digest := func(path string) ([32]byte, error) {
		var sum [32]byte
		f, err := os.Open(path)
		if err != nil {
			return sum, err
		}
		defer f.Close()
		h := sha256.New()
		if _, err = io.Copy(h, f); err != nil {
			return sum, err
		}
		copy(sum[:], h.Sum(nil))
		return sum, nil
	}
	sourceHash, err := digest(source)
	if err != nil {
		return "", err
	}
	found := ""
	seen := map[string]bool{}
	for _, id := range candidates {
		if !folderID.MatchString(id) || seen[id] {
			continue
		}
		seen[id] = true
		var meta struct {
			Type    string `json:"type"`
			Parent  string `json:"parent"`
			Deleted bool   `json:"deleted"`
		}
		b, e := os.ReadFile(filepath.Join(library, id+".metadata"))
		if e != nil || json.Unmarshal(b, &meta) != nil || meta.Type != "DocumentType" || meta.Deleted || meta.Parent != parent {
			continue
		}
		pdf := filepath.Join(library, id+".pdf")
		info, e := os.Lstat(pdf)
		if e != nil || !info.Mode().IsRegular() || info.Size() != srcInfo.Size() {
			continue
		}
		hash, e := digest(pdf)
		if e != nil || hash != sourceHash {
			continue
		}
		if found != "" {
			return "", fmt.Errorf("more than one imported PDF matches; refusing to choose the wrong document")
		}
		found = id
	}
	return found, nil
}
