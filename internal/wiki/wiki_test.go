package wiki

import (
	"context"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type transport func(*http.Request) (*http.Response, error)

func (t transport) RoundTrip(r *http.Request) (*http.Response, error) { return t(r) }
func mock(body, ct string, status int, check func(*http.Request)) *Client {
	return &Client{HTTP: &http.Client{Transport: transport(func(r *http.Request) (*http.Response, error) {
		if check != nil {
			check(r)
		}
		return &http.Response{StatusCode: status, Header: http.Header{"Content-Type": {ct}}, Body: io.NopCloser(strings.NewReader(body)), ContentLength: int64(len(body))}, nil
	})}}
}
func TestSearch(t *testing.T) {
	c := mock(`{"pages":[{"id":1,"key":"C++","title":"C++","excerpt":"<span>C++</span> &amp; things"}]}`, "application/json", 200, func(r *http.Request) {
		if r.URL.Host != "he.wikipedia.org" || r.URL.Query().Get("q") != "C++ & hello" || r.Header.Get("User-Agent") == "" {
			t.Fatal(r.URL)
		}
	})
	p, err := c.Search(context.Background(), "he", " C++ & hello ")
	if err != nil || len(p) != 1 || p[0].Excerpt != "C++ & things" {
		t.Fatal(p, err)
	}
	for _, lang := range []string{"../en", "en.wikipedia.org@evil", "", "fr"} {
		if _, err = c.Search(context.Background(), lang, "hello"); err == nil {
			t.Fatal(lang)
		}
	}
	if _, err = c.Search(context.Background(), "en", " "); err == nil {
		t.Fatal("empty query accepted")
	}
}
func TestDownload(t *testing.T) {
	dir := t.TempDir()
	pdf := "%PDF-1.7\nfixture\n%%EOF\n"
	c := mock(pdf, "application/pdf", 200, func(r *http.Request) {
		if r.URL.EscapedPath() != "/api/rest_v1/page/pdf/A%2FB%3F%23" {
			t.Fatal(r.URL)
		}
	})
	path, err := c.Download(context.Background(), dir, "en", "A/B?#", "../../One/Two", nil)
	if err != nil || !ValidPDF(path) {
		t.Fatal(path, err)
	}
	rel, _ := filepath.Rel(dir, path)
	if strings.HasPrefix(rel, "..") || strings.Contains(filepath.Base(path), "/") {
		t.Fatal(path)
	}
	if _, err = os.Stat(filepath.Join(dir, "state.json")); !os.IsNotExist(err) {
		t.Fatal("download wrote unrelated state")
	}
}
func TestRejectBadPDF(t *testing.T) {
	for _, tc := range []struct {
		body, ct string
		status   int
	}{{"<html>bad</html>", "text/html", 200}, {"not pdf", "application/pdf", 200}, {"%PDF-1.7 partial", "application/pdf", 200}, {"", "application/pdf", 429}, {"", "application/pdf", 503}} {
		dir := t.TempDir()
		_, err := mock(tc.body, tc.ct, tc.status, nil).Download(context.Background(), dir, "en", "Earth", "Earth", nil)
		if err == nil {
			t.Fatal(tc)
		}
		_ = filepath.WalkDir(dir, func(p string, d os.DirEntry, e error) error {
			if e == nil && !d.IsDir() {
				t.Errorf("partial file left behind: %s", p)
			}
			return e
		})
	}
}

func TestDownloadFreshBypassesCacheAndPreservesItOnFailure(t *testing.T) {
	dir := t.TempDir()
	oldPDF := "%PDF-1.7\nold article\n%%EOF\n"
	newPDF := "%PDF-1.7\nupdated article\n%%EOF\n"
	path, err := mock(oldPDF, "application/pdf", 200, nil).Download(context.Background(), dir, "en", "Earth", "Earth", nil)
	if err != nil {
		t.Fatal(err)
	}
	calls := 0
	client := mock(newPDF, "application/pdf", 200, func(*http.Request) { calls++ })
	if _, err = client.Download(context.Background(), dir, "en", "Earth", "Earth", nil); err != nil || calls != 0 {
		t.Fatal("normal retry must reuse cache", err, calls)
	}
	bad := mock("<html>unavailable</html>", "text/html", 503, nil)
	if _, err = bad.DownloadFresh(context.Background(), dir, "en", "Earth", "Earth", nil); err == nil {
		t.Fatal("failed refresh accepted")
	}
	bytes, err := os.ReadFile(path)
	if err != nil || string(bytes) != oldPDF {
		t.Fatal("failed refresh destroyed cache", err)
	}
	refreshed, err := client.DownloadFresh(context.Background(), dir, "en", "Earth", "Earth", nil)
	if err != nil || calls != 1 || refreshed != path {
		t.Fatal("refresh must make a fresh request", err, calls, refreshed)
	}
	bytes, err = os.ReadFile(path)
	if err != nil || string(bytes) != newPDF {
		t.Fatal("new PDF not published", err)
	}
}

func TestDownloadDuplicatePolicy(t *testing.T) {
	for _, tc := range []struct {
		status           string
		refresh, blocked bool
	}{
		{"imported", false, true}, {"imported", true, false},
		{"importing", false, true}, {"importing", true, true},
		{"downloaded", false, false}, {"downloaded", true, false},
	} {
		if got := (Record{Status: tc.status}).BlocksDownload(tc.refresh); got != tc.blocked {
			t.Errorf("status=%s refresh=%v blocked=%v", tc.status, tc.refresh, got)
		}
	}
}

func TestStore(t *testing.T) {
	dir := t.TempDir()
	s, err := OpenStore(dir)
	if err != nil {
		t.Fatal(err)
	}
	s.Language = "he"
	token := Key("he", "Earth")
	s.Records[token] = Record{Language: "he", Key: "Earth", Title: "Earth", Path: filepath.Join(dir, "downloads", token, "Earth.pdf"), Status: "importing"}
	if err = s.Save(); err != nil {
		t.Fatal(err)
	}
	s, err = OpenStore(dir)
	if err != nil || s.Language != "he" || s.Records[token].Status != "importing" {
		t.Fatal(s, err)
	}
	if err = os.WriteFile(filepath.Join(dir, "state.json"), []byte("invalid"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err = OpenStore(dir); err == nil {
		t.Fatal("corrupt state must not be discarded")
	}
}
