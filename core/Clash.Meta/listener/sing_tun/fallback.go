package sing_tun

import (
	"errors"
	"io/fs"
	"time"
)

// wintun 等新网卡设备启动最多 15s;耗时 ≥ 此阈值的失败才算「设备启动超时」,
// 而不是 CreateAdapter 参数/权限类的秒级失败。
const adapterStartTimeoutThreshold = 10 * time.Second

// shouldTryFallbackName 判断是否该换备用网卡名重建:
// 错误是 ERROR_FILE_NOT_FOUND(wintun 把 PnP 问题状态码转出来的结果)且耗时落在设备启动超时区间。
// 同名同 GUID 再重试只会白等 15s,所以直接换名。
func shouldTryFallbackName(err error, elapsed time.Duration) bool {
	return err != nil && errors.Is(err, fs.ErrNotExist) && elapsed >= adapterStartTimeoutThreshold
}

// fallbackTunName 备用网卡名;wintun 的 GUID 由名字派生,名字变 GUID 也变。
func fallbackTunName(name string) string {
	return name + "-2"
}
