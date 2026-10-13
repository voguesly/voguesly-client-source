package tun

import "github.com/metacubex/sing-tun/internal/wintun"

// Wintun log levels as passed to the callback of SetWintunLogger.
const (
	WintunLogInfo = wintun.LogInfo
	WintunLogWarn = wintun.LogWarn
	WintunLogErr  = wintun.LogErr
)

// SetWintunLogger forwards wintun.dll's internal diagnostics to fn.
func SetWintunLogger(fn func(level int, message string)) {
	wintun.SetLogger(fn)
}
