import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

// [0.9.99] Windows 完整配置重载漏写 `strict-route`(2026-10-13 修):
// 客户端生成完整 YAML 时只写 enable / device / dns-hijack / stack / route-address / auto-route,
// 漏写 strict-route ⇒ 退回内核默认 false ⇒ 多网卡时系统 DNS 由非 TUN 网卡直出运营商 DNS
// (客户日志:所有 DNS 上游 UDP53 + DoH 全超时 ⇒ 全节点红色)。
// 只测模型序列化抓唔到呢个漏写 —— 必须测「最终写进配置嘅实际布尔值」,所以呢组用例。
//
// ⚠️ Windows 判断不能拿掉:macOS / Linux 算出来係 false,无条件写会覆盖订阅里已有嘅 true。

void main() {
  group('applyTunToConfig', () {
    const tun = Tun(enable: true, autoRoute: true, strictRoute: true);

    test('Windows:订阅冇 tun 块 → 仍然写入 strict-route', () {
      final raw = <String, dynamic>{};
      applyTunToConfig(raw, tun, onWindows: true);
      expect((raw['tun'] as Map)['strict-route'], isTrue);
      expect((raw['tun'] as Map)['auto-route'], isTrue);
    });

    test('Windows:空 tun 块 → 写入 strict-route', () {
      final raw = <String, dynamic>{'tun': <String, dynamic>{}};
      applyTunToConfig(raw, tun, onWindows: true);
      expect((raw['tun'] as Map)['strict-route'], isTrue);
    });

    test('Windows:订阅显式 false → 按客户端平台策略覆盖成 true', () {
      final raw = <String, dynamic>{
        'tun': <String, dynamic>{'strict-route': false},
      };
      applyTunToConfig(raw, tun, onWindows: true);
      expect((raw['tun'] as Map)['strict-route'], isTrue);
    });

    test('Windows:模型算出 false 时如实写 false', () {
      final raw = <String, dynamic>{};
      applyTunToConfig(
        raw,
        const Tun(enable: true, autoRoute: true),
        onWindows: true,
      );
      expect((raw['tun'] as Map)['strict-route'], isFalse);
    });

    test('非 Windows:唔写 strict-route,订阅原有 true 保留', () {
      final raw = <String, dynamic>{
        'tun': <String, dynamic>{'strict-route': true},
      };
      applyTunToConfig(raw, tun, onWindows: false);
      expect((raw['tun'] as Map)['strict-route'], isTrue);
    });

    test('非 Windows:订阅冇 strict-route 时唔会凭空写入', () {
      final raw = <String, dynamic>{
        'tun': <String, dynamic>{'mtu': 9000},
      };
      applyTunToConfig(raw, tun, onWindows: false);
      expect((raw['tun'] as Map).containsKey('strict-route'), isFalse);
    });

    test('订阅里模型未覆盖嘅字段要保留', () {
      final raw = <String, dynamic>{
        'tun': <String, dynamic>{
          'mtu': 1400,
          'route-exclude-address': <String>['1.2.3.0/24'],
        },
      };
      applyTunToConfig(raw, tun, onWindows: true);
      expect((raw['tun'] as Map)['mtu'], 1400);
      expect((raw['tun'] as Map)['route-exclude-address'], ['1.2.3.0/24']);
      expect((raw['tun'] as Map)['strict-route'], isTrue);
    });
  });
}
