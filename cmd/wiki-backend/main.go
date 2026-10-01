package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"time"

	"github.com/guibor/remarkable-wiki/internal/protocol"
	"github.com/guibor/remarkable-wiki/internal/wiki"
)

type Request struct {
	Action        string    `json:"action"`
	ID            int       `json:"id"`
	Language      string    `json:"language"`
	Query         string    `json:"query"`
	Page          wiki.Page `json:"page"`
	Token         string    `json:"token"`
	DestinationID string    `json:"destinationId"`
	CandidateIDs  []string  `json:"candidateIds"`
}
type operation struct {
	request     Request
	pages       []wiki.Page
	path        string
	err         error
	destination wiki.Destination
}
type packet struct {
	typ  uint32
	data []byte
	err  error
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "remarkable-wiki:", err)
		os.Exit(1)
	}
}
func run() error {
	client := wiki.NewClient()
	if len(os.Args) == 2 && os.Args[1] == "--check-folders" {
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		folders, err := wiki.ListFolders(filepath.Join(home, ".local/share/remarkable/xochitl"))
		if err != nil {
			return err
		}
		fmt.Printf("Library folder enumeration OK: %d folders plus My files (no writes).\n", len(folders)-1)
		return nil
	}
	if len(os.Args) >= 3 && os.Args[1] == "--search" {
		pages, err := client.Search(context.Background(), "en", os.Args[2])
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(pages)
	}
	if len(os.Args) >= 4 && os.Args[1] == "--download" {
		path, err := client.Download(context.Background(), os.Args[3], "en", os.Args[2], os.Args[2], nil)
		if err != nil {
			return err
		}
		fmt.Println(path)
		return nil
	}
	if len(os.Args) != 2 {
		return fmt.Errorf("launch from AppLoad (or --search QUERY / --download TITLE DIRECTORY)")
	}
	dir := os.Getenv("REMARKABLE_WIKI_STATE")
	if dir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		dir = filepath.Join(home, ".local/share/remarkable-wiki")
	}
	store, err := wiki.OpenStore(dir)
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	library := filepath.Join(home, ".local/share/remarkable/xochitl")
	conn, err := protocol.Connect(os.Args[1])
	if err != nil {
		return err
	}
	defer conn.Close()
	send := func(v any) {
		b, e := json.Marshal(v)
		if e == nil {
			_ = conn.Send(100, b)
		}
	}
	errmsg := func(id int, err error) { send(map[string]any{"kind": "error", "id": id, "message": err.Error()}) }
	ctx, stop := context.WithCancel(context.Background())
	defer stop()
	in := make(chan packet, 4)
	out := make(chan operation, 4)
	go func() {
		for {
			t, b, e := conn.Read()
			select {
			case in <- packet{t, b, e}:
			case <-ctx.Done():
				return
			}
			if e != nil {
				return
			}
		}
	}()
	var cancel context.CancelFunc
	active := 0
	defer func() {
		if cancel != nil {
			cancel()
		}
	}()
	hello := func() {
		send(map[string]any{"kind": "ready", "language": store.Language, "records": store.Records, "destination": store.Destination})
	}
	for {
		select {
		case p := <-in:
			if p.err != nil {
				return nil
			}
			if p.typ == 0xffffffff {
				return nil
			}
			if p.typ == 0xfffffffe {
				hello()
				continue
			}
			if p.typ != 1 {
				continue
			}
			var r Request
			if json.Unmarshal(p.data, &r) != nil {
				continue
			}
			switch r.Action {
			case "hello":
				hello()
			case "resolve-import":
				rec, ok := store.Records[r.Token]
				if !ok || rec.Status != "imported" {
					errmsg(r.ID, fmt.Errorf("native import has not completed"))
					continue
				}
				if rec.DocumentID == "" {
					id, e := wiki.MatchImportedPDF(library, rec.Path, rec.Destination.ID, r.CandidateIDs)
					if e != nil {
						errmsg(r.ID, fmt.Errorf("PDF is saved, but its open shortcut could not be verified: %w", e))
						continue
					}
					if id != "" {
						rec.DocumentID = id
						previous := store.Records[r.Token]
						store.Records[r.Token] = rec
						if e := store.Save(); e != nil {
							store.Records[r.Token] = previous
							errmsg(r.ID, e)
							continue
						}
						_ = os.Remove(rec.Path) // Only the cached source, after native success + ID verification.
					}
				}
				send(map[string]any{"kind": "resolved", "id": r.ID, "token": r.Token, "documentId": rec.DocumentID})
			case "folders":
				folders, e := wiki.ListFolders(library)
				if e != nil {
					errmsg(r.ID, e)
					continue
				}
				send(map[string]any{"kind": "folders", "id": r.ID, "folders": folders})
			case "set-destination":
				if active != 0 {
					errmsg(r.ID, fmt.Errorf("wait for the current download or search"))
					continue
				}
				if e := store.SetDestination(library, r.DestinationID); e != nil {
					errmsg(r.ID, e)
					continue
				}
				send(map[string]any{"kind": "destination", "id": r.ID, "destination": store.Destination})
			case "cancel":
				if cancel != nil {
					cancel()
					cancel = nil
				}
				active = 0
				send(map[string]any{"kind": "cancelled", "id": r.ID})
			case "search", "download":
				if active != 0 {
					errmsg(r.ID, fmt.Errorf("another operation is still running"))
					continue
				}
				if r.ID <= 0 {
					continue
				}
				if r.Language != "en" && r.Language != "he" {
					errmsg(r.ID, fmt.Errorf("unsupported Wikipedia language"))
					continue
				}
				store.Language = r.Language
				if e := store.Save(); e != nil {
					errmsg(r.ID, e)
					continue
				}
				destination := wiki.RootDestination()
				if r.Action == "download" {
					token := wiki.Key(r.Language, r.Page.Key)
					if rec, ok := store.Records[token]; ok && (rec.Status == "imported" || rec.Status == "importing") {
						message := "Already added to " + rec.Destination.Name + ". Changing Save to does not move existing PDFs."
						if rec.Status == "importing" {
							message = "Import was started earlier. Check My files before downloading again."
						}
						send(map[string]any{"kind": "existing", "id": r.ID, "message": message, "documentId": rec.DocumentID, "title": rec.Title, "destination": rec.Destination, "token": token})
						continue
					}
					var e error
					destination, e = wiki.ResolveDestination(library, store.Destination.ID)
					if e != nil {
						errmsg(r.ID, e)
						continue
					}
				}
				job, c := context.WithTimeout(ctx, 90*time.Second)
				cancel = c
				active = r.ID
				go func(r Request, destination wiki.Destination) {
					o := operation{request: r, destination: destination}
					if r.Action == "search" {
						o.pages, o.err = client.Search(job, r.Language, r.Query)
					} else {
						o.path, o.err = client.Download(job, dir, r.Language, r.Page.Key, r.Page.Title, func(n, total int64) { send(map[string]any{"kind": "progress", "id": r.ID, "bytes": n, "total": total}) })
					}
					select {
					case out <- o:
					case <-ctx.Done():
					}
				}(r, destination)
			case "import-started", "imported", "import-failed":
				rec, ok := store.Records[r.Token]
				if !ok {
					errmsg(r.ID, fmt.Errorf("unknown download"))
					continue
				}
				if r.Action == "import-started" {
					destination, e := wiki.ResolveDestination(library, rec.Destination.ID)
					if e != nil {
						errmsg(r.ID, e)
						continue
					}
					if rec.Status != "downloaded" || !wiki.ValidPDF(rec.Path) {
						errmsg(r.ID, fmt.Errorf("PDF is not ready to import"))
						continue
					}
					old := rec
					rec.Status = "importing"
					rec.Destination = destination
					store.Records[r.Token] = rec
					if e := store.Save(); e != nil {
						store.Records[r.Token] = old
						errmsg(r.ID, e)
						continue
					}
					u := url.URL{Scheme: "file", Path: rec.Path}
					send(map[string]any{"kind": "import", "id": r.ID, "url": u.String(), "token": r.Token, "title": rec.Title, "destination": destination})
				} else {
					if rec.Status != "importing" {
						continue
					}
					if r.Action == "imported" {
						rec.Status = "imported"
					} else {
						rec.Status = "downloaded"
					}
					store.Records[r.Token] = rec
					if e := store.Save(); e != nil {
						errmsg(r.ID, e)
						continue
					}
					// Keep the cached source until resolve-import verifies the native ID.
					send(map[string]any{"kind": "recorded", "id": r.ID, "status": rec.Status, "token": r.Token})
				}
			}
		case o := <-out:
			if o.request.ID != active {
				continue
			}
			if cancel != nil {
				cancel()
				cancel = nil
			}
			active = 0
			if o.err != nil {
				errmsg(o.request.ID, o.err)
				continue
			}
			if o.request.Action == "search" {
				send(map[string]any{"kind": "results", "id": o.request.ID, "pages": o.pages})
				continue
			}
			r := o.request
			token := wiki.Key(r.Language, r.Page.Key)
			store.Records[token] = wiki.Record{Language: r.Language, Key: r.Page.Key, Title: r.Page.Title, Path: o.path, Status: "downloaded", Destination: o.destination}
			if e := store.Save(); e != nil {
				errmsg(r.ID, e)
				continue
			}
			send(map[string]any{"kind": "downloaded", "id": r.ID, "token": token, "title": r.Page.Title})
		}
	}
}
