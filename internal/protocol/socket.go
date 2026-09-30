// Package protocol implements AppLoad 0.6's header-packet/body-packet transport.
package protocol

import (
	"encoding/binary"
	"errors"
	"golang.org/x/sys/unix"
	"io"
	"sync"
)

const MaxMessage = 1 << 20

type Conn struct {
	fd int
	mu sync.Mutex
}

func Connect(path string) (*Conn, error) {
	fd, err := unix.Socket(unix.AF_UNIX, unix.SOCK_SEQPACKET, 0)
	if err != nil {
		return nil, err
	}
	if err = unix.Connect(fd, &unix.SockaddrUnix{Name: path}); err != nil {
		unix.Close(fd)
		return nil, err
	}
	return &Conn{fd: fd}, nil
}
func (c *Conn) Close() { unix.Close(c.fd) }
func (c *Conn) Read() (uint32, []byte, error) {
	h := make([]byte, 8)
	n, _, flags, _, err := unix.Recvmsg(c.fd, h, nil, 0)
	if err != nil {
		return 0, nil, err
	}
	if n == 0 {
		return 0, nil, io.EOF
	}
	if n != 8 || flags&unix.MSG_TRUNC != 0 {
		return 0, nil, errors.New("invalid AppLoad header")
	}
	t := binary.LittleEndian.Uint32(h)
	size := binary.LittleEndian.Uint32(h[4:])
	if size > MaxMessage {
		return 0, nil, errors.New("AppLoad message too large")
	}
	// AppLoad sends an empty packet for empty strings, unlike its Rust client.
	b := make([]byte, int(size)+1)
	n, _, flags, _, err = unix.Recvmsg(c.fd, b, nil, 0)
	if err != nil {
		return 0, nil, err
	}
	if n != int(size) || flags&unix.MSG_TRUNC != 0 {
		return 0, nil, errors.New("invalid AppLoad body")
	}
	return t, b[:n], nil
}
func (c *Conn) Send(t uint32, b []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(b) > MaxMessage {
		return errors.New("outbound message too large")
	}
	h := make([]byte, 8)
	binary.LittleEndian.PutUint32(h, t)
	binary.LittleEndian.PutUint32(h[4:], uint32(len(b)))
	if err := unix.Send(c.fd, h, 0); err != nil {
		return err
	}
	return unix.Send(c.fd, b, 0)
}
