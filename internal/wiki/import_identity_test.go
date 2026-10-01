package wiki

import (
	"os"
	"path/filepath"
	"testing"
)

func TestImportedPDFIdentity(t *testing.T) {
	library, cache := t.TempDir(), t.TempDir()
	source := filepath.Join(cache, "article.pdf")
	put := func(path, data string) {
		t.Helper()
		if e := os.WriteFile(path, []byte(data), 0600); e != nil {
			t.Fatal(e)
		}
	}
	put(source, "%PDF-1.7 exact content\n%%EOF\n")
	put(filepath.Join(library, folderA+".metadata"), `{"type":"DocumentType","parent":"","visibleName":"Same title"}`)
	put(filepath.Join(library, folderA+".pdf"), "%PDF-1.7 wrong content\n%%EOF\n")
	put(filepath.Join(library, folderB+".metadata"), `{"type":"DocumentType","parent":"","visibleName":"Another title"}`)
	put(filepath.Join(library, folderB+".pdf"), "%PDF-1.7 exact content\n%%EOF\n")
	id, err := MatchImportedPDF(library, source, "", []string{folderA, folderB, "../escape", folderB})
	if err != nil || id != folderB {
		t.Fatal(id, err)
	}
	id, err = MatchImportedPDF(library, source, folderC, []string{folderB})
	if err != nil || id != "" {
		t.Fatal("wrong parent accepted", id, err)
	}
	put(filepath.Join(library, folderA+".pdf"), "%PDF-1.7 exact content\n%%EOF\n")
	if _, err := MatchImportedPDF(library, source, "", []string{folderA, folderB}); err == nil {
		t.Fatal("ambiguous duplicate accepted")
	}
	put(filepath.Join(library, folderB+".metadata"), `{"type":"DocumentType","parent":"","deleted":true}`)
	id, err = MatchImportedPDF(library, source, "", []string{folderB})
	if err != nil || id != "" {
		t.Fatal("deleted PDF accepted", id, err)
	}
	if _, err := os.Stat(source); err != nil {
		t.Fatal("source changed during verification", err)
	}
}
