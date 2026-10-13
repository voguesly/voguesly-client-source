import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/common/task.dart' show kLinuxTunDevice;
import 'package:flutter_test/flutter_test.dart';

/// [0.9.96] Windows 按虚拟网卡名认「边个软件占住网络」(09-30 测试机实测名)。
void main() {
  test('易联自己张网卡同普通网卡唔算冲突', () {
    expect(foreignTunOwnerFromNames(['以太网', 'WLAN', appName]), isNull);
  });
  test('官方 FlClash 张网卡叫 FlClash', () {
    expect(foreignTunOwnerFromNames(['以太网', 'FlClash']), 'FlClash(官方版)');
  });
  test('Clash Verge / mihomo 张网卡叫 Meta ⇒ 通用名,由调用方按进程细分', () {
    expect(foreignTunOwnerFromNames(['以太网', 'Meta']), 'Clash 类代理软件');
    expect(foreignTunOwnerFromNames(['Mihomo']), 'Clash 类代理软件');
  });
  test('其他代理软件', () {
    expect(foreignTunOwnerFromNames(['sing-box']), 'sing-box');
    expect(foreignTunOwnerFromNames(['HiddifyTunnel']), 'Hiddify');
  });
  test('公司 VPN / WireGuard 等唔当冲突', () {
    expect(foreignTunOwnerFromNames(['公司VPN', 'WireGuard Tunnel', 'OpenVPN TAP-Windows6']), isNull);
  });
  test('唔会将 Metadata / 名入面有 meta 嘅网卡当成 mihomo', () {
    expect(foreignTunOwnerFromNames(['Metadata Adapter']), isNull);
  });
  test('Linux:易联自己张 voguesly-tun 唔算;官方 FlClash / Verge 张网卡认得出', () {
    expect(foreignTunOwnerFromNames(['lo', 'ens3', kLinuxTunDevice]), isNull);
    expect(foreignTunOwnerFromNames(['ens3', 'FlClash']), 'FlClash(官方版)');
    expect(foreignTunOwnerFromNames(['ens3', 'Mihomo']), 'Clash 类代理软件');
  });
  test('畀用户睇嘅名去走「(服务模式)」', () {
    expect(userFacingProxyName('Clash Verge(服务模式)'), 'Clash Verge');
    expect(userFacingProxyName('Clash Verge（服务模式）'), 'Clash Verge');
    expect(userFacingProxyName('FlClash(官方版)'), 'FlClash(官方版)');
  });

  // [0.9.100] 内核 Windows 换名自愈会把网卡改成 `原名-2`(Clash.Meta `listener/sing_tun/fallback.go`
  // ⇒ `fallbackTunName(name) = name + "-2"`)。换名后网卡**其实已建好、流量照走**,但 Dart 侧只认
  // appName 就会漏认 ⇒ 判「TUN 冇起到」⇒ 触发 controlled core/TUN recovery ⇒ 内核重启 ⇒ 死循环。
  // 2026-10-13 uid 44 工单 #39 日志实证:`desktop transport ok=false` 反复 + `CORE-RECOVER`。
  group('isOurTunName(内核换名自愈 -2)', () {
    test('原名 / Linux 名照旧算自己', () {
      expect(isOurTunName(appName), isTrue);
      expect(isOurTunName(kLinuxTunDevice), isTrue);
    });
    test('换名自愈后嘅 appName-2 都要算自己(呢条就係本次回归)', () {
      expect(isOurTunName('$appName-2'), isTrue);
    });
    test('改成 -2 之后,两个名都唔可以被当成第三方代理软件', () {
      expect(foreignTunOwnerFromNames([appName, '$appName-2', '以太网']), isNull);
      expect(foreignTunOwnerFromNames(['$appName-2']), isNull);
    });
    test('唔可以宽到认任意后缀(只收内核真实会产生嘅名)', () {
      expect(isOurTunName('$appName-backup'), isFalse);
      expect(isOurTunName('$appName-sing-box'), isFalse);
      expect(isOurTunName('${appName}2'), isFalse);
      expect(isOurTunName('x$appName'), isFalse);
      expect(isOurTunName('$appName-'), isFalse);
    });
    test('前后空白要 trim 后再判', () {
      expect(isOurTunName('  $appName  '), isTrue);
      expect(isOurTunName('   '), isFalse);
      expect(isOurTunName(''), isFalse);
    });
  });
}
