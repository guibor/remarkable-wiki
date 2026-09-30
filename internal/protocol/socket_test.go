package protocol

import (
	"encoding/binary"
	"runtime"
	"testing"

	"golang.org/x/sys/unix"
)

func pair(t *testing.T) (*Conn, *Conn) {
	t.Helper()
	if runtime.GOOS != "linux" {
		t.Skip("AppLoad SOCK_SEQPACKET is qualified on Linux")
	}
	fds, err := unix.Socketpair(unix.AF_UNIX, unix.SOCK_SEQPACKET, 0)
	if err != nil {
		t.Fatal(err)
	}
	a, b := &Conn{fd: fds[0]}, &Conn{fd: fds[1]}
	t.Cleanup(a.Close)
	t.Cleanup(b.Close)
	return a, b
}
func TestRoundTrip(t *testing.T) {
	a, b := pair(t)
	for _, body := range []string{"שלום wiki", "", "{}"} {
		if err := a.Send(100, []byte(body)); err != nil {
			t.Fatal(err)
		}
		typ, data, err := b.Read()
		if err != nil || typ != 100 || string(data) != body {
			t.Fatal(typ, string(data), err)
		}
	}
}
func TestRejectOversize(t *testing.T) {
	a, b := pair(t)
	header := make([]byte, 8)
	binary.LittleEndian.PutUint32(header[4:], MaxMessage+1)
	if err := unix.Send(a.fd, header, 0); err != nil {
		t.Fatal(err)
	}
	if _, _, err := b.Read(); err == nil {
		t.Fatal("oversized packet accepted")
	}
}
func TestRejectTruncated(t *testing.T) {
	a, b := pair(t)
	header := make([]byte, 8)
	binary.LittleEndian.PutUint32(header[4:], 2)
	if err := unix.Send(a.fd, header, 0); err != nil {
		t.Fatal(err)
	}
	if err := unix.Send(a.fd, []byte("too much"), 0); err != nil {
		t.Fatal(err)
	}
	if _, _, err := b.Read(); err == nil {
		t.Fatal("truncated packet accepted")
	}
}
