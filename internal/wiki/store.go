package wiki

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

type Record struct {
	Language string `json:"language"`
	Key      string `json:"key"`
	Title    string `json:"title"`
	Path     string `json:"path"`
	Status   string `json:"status"`
}
type Store struct {
	Language string            `json:"language"`
	Records  map[string]Record `json:"records"`
	dir      string
}

func OpenStore(dir string) (*Store, error) {
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}
	s := &Store{Language: "en", Records: map[string]Record{}, dir: dir}
	b, err := os.ReadFile(filepath.Join(dir, "state.json"))
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, err
	}
	if err = json.Unmarshal(b, s); err != nil {
		return nil, err
	}
	if s.Records == nil {
		s.Records = map[string]Record{}
	}
	if !validLanguage(s.Language) {
		s.Language = "en"
	}
	for token, rec := range s.Records {
		expected := filepath.Join(dir, "downloads", Key(rec.Language, rec.Key), filename(rec.Title))
		if !validLanguage(rec.Language) || token != Key(rec.Language, rec.Key) || rec.Path != expected {
			return nil, errors.New("download history contains an invalid app-owned path")
		}
		if rec.Status != "downloaded" && rec.Status != "importing" && rec.Status != "imported" {
			return nil, errors.New("download history contains an invalid status")
		}
	}
	return s, nil
}
func (s *Store) Save() error {
	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	f, err := os.CreateTemp(s.dir, ".state-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	defer f.Close()
	if _, err = f.Write(b); err != nil {
		return err
	}
	if err = f.Sync(); err != nil {
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(f.Name(), filepath.Join(s.dir, "state.json"))
}
