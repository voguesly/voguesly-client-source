package sing_tun

import (
	"fmt"
	"sync"
	"time"

	"github.com/metacubex/mihomo/constant/features"
	"github.com/metacubex/mihomo/log"

	tun "github.com/metacubex/sing-tun"
)

var wintunLoggerOnce sync.Once

// installWintunLogger 把 wintun.dll 内部日志(含 "Failed to setup adapter (problem code, ntstatus)")
// 接进 mihomo 日志;sing-tun 自己从不调用 WintunSetLogger,没有它就分不清设备启动失败的真因。
func installWintunLogger() {
	wintunLoggerOnce.Do(func() {
		tun.SetWintunLogger(func(level int, message string) {
			switch level {
			case tun.WintunLogErr:
				log.Errorln("[TUN] wintun: %s", message)
			case tun.WintunLogWarn:
				log.Warnln("[TUN] wintun: %s", message)
			default:
				log.Infoln("[TUN] wintun: %s", message)
			}
		})
	})
}

// tunNewRetry 同名重试;stuck=true 表示「设备启动超时」,同名同 GUID 再试没意义。
func tunNewRetry(options tun.Options) (tunIf tun.Tun, err error, stuck bool) {
	maxRetry := 3
	for i := 0; i < maxRetry; i++ {
		timeBegin := time.Now()
		tunIf, err = tun.New(options)
		if err == nil {
			return
		}
		elapsed := time.Since(timeBegin)
		if elapsed < 1*time.Second { // retrying for "Cannot create a file when that file already exists."
			return
		}
		if shouldTryFallbackName(err, elapsed) {
			stuck = true
			return
		}
		log.Warnln("Start Tun interface timeout: %s [retrying %d/%d]", err, i+1, maxRetry)
	}
	return
}

// tunNew 成功时 options.Name 即实际生效的网卡名(可能已换成备用名),调用方必须以它为准。
func tunNew(options *tun.Options) (tun.Tun, error) {
	installWintunLogger()
	tunIf, err, stuck := tunNewRetry(*options)
	if err == nil || !stuck {
		return tunIf, err
	}

	alt := *options
	alt.Name = fallbackTunName(options.Name)
	log.Warnln("[TUN] 虚拟网卡 %s 启动超时(%s),改用备用网卡名 %s 重试", options.Name, err, alt.Name)
	tunIf, altErr, altStuck := tunNewRetry(alt)
	if altErr == nil {
		options.Name = alt.Name
		return tunIf, nil
	}
	if altStuck {
		log.Errorln("[TUN] 虚拟网卡启动失败(%s 与 %s 均超时),重启 Windows 可恢复", options.Name, alt.Name)
	}
	return nil, fmt.Errorf("%w (备用网卡名 %s 同样失败: %v)", err, alt.Name, altErr)
}

func init() {
	tun.TunnelType = InterfaceName

	if features.WindowsMajorVersion < 10 {
		// to resolve "bind: The requested address is not valid in its context"
		EnforceBindInterface = true
	}
}
