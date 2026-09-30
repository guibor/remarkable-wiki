// Package wiki talks directly to Wikipedia and stores only application-owned PDFs.
package wiki

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
	"unicode"
)

const MaxPDF = 64 << 20
const UserAgent = "RemarkableWiki/0.1 (https://github.com/guibor/remarkable-wiki; personal e-reader)"

type Page struct {
	ID          int    `json:"id"`
	Key         string `json:"key"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Excerpt     string `json:"excerpt"`
}

type Client struct{ HTTP *http.Client }

func NewClient() *Client {
	return &Client{HTTP: &http.Client{
		Timeout: 90 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 4 {
				return errors.New("too many Wikipedia redirects")
			}
			if req.URL.Scheme != "https" || req.URL.Host != via[0].URL.Host || req.URL.User != nil {
				return errors.New("refused redirect outside the selected Wikipedia site")
			}
			return nil
		},
	}}
}

func validLanguage(lang string) bool { return lang == "en" || lang == "he" }

func endpoint(lang, path string) (string, error) {
	if !validLanguage(lang) {
		return "", errors.New("choose English or Hebrew Wikipedia")
	}
	return "https://" + lang + ".wikipedia.org" + path, nil
}

func (c *Client) get(ctx context.Context, address string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", address, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", UserAgent)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Wikipedia could not be reached: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		if resp.StatusCode == 429 {
			return nil, errors.New("Wikipedia is rate-limiting requests; please try again later")
		}
		return nil, fmt.Errorf("Wikipedia returned HTTP %d; try again later", resp.StatusCode)
	}
	return resp, nil
}

var tags = regexp.MustCompile(`<[^>]*>`)

func plain(s string) string {
	return strings.Join(strings.Fields(html.UnescapeString(tags.ReplaceAllString(s, ""))), " ")
}

func (c *Client) Search(ctx context.Context, lang, query string) ([]Page, error) {
	query = strings.TrimSpace(query)
	if query == "" || len([]rune(query)) > 200 {
		return nil, errors.New("enter a search between 1 and 200 characters")
	}
	address, err := endpoint(lang, "/w/rest.php/v1/search/page?"+url.Values{"q": {query}, "limit": {"15"}}.Encode())
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, 25*time.Second)
	defer cancel()
	resp, err := c.get(ctx, address)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(io.LimitReader(resp.Body, (2<<20)+1))
	if err != nil {
		return nil, err
	}
	if len(b) > 2<<20 {
		return nil, errors.New("Wikipedia search response too large")
	}
	var result struct {
		Pages []Page `json:"pages"`
	}
	if err = json.Unmarshal(b, &result); err != nil {
		return nil, errors.New("Wikipedia returned an invalid search response")
	}
	if len(result.Pages) > 15 {
		result.Pages = result.Pages[:15]
	}
	for i := range result.Pages {
		p := &result.Pages[i]
		p.Title = plain(p.Title)
		p.Description = plain(p.Description)
		p.Excerpt = plain(p.Excerpt)
		if p.Key == "" || len(p.Key) > 1024 {
			return nil, errors.New("Wikipedia returned an invalid article key")
		}
	}
	return result.Pages, nil
}

func Key(lang, title string) string {
	sum := sha256.Sum256([]byte(lang + "\x00" + title))
	return hex.EncodeToString(sum[:12])
}

func filename(title string) string {
	runes := []rune(strings.Map(func(r rune) rune {
		if unicode.IsLetter(r) || unicode.IsNumber(r) || r == ' ' || r == '-' || r == '_' || r == '(' || r == ')' {
			return r
		}
		return '_'
	}, title))
	if len(runes) > 100 {
		runes = runes[:100]
	}
	name := strings.TrimSpace(string(runes))
	if name == "" {
		name = "Wikipedia"
	}
	return name + ".pdf"
}

func ValidPDF(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() < 8 || info.Size() > MaxPDF {
		return false
	}
	var header [5]byte
	_, err = io.ReadFull(f, header[:])
	if err != nil || string(header[:]) != "%PDF-" {
		return false
	}
	n := int64(2048)
	if info.Size() < n {
		n = info.Size()
	}
	_, err = f.Seek(-n, io.SeekEnd)
	if err != nil {
		return false
	}
	tail, err := io.ReadAll(f)
	return err == nil && strings.Contains(string(tail), "%%EOF")
}

// Download never publishes partial/non-PDF content and never writes xochitl data.
func (c *Client) Download(ctx context.Context, dir, lang, key, title string, progress func(int64, int64)) (string, error) {
	if strings.TrimSpace(key) == "" || len(key) > 1024 {
		return "", errors.New("invalid article key")
	}
	address, err := endpoint(lang, "/api/rest_v1/page/pdf/"+url.PathEscape(key))
	if err != nil {
		return "", err
	}
	folder := filepath.Join(dir, "downloads", Key(lang, key))
	if err = os.MkdirAll(folder, 0700); err != nil {
		return "", err
	}
	path := filepath.Join(folder, filename(title))
	if ValidPDF(path) {
		return path, nil
	}
	resp, err := c.get(ctx, address)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.ContentLength > MaxPDF {
		return "", errors.New("article PDF exceeds the 64 MB limit")
	}
	if !strings.HasPrefix(strings.ToLower(resp.Header.Get("Content-Type")), "application/pdf") {
		return "", errors.New("Wikipedia did not return a PDF for this article")
	}
	f, err := os.CreateTemp(folder, ".download-*.part")
	if err != nil {
		return "", err
	}
	tmp := f.Name()
	defer os.Remove(tmp)
	defer f.Close()
	buffer := make([]byte, 32<<10)
	var total int64
	last := time.Now().Add(-time.Second)
	for {
		n, readErr := resp.Body.Read(buffer)
		if n > 0 {
			total += int64(n)
			if total > MaxPDF {
				return "", errors.New("article PDF exceeds the 64 MB limit")
			}
			if _, err = f.Write(buffer[:n]); err != nil {
				return "", err
			}
			if progress != nil && time.Since(last) > 400*time.Millisecond {
				progress(total, resp.ContentLength)
				last = time.Now()
			}
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			return "", readErr
		}
	}
	if err = f.Sync(); err != nil {
		return "", err
	}
	if err = f.Close(); err != nil {
		return "", err
	}
	if !ValidPDF(tmp) {
		return "", errors.New("download was not a complete PDF; please retry")
	}
	if err = os.Rename(tmp, path); err != nil {
		return "", err
	}
	return path, nil
}
