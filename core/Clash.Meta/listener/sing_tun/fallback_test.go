package sing_tun

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"testing"
	"time"
)

func TestShouldTryFallbackName(t *testing.T) {
	notFound := fmt.Errorf("configure tun interface: %w", fs.ErrNotExist)
	cases := []struct {
		name    string
		err     error
		elapsed time.Duration
		want    bool
	}{
		{"nil error", nil, 15 * time.Second, false},
		{"not-found after full 15s device-start wait", notFound, 15 * time.Second, true},
		{"not-found right at threshold", notFound, adapterStartTimeoutThreshold, true},
		{"not-found but fast (not a device-start timeout)", notFound, 2 * time.Second, false},
		{"other error after 15s", errors.New("access denied"), 15 * time.Second, false},
		{"os.ErrNotExist counts too", os.ErrNotExist, 12 * time.Second, true},
	}
	for _, c := range cases {
		if got := shouldTryFallbackName(c.err, c.elapsed); got != c.want {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}

func TestFallbackTunNameDiffers(t *testing.T) {
	if got := fallbackTunName("Meta"); got == "Meta" || got == "" {
		t.Fatalf("fallback name must differ from original, got %q", got)
	}
}
