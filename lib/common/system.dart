import 'dart:ffi';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show TextSpan;
import 'package:path/path.dart';

class System {
  static System? _instance;
  // [2026-09-21] route probe 正常结果只喺变化时写日志(见 action.dart 心跳注释)
  String? _lastMacRouteProbeLine;

  System._internal();

  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  // macOS TUN 提权 helper(SMAppService LaunchDaemon)的 platform channel。
  // 原生侧实现在 macos/Runner/TunHelperManager.swift,只在 macOS 且 helper target 已接入时可用;
  // 未接入前 invoke 会抛 MissingPluginException,authorizeCore 会自动回退旧 osascript 逻辑。
  static const _tunHelperChannel = MethodChannel('voguesly/tunhelper');

  bool get isDesktop => isWindows || isMacOS || isLinux;

  bool get isWindows => Platform.isWindows;

  bool get isMacOS => Platform.isMacOS;

  bool get isAndroid => Platform.isAndroid;

  bool get isLinux => Platform.isLinux;

  /// TUN helper 需要从已安装的 App bundle 注册到 macOS 后台项目。
  /// 从 DMG 挂载卷或 App Translocation 直接运行时，SMAppService 不能可靠地
  /// 注册/启动这个 helper；这时必须先把 App 拖进 Applications，再从那里打开。
  bool get isMacRunningFromInstaller =>
      isMacOS &&
      (Platform.resolvedExecutable.startsWith('/Volumes/') ||
          Platform.resolvedExecutable.contains('/AppTranslocation/'));

  Future<bool> openMacTunSettings() async {
    if (!isMacOS) return false;
    try {
      final result = await Process.run('/usr/bin/open', [
        'x-apple.systempreferences:com.apple.LoginItems-Settings.extension',
      ]);
      return result.exitCode == 0;
    } catch (e) {
      commonPrint.log(
        'open macOS TUN settings failed: $e',
        logLevel: LogLevel.warning,
      );
      return false;
    }
  }

  Future<int> get version async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    return switch (Platform.operatingSystem) {
      'macos' => (deviceInfo as MacOsDeviceInfo).majorVersion,
      'android' => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      'windows' => (deviceInfo as WindowsDeviceInfo).majorVersion,
      String() => 0,
    };
  }

  Future<bool> checkIsAdmin() async {
    // ⚠️ 这里**不能**对空格做转义。`Process.run` 不经 shell,参数是原样传给 stat 的;
    // 原来的 `replaceAll(' ', '\\\\ ')` 会把真实空格变成「反斜杠+空格」两个字符,
    // stat 直接 file-not-found → 恒返 false → TUN 授权永远过不去。
    // 旧的 corePath 在 /Applications/...app/Contents/MacOS/ 下没有空格,所以这个 bug 一直潜伏;
    // 核心搬到 `~/Library/Application Support/` 后路径含空格,会立刻引爆。
    final corePath = appPath.corePath;
    if (system.isWindows) {
      final result = await windows?.checkService();
      return result == WindowsHelperServiceStatus.running;
    } else if (system.isMacOS) {
      final result = await Process.run('stat', ['-f', '%Su:%Sg %Sp', corePath]);
      final output = result.stdout.trim();
      // [TUN-DIAG] 只加诊断,不改判定逻辑。若授权后 corePath 仍在只读的 AppTranslocation/
      // /private/var/folders 路径 => chmod +sx 无效 => 核心非 root => utun 创不成 => 假连接。
      final rawCorePath = appPath.corePath;
      final translocated =
          rawCorePath.contains('AppTranslocation') ||
          rawCorePath.contains('/private/var/folders');
      final isAdminDiag =
          output.startsWith('root:admin') && output.contains('rws');
      commonPrint.log(
        '[TUN-DIAG] checkIsAdmin macOS corePath=$rawCorePath '
        'translocated=$translocated statOutput="$output" isAdmin=$isAdminDiag',
        logLevel: LogLevel.info,
      );
      if (output.startsWith('root:admin') && output.contains('rws')) {
        return true;
      }
      return false;
    } else if (Platform.isLinux) {
      // [0.9.86] Linux 改用 file capabilities,唔再用 setuid root。
      // 旧做法 `chown root + chmod +sx` 会令一个 60MB 嘅代理核心长期挂住 setuid root
      // (而且关咗 TUN 都唔还原)= 白送一个提权面;capabilities 只畀 TUN 真正需要嘅
      // CAP_NET_ADMIN / CAP_NET_RAW,而且写入文件会自动清走。
      // ⚠️ getcap 喺 /usr/sbin:Debian / Ubuntu 普通用户嘅 PATH **冇** sbin
      // (桌面会话继承落嚟嘅 PATH 亦冇)⇒ 净係写 'getcap' 会 ProcessException / 127,
      // 令 checkIsAdmin 永远 false、每次都重新弹密码。所以逐个候选路径试。
      for (final exe in const ['getcap', '/usr/sbin/getcap', '/sbin/getcap']) {
        try {
          final result = await Process.run(exe, [corePath]);
          if (result.exitCode != 0) continue;
          return result.stdout.toString().toLowerCase().contains('cap_net_admin');
        } on ProcessException catch (_) {
          continue;
        }
      }
      return false;
    }
    return true;
  }

  static String _shellEscape(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  /// 与 TunHelper (macos/TunHelper/main.swift kCoreRequirement) 保持一致的签名要求:
  /// 必须是 Apple 根信任链下、叶证书 OU == 我们 team 的产物。
  static const _macCoreRequirement =
      'anchor apple generic and certificate leaf[subject.OU] = "236T6T3629"';

  /// 校验将要被抬成 setuid-root 的核心确实是我们签的。失败一律拒绝提权。
  Future<bool> _verifyMacCoreSignature() async {
    try {
      final result = await Process.run('codesign', [
        '--verify',
        '--strict',
        '-R=$_macCoreRequirement',
        appPath.corePath,
      ]);
      final ok = result.exitCode == 0;
      commonPrint.log(
        '[TUN-DIAG] 核心验签 exitCode=${result.exitCode} ok=$ok '
        'stderr="${result.stderr.toString().trim()}"',
        logLevel: ok ? LogLevel.info : LogLevel.error,
      );
      return ok;
    } catch (e) {
      commonPrint.log('核心验签异常: $e', logLevel: LogLevel.error);
      return false;
    }
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (system.isAndroid) {
      return AuthorizeCode.error;
    }
    final isAdmin = await checkIsAdmin();
    if (isAdmin) {
      return AuthorizeCode.none;
    }

    if (system.isWindows) {
      final result = await windows?.registerService();
      if (result == true && await checkIsAdmin()) {
        return AuthorizeCode.success;
      }
      return AuthorizeCode.error;
    }

    if (system.isMacOS) {
      // [TUN-DIAG] 进入 macOS 授权分支时的状态快照(不改逻辑)。
      commonPrint.log(
        '[TUN-DIAG] authorizeCore macOS enter isAdmin=$isAdmin '
        'corePath=${appPath.corePath}',
        logLevel: LogLevel.info,
      );
      // 纵深防线:核心已搬出 app bundle(见 AppPath.corePath 注释),落在用户可写目录。
      // 抬 setuid-root 之前必须验签,确保只有本 team 签名的核心能被提权 —— 否则任何
      // 以当前用户身份跑的进程只要事先把核心换掉,就能骗到一个 root shell(confused deputy)。
      if (!await _verifyMacCoreSignature()) {
        return AuthorizeCode.error;
      }
      // 加法:优先走 root helper(免重复密码)。返回 null = helper 不可用/未接入,回退旧 osascript。
      final helperResult = await _authorizeCoreViaMacHelper();
      if (helperResult != null) {
        return helperResult;
      }
      final escapedPath = _shellEscape(appPath.corePath);
      final shell = 'chown root:admin $escapedPath && chmod +sx $escapedPath';
      final arguments = [
        '-e',
        'do shell script "$shell" with administrator privileges',
      ];
      final result = await Process.run('osascript', arguments);
      // [TUN-DIAG] osascript 执行结果(exitCode + 截断 stderr)。
      final stderrStr = result.stderr.toString();
      commonPrint.log(
        '[TUN-DIAG] authorizeCore osascript exitCode=${result.exitCode} '
        'stderr="${stderrStr.substring(0, stderrStr.length > 300 ? 300 : stderrStr.length)}"',
        logLevel: LogLevel.info,
      );
      // [TUN-DIAG] 关键:授权后再核实一次 setuid 是否真的生效。
      // 若仍 false => translocation/只读路径 chmod 无效(实锤理论)。
      final postAuthIsAdmin = await checkIsAdmin();
      commonPrint.log(
        '[TUN-DIAG] authorizeCore post-auth checkIsAdmin=$postAuthIsAdmin '
        '(若授权后仍 false => 只读/translocation 路径 chmod 无效)',
        logLevel: LogLevel.info,
      );
      if (result.exitCode != 0 || !postAuthIsAdmin) {
        commonPrint.log(
          '[TUN-DIAG] authorizeCore failed post-auth verification',
          logLevel: LogLevel.error,
        );
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    } else if (Platform.isLinux) {
      final shell = Platform.environment['SHELL'] ?? 'bash';
      final password = await globalState.showCommonDialog<String>(
        child: InputDialog(
          obscureText: true,
          title: currentAppLocalizations.pleaseInputAdminPassword,
          value: '',
        ),
      );
      if (password == null || password.isEmpty) {
        return AuthorizeCode.error;
      }
      final escapedPassword = _shellEscape(password);
      final escapedCorePath = _shellEscape(appPath.corePath);
      final escapedBundledCorePath = _shellEscape(appPath.bundledCorePath);
      // [0.9.86] 授权 = 给核心打 capabilities(CAP_NET_ADMIN 建 tun / 改路由,CAP_NET_RAW 收发原始包),
      // 唔再 setuid root。顺手:
      //   ① chown root + chmod 0755 —— 普通用户改唔到呢个档(改写会即刻清走 capabilities);
      //   ② 清走 0.9.85 及之前留低嘅 setuid 位(安装目录嗰份母本都清埋)。
      final escapedSudo = 'echo $escapedPassword | sudo -S';
      final arguments = [
        '-c',
        '$escapedSudo chown root:root $escapedCorePath '
            '&& $escapedSudo chmod 0755 $escapedCorePath '
            '&& ( $escapedSudo setcap cap_net_admin,cap_net_raw+ep $escapedCorePath || $escapedSudo /usr/sbin/setcap cap_net_admin,cap_net_raw+ep $escapedCorePath ) '
            '; $escapedSudo chmod 0755 $escapedBundledCorePath 2>/dev/null; true',
      ];
      final result = await Process.run(shell, arguments);
      final ok = await checkIsAdmin();
      commonPrint.log(
        '[TUN-DIAG] authorizeCore linux setcap exitCode=${result.exitCode} '
        'postAuthHasCaps=$ok',
        logLevel: LogLevel.info,
      );
      if (!ok) {
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    }
    return AuthorizeCode.error;
  }

  // macOS:经 root helper 给核心打 setuid。
  // 返回值:
  //   AuthorizeCode.success —— helper 已把核心提权好。
  //   AuthorizeCode.error   —— 需用户在系统设置批准 helper(已弹引导),别再回退弹密码。
  //   null                  —— helper 未接入 / 不可用 / 提权失败,调用方回退旧 osascript 逻辑。
  Future<AuthorizeCode?> _authorizeCoreViaMacHelper() async {
    final corePath = appPath.corePath;
    try {
      if (system.isMacRunningFromInstaller) {
        await globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: TextSpan(
            text:
                l10nJoin([
                  currentAppLocalizations.vgRunningFromDmgHint,
                  currentAppLocalizations.vgRunningFromDmgHint2,
                ]),
          ),
          confirmText: currentAppLocalizations.vgGotIt,
        );
        return AuthorizeCode.error;
      }
      // 先确保 daemon 已注册。首次会是 requiresApproval,引导用户去系统设置放行。
      final status = await _tunHelperChannel.invokeMethod<String>('register');
      if (status == 'requiresApproval') {
        final openSettings = await globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: TextSpan(
            text:
                l10nJoin([
                  currentAppLocalizations.vgAllowLoginItemHint,
                  currentAppLocalizations.vgAllowLoginItemHint2,
                ]),
          ),
          confirmText: currentAppLocalizations.vgOpenSystemSettings,
        );
        if (openSettings == true) await system.openMacTunSettings();
        return AuthorizeCode.error;
      }
      if (status == 'unsupported') {
        // macOS <13: SMAppService is unavailable; keep the legacy path.
        return null;
      }
      if (status != 'enabled') {
        // The helper is present but not usable. Falling back to a password
        // prompt on every reconnect is the repeated-authorization bug.
        commonPrint.log(
          'tunhelper register status: $status',
          logLevel: LogLevel.error,
        );
        final openSettings = await globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: TextSpan(text: currentAppLocalizations.vgTunServiceNotEnabled),
          confirmText: currentAppLocalizations.vgOpenSystemSettings,
        );
        if (openSettings == true) await system.openMacTunSettings();
        return AuthorizeCode.error;
      }
      final result = await _tunHelperChannel
          .invokeMethod<Map<Object?, Object?>>('ensureSetuid', {
            'corePath': corePath,
          });
      if (result != null && result['ok'] == true) {
        return await checkIsAdmin()
            ? AuthorizeCode.success
            : AuthorizeCode.error;
      }
      commonPrint.log(
        'tunhelper ensureSetuid failed: ${result?['msg']}',
        logLevel: LogLevel.error,
      );
      // 反应式迁移:升级覆盖后可能仲係旧 helper 驻留(唔认新嘅外置核心路径)。
      // 呢种情况先至值得拆 daemon 重注册 —— 0.9.57 嗰种「一见版本唔同就主动拆」
      // 会喺每次升级都令 daemon 掉出 .enabled,系 0.9.61/0.9.62 TUN 永久起唔到嘅根因。
      final migrated = await _tunHelperChannel.invokeMethod<String>('migrate');
      commonPrint.log(
        '[TUN-DIAG] tunhelper reactive migrate status=$migrated',
        logLevel: LogLevel.warning,
      );
      if (migrated != 'enabled') {
        if (migrated == 'requiresApproval') {
          final openSettings = await globalState.showMessage(
            title: currentAppLocalizations.tip,
            message: TextSpan(
              text:
                  l10nJoin([
                    currentAppLocalizations.vgTunServiceNeedsReauth,
                    currentAppLocalizations.vgTunServiceNeedsReauth2,
                  ]),
            ),
            confirmText: currentAppLocalizations.vgOpenSystemSettings,
          );
          if (openSettings == true) await system.openMacTunSettings();
        }
        return AuthorizeCode.error;
      }
      final retry = await _tunHelperChannel
          .invokeMethod<Map<Object?, Object?>>('ensureSetuid', {
            'corePath': corePath,
          });
      if (retry != null && retry['ok'] == true) {
        return await checkIsAdmin()
            ? AuthorizeCode.success
            : AuthorizeCode.error;
      }
      commonPrint.log(
        'tunhelper ensureSetuid retry failed: ${retry?['msg']}',
        logLevel: LogLevel.error,
      );
      return AuthorizeCode.error;
    } on MissingPluginException {
      // helper target 未接入(Xcode GUI 步骤未做)——回退,保证接入前 app 照常可用。
      return null;
    } on PlatformException catch (e) {
      commonPrint.log(
        'tunhelper channel error: ${e.message}',
        logLevel: LogLevel.error,
      );
      return AuthorizeCode.error;
    } catch (e) {
      commonPrint.log(
        'tunhelper unexpected error: $e',
        logLevel: LogLevel.error,
      );
      return AuthorizeCode.error;
    }
  }

  /// Returns a known third-party proxy/TUN process currently running.
  /// We warn instead of killing it: route ownership cannot be safely stolen
  /// from arbitrary VPN/network-extension clients.
  /// [0.9.87] detectThirdPartyTunnel 返嘅係进程关键字(小写),畀用户睇要换返产品名。
  /// [0.9.96 Mac] `vpn:` 前缀 = 系统 VPN 类(见 [macForeignTunOwner]),显示时去掉。
  String thirdPartyProxyDisplayName(String key) {
    final k = key.startsWith('vpn:') ? key.substring(4) : key;
    return switch (k) {
      'clash verge' || 'clash-verge' => 'Clash Verge',
      'clashx' => 'ClashX',
      'clash meta' => 'Clash Meta',
      'mihomo-party' => 'Mihomo Party',
      'sing-box' || 'singbox' => 'sing-box',
      _ => k,
    };
  }

  /// [0.9.96] Windows / Linux:搵出**占住网络嘅第三方虚拟网卡**属于边个软件(返产品名);冇就返 null。
  /// 网卡名比进程名可靠:进程开住唔代表佢抢网络(例:Verge 退出后仲有个空闲服务),
  /// 网卡喺度先代表真係有人接管紧流量。「Meta」呢类通用名再用进程名细分(Verge / Mihomo Party)。
  Future<String?> foreignTunAdapterOwner() async {
    if (!isWindows && !isLinux) return null;
    try {
      final ifaces = await NetworkInterface.list(includeLoopback: false);
      final owner = foreignTunOwnerFromNames(ifaces.map((i) => i.name));
      if (owner == null) return null;
      if (owner != 'Clash 类代理软件') return owner;
      final procs = await listOtherProxyProcesses();
      return procs.isNotEmpty ? userFacingProxyName(procs.first) : owner;
    } catch (e) {
      commonPrint.log('foreign TUN adapter probe failed: $e', logLevel: LogLevel.warning);
      return null;
    }
  }

  /// [0.9.96 Mac] 连接前:公网流量已经行紧某个 utun ⇒ 有第三方接管咗网络,揾出係边个软件。
  /// ⚠️ 只可以喺易联**未连接**时调(连住时公网本来就行易联自己个 utun,见 action.dart 调用处嘅守卫)。
  /// 旧逻辑「进程名单命中 + 有 198.18 utun」两样独立拼凑,09-30 MacBook Air 实测三个场景全部报错人:
  ///   · 官方 FlClash 开 TUN ⇒ 报「请先退出 Clash Verge」(只因为 Verge 服务模式个常驻服务喺度);
  ///   · 用户照做彻底退出 Verge ⇒ 仍然报 Verge(死循环,永远连唔到);
  ///   · Shadowrocket 开 VPN ⇒ 一样报 Verge。
  /// 返回:`vpn:<名>` = 系统 VPN(要关 VPN 开关);其他 = 产品名;null = 冇人占。
  Future<String?> macForeignTunOwner() async {
    if (!isMacOS) return null;
    try {
      Future<bool> publicRouteOnTun() async {
        final routes = await Future.wait([
          _macRouteInterface('1.1.1.1'),
          _macRouteInterface('8.8.8.8'),
        ]);
        return routes.whereType<String>().any((i) => i.startsWith('utun'));
      }

      if (!await publicRouteOnTun()) return null;
      final nc = (await Process.run('/usr/sbin/scutil', ['--nc', 'list'])).stdout.toString();
      final vpns = macConnectedVpnNames(nc);
      if (vpns.isNotEmpty) return 'vpn:${vpns.join('、')}';
      final ps = (await Process.run('ps', ['-axo', 'comm='])).stdout.toString();
      final cores = macTunCoreOwners(ps, vergeTunOn: await _macVergeTunEnabled());
      if (cores.isNotEmpty) return cores.join('、');
      // 认唔出係边个:可能係易联自己啱啱断开、utun 未收完(快速断开再连)。等一阵再睇,仲喺度先算。
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!await publicRouteOnTun()) return null;
      commonPrint.log('[TUN-DIAG] macOS: 公网行紧第三方 utun,但认唔出软件', logLevel: LogLevel.warning);
      return '其他代理软件';
    } catch (e) {
      commonPrint.log('mac foreign TUN probe failed: $e', logLevel: LogLevel.warning);
      return null;
    }
  }

  /// Clash Verge「虚拟网卡模式」开关(verge.yaml `enable_tun_mode`);读唔到返 null。
  Future<bool?> _macVergeTunEnabled() async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      final f = File('$home/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/verge.yaml');
      if (!await f.exists()) return null;
      final m = RegExp(r'^enable_tun_mode:\s*(true|false)', multiLine: true).firstMatch(await f.readAsString());
      return m == null ? null : m.group(1) == 'true';
    } catch (_) {
      return null;
    }
  }

  /// [2026-09-29] 列出正在运行嘅其他代理软件(唔要求对方开住 TUN)。
  /// 起因:客户关咗 Clash Verge 窗口,但 Verge「服务模式」嘅内核 verge-mihomo.exe 仲喺后台跑,
  /// 抢住网卡令易联 TUN 起唔到、Codex 行去 Verge 嘅代理端口 → 10061。旧检测名单冇 verge-mihomo,
  /// 而且只喺对方开住 TUN 先报,所以成晚都冇提示。
  Future<List<String>> listOtherProxyProcesses() async {
    if (!isDesktop) return const [];
    try {
      final out = isWindows
          ? (await Process.run('tasklist', const ['/FO', 'CSV', '/NH'])).stdout.toString()
          : (await Process.run('ps', ['-axo', 'comm='])).stdout.toString();
      return matchOtherProxyProcesses(out, windows: isWindows);
    } catch (e) {
      commonPrint.log('other proxy process scan failed: $e');
      return const [];
    }
  }

  /// [2026-09-29] 读系统代理(Windows 注册表 / macOS scutil),返「host:port」;冇开返 null。
  Future<String?> readOsSystemProxy() async {
    if (!isDesktop) return null;
    try {
      if (isWindows) {
        const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
        final en = (await Process.run('reg', ['query', key, '/v', 'ProxyEnable'])).stdout.toString().toLowerCase();
        if (!en.contains('0x1')) return null;
        final sv = (await Process.run('reg', ['query', key, '/v', 'ProxyServer'])).stdout.toString();
        final m = RegExp(r'ProxyServer\s+REG_SZ\s+(\S+)').firstMatch(sv);
        return m?.group(1);
      }
      if (isMacOS) {
        final out = (await Process.run('/usr/sbin/scutil', ['--proxy'])).stdout.toString();
        if (!RegExp(r'(HTTPEnable|HTTPSEnable|SOCKSEnable)\s*:\s*1').hasMatch(out)) return null;
        final h = RegExp(r'HTTPSProxy\s*:\s*(\S+)').firstMatch(out) ?? RegExp(r'HTTPProxy\s*:\s*(\S+)').firstMatch(out);
        final p = RegExp(r'HTTPSPort\s*:\s*(\d+)').firstMatch(out) ?? RegExp(r'HTTPPort\s*:\s*(\d+)').firstMatch(out);
        return h == null ? 'on' : '${h.group(1)}:${p?.group(1) ?? '?'}';
      }
    } catch (_) {}
    return null;
  }

  /// [2026-09-29] 读 HTTP_PROXY / HTTPS_PROXY / ALL_PROXY(Windows 用户环境变量 + 本进程环境),返「名=值」。
  /// Codex / 终端 / 好多开发工具认呢几个变量,指住已关闭嘅代理端口就会「积极拒绝 10061」。
  Future<List<String>> readProxyEnvVars() async {
    final found = <String>{};
    const names = ['HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy'];
    for (final n in names) {
      final v = Platform.environment[n];
      if (v != null && v.trim().isNotEmpty) found.add('${n.toUpperCase()}=${v.trim()}');
    }
    if (isWindows) {
      try {
        final out = (await Process.run('reg', ['query', r'HKCU\Environment'])).stdout.toString();
        for (final m in RegExp(r'^\s*(HTTPS?_PROXY|ALL_PROXY)\s+REG_\w+\s+(\S+)', caseSensitive: false, multiLine: true).allMatches(out)) {
          found.add('${m.group(1)!.toUpperCase()}=${m.group(2)}');
        }
      } catch (_) {}
    }
    return found.toList();
  }

  Future<String?> detectThirdPartyTunnel() async {
    if (!isDesktop) return null;
    // [0.9.96] Windows 按「虚拟网卡名」认边个占住网络,唔再用「进程名 + 有 198.18 路由」两样独立拼凑。
    //   实测(09-30 测试机):
    //   · 官方 FlClash 开住 TUN ⇒ 旧名单冇 FlClash ⇒ 唔拦,易联网卡起唔到但显示「已连接」;
    //   · 同时仲有 Clash Verge 嘅空闲服务 ⇒ 旧逻辑认咗 Verge 做凶手(「请先退出 Clash Verge」),用户照做都冇用。
    // [0.9.96 Linux] 同 Windows 一样按网卡名认(Linux 网卡名由各软件自己起:易联 voguesly-tun、官方 FlClash「FlClash」、
    //   Clash Verge「Mihomo」)。旧逻辑喺 Linux 冇验路由(verifyDesktopTunTransport 直接返 true)⇒ 淨係见到
    //   clash-verge / daed / sing-box 进程就拦,Verge TUN 冇开、只剩常驻服务都照拦(同 Mac 09-30 实测嘅死循环同一类)。
    if (isWindows || isLinux) return foreignTunAdapterOwner();
    if (isMacOS) return macForeignTunOwner();
    try {
      final output = isWindows
          ? (await Process.run('tasklist', const [])).stdout.toString()
          : (await Process.run('ps', ['-axo', 'comm='])).stdout.toString();
      const known = [
        'clash verge',
        'clash-verge',
        'clashx',
        'clash meta',
        'mihomo-party',
        'daed',
        'sing-box',
        'singbox',
      ];
      final lower = output.toLowerCase();
      for (final name in known) {
        if (lower.contains(name) && await verifyDesktopTunTransport()) {
          return name;
        }
      }
    } catch (e) {
      commonPrint.log('third-party tunnel detection failed: $e');
    }
    return null;
  }

  /// Best-effort device-level TUN probe used for truthful desktop status.
  /// Mihomo desktop TUN should own the default route; if it does not, the
  /// green connected state is unsafe.  During startup macOS may publish the
  /// utun interface before the route table settles, so this probe deliberately
  /// checks more than one route and the interface itself instead of treating a
  /// single transient `route -n get default` result as a disconnect.
  Future<bool> verifyDesktopTunTransport() async {
    if (!isDesktop) return true;
    try {
      if (isMacOS) {
        // ⚠️ 2026-08-05 根因:**绝对唔可以用 `route -n get default` 做判据**。
        //
        // macOS 上 mihomo/sing-tun 係用两条「更具体」嘅路由(0.0.0.0/1 + 128.0.0.0/1)
        // 覆盖式接管流量,**从来唔会替换 `default` 条目**。所以 TUN 完全正常运作嗰阵,
        // `route get default` 照样返物理网卡。实测(Sam 本机,TUN 健康、Telegram 流量
        // 已经喺 utun9 上跑):
        //     route get default  → en1     ← 旧实现第一条就 return false
        //     route get 1.1.1.1  → utun9   ← 真实公网流量喺呢度
        //     route get 8.8.8.8  → utun9
        // 旧实现把一个健康嘅 TUN 判成失败,连锁触发「持久化关 TUN → 兜底 → 断网」
        // 成条 bug 链嘅源头就係呢度。
        //
        // 新判据:睇真实公网目标行边个接口,再证明嗰个 utun 係易联自己嘅。
        final targets = await Future.wait([
          _macRouteInterface('1.1.1.1'),
          _macRouteInterface('8.8.8.8'),
        ]);
        final tunNames = targets
            .whereType<String>()
            .where((item) => item.startsWith('utun'))
            .toSet();
        if (tunNames.isEmpty) {
          commonPrint.log(
            '[TUN-DIAG] macOS route probe: 公网目标唔行 utun '
            'routes=${targets.map((item) => item ?? '-').join(',')}',
            logLevel: LogLevel.warning,
          );
          return false;
        }
        // handoff §5.3 要求「证明 utun 属于易联会话」:第三方(Tailscale 100.64/10、
        // 其他 VPN)一样开 utun,单睇接口名会认错。mihomo TUN 固定攞 198.18.0.0/30,
        // 用呢个 inet 地址做归属判据。
        for (final name in tunNames) {
          final ifconfig = await Process.run('ifconfig', [name]);
          final output = ifconfig.stdout.toString();
          final isUp =
              output.contains('UP') && !output.contains('status: inactive');
          final isOurs = output.contains('inet 198.18.');
          final probeLine = '[TUN-DIAG] macOS route probe interface=$name '
              'isUp=$isUp isOurs=$isOurs';
          if (!(isUp && isOurs) || _lastMacRouteProbeLine != probeLine) {
            commonPrint.log(
              probeLine,
              logLevel: isUp && isOurs ? LogLevel.info : LogLevel.warning,
            );
          }
          _lastMacRouteProbeLine = probeLine;
          if (isUp && isOurs) return true;
        }
        commonPrint.log(
          '[TUN-DIAG] macOS route probe: 公网流量行紧 ${tunNames.join(',')} '
          '但唔係易联嘅 TUN(198.18.x)',
          logLevel: LogLevel.warning,
        );
        return false;
      }
      if (isWindows) {
        // [0.9.96] 原本只睇「有冇 198.18 路由」—— 第三方 TUN(官方 FlClash / Clash Verge)都用 198.18,
        //   09-30 实测:官方 FlClash 占住网络、易联自己张网卡根本冇起,呢个判断照返 true ⇒ 绿灯「已连接」但上唔到网。
        //   而家要:① 见到易联自己张网卡(名 = appName,**或换名自愈后嘅 appName-2**,见 [isOurTunName])
        //          ② 冇第三方代理网卡同我哋抢。
        final ifaces = await NetworkInterface.list(includeLoopback: false);
        final ours = ifaces.any((i) => isOurTunName(i.name));
        if (!ours) return false;
        final other = foreignTunOwnerFromNames(ifaces.map((i) => i.name));
        if (other != null) {
          commonPrint.log(
            '[TUN-DIAG] windows: 易联网卡喺度,但「$other」嘅虚拟网卡都喺度(抢网络)',
            logLevel: LogLevel.warning,
          );
          return false;
        }
        return true;
      }
    } catch (e) {
      commonPrint.log(
        'desktop TUN probe failed: $e',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    return true;
  }

  Future<String?> _macRouteInterface(String destination) async {
    final result = await Process.run('route', ['-n', 'get', destination]);
    if (result.exitCode != 0) return null;
    final line = result.stdout
        .toString()
        .split('\n')
        .firstWhere(
          (item) => item.trim().startsWith('interface:'),
          orElse: () => '',
        );
    if (line.isEmpty) return null;
    final interfaceName = line.split(':').skip(1).join(':').trim();
    return interfaceName.isEmpty ? null : interfaceName;
  }

  /// Best-effort check that the desktop system proxy is actually enabled and
  /// points at this core's mixed port. The setting provider is only intent;
  /// this probes the OS state so a green connection cannot hide a failed
  /// networksetup/registry write.
  Future<bool> verifyDesktopSystemProxy(int port) async {
    if (!isDesktop) return true;
    try {
      if (isMacOS) {
        final result = await Process.run('/usr/sbin/scutil', ['--proxy']);
        if (result.exitCode != 0) return false;
        final output = result.stdout.toString();
        final enabled = RegExp(
          r'(HTTPEnable|HTTPSEnable|SOCKSEnable)\s*:\s*1',
        ).hasMatch(output);
        if (!enabled) return false;
        return RegExp(
          r'(HTTPPort|HTTPSPort|SOCKSPort)\s*:\s*' + port.toString(),
        ).hasMatch(output);
      }
      if (isWindows) {
        final base = [
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        ];
        final enabledResult = await Process.run('reg', [
          'query',
          ...base,
          '/v',
          'ProxyEnable',
        ]);
        final enabledOutput = enabledResult.stdout.toString().toLowerCase();
        if (enabledResult.exitCode != 0 || !enabledOutput.contains('0x1')) {
          return false;
        }
        final serverResult = await Process.run('reg', [
          'query',
          ...base,
          '/v',
          'ProxyServer',
        ]);
        final server = serverResult.stdout.toString().toLowerCase();
        return serverResult.exitCode == 0 &&
            (server.contains(':$port') || server.contains(port.toString()));
      }
    } catch (e) {
      commonPrint.log(
        'desktop system proxy probe failed: $e',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    return true;
  }

  Future<void> back() async {
    await app?.moveTaskToBack();
    await window?.hide();
  }

  Future<void> exit() async {
    if (system.isAndroid) {
      await SystemNavigator.pop();
    }
    await window?.close();
    window?.forceExit();
  }
}

final system = System();

class Windows {
  static Windows? _instance;
  late DynamicLibrary _shell32;

  Windows._internal() {
    _shell32 = DynamicLibrary.open('shell32.dll');
  }

  factory Windows() {
    _instance ??= Windows._internal();
    return _instance!;
  }

  bool runas(String command, String arguments) {
    final commandPtr = command.toNativeUtf16();
    final argumentsPtr = arguments.toNativeUtf16();
    final operationPtr = 'runas'.toNativeUtf16();

    final shellExecute = _shell32
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            Int32 nShowCmd,
          ),
          int Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            int nShowCmd,
          )
        >('ShellExecuteW');

    final result = shellExecute(
      nullptr,
      operationPtr,
      commandPtr,
      argumentsPtr,
      nullptr,
      1,
    );

    calloc.free(commandPtr);
    calloc.free(argumentsPtr);
    calloc.free(operationPtr);

    commonPrint.log(
      'windows runas: $command $arguments resultCode:$result',
      logLevel: LogLevel.warning,
    );

    if (result <= 32) {
      return false;
    }
    return true;
  }

  // Future<void> _killProcess(int port) async {
  //   final result = await Process.run('netstat', ['-ano']);
  //   final lines = result.stdout.toString().trim().split('\n');
  //   for (final line in lines) {
  //     if (!line.contains(':$port') || !line.contains('LISTENING')) {
  //       continue;
  //     }
  //     final parts = line.trim().split(RegExp(r'\s+'));
  //     final pid = int.tryParse(parts.last);
  //     if (pid != null) {
  //      await Process.run('taskkill', ['/PID', pid.toString(), '/F']);
  //     }
  //   }
  // }

  Future<WindowsHelperServiceStatus> checkService() async {
    // final qcResult = await Process.run('sc', ['qc', appHelperService]);
    // final qcOutput = qcResult.stdout.toString();
    // if (qcResult.exitCode != 0 || !qcOutput.contains(appPath.helperPath)) {
    //   return WindowsHelperServiceStatus.none;
    // }
    final result = await Process.run('sc', ['query', appHelperService]);
    if (result.exitCode != 0) {
      return WindowsHelperServiceStatus.none;
    }
    final output = result.stdout.toString();
    if (output.contains('RUNNING') && await request.pingHelper()) {
      return WindowsHelperServiceStatus.running;
    }
    return WindowsHelperServiceStatus.presence;
  }

  Future<bool> registerService() async {
    final status = await checkService();

    if (status == WindowsHelperServiceStatus.running) {
      return true;
    }

    final command = [
      '/c',
      if (status == WindowsHelperServiceStatus.presence) ...[
        'taskkill',
        '/F',
        '/IM',
        '$appHelperService.exe'
            ' & '
            'sc',
        'delete',
        appHelperService,
        '&',
      ],
      'sc',
      'create',
      appHelperService,
      'binPath= "${appPath.helperPath}"',
      'start= auto',
      '&&',
      'sc',
      'start',
      appHelperService,
    ].join(' ');

    final res = runas('cmd.exe', command);

    await Future.delayed(const Duration(milliseconds: 300));
    // ⚠️ 重试要够耐心(2026-08-10 由 5 次 × 1s 加到 15 次 × 1s):
    // 上面嘅 `sc delete` + `sc create` 有个 Windows 经典坑 —— 若旧 helper 进程係被强杀
    // (例如安装器 taskkill /f),`sc delete` 会令服务变成 "marked for deletion",
    // 同名 `sc create` 就会失败(error 1072),要等 SCM 释放晒句柄先得。
    // 旧嘅 5 秒窗口远远唔够 → helper 起唔到 → TUN 建唔起 → 用户以为新版坏咗。
    // 治本喺安装器嗰边(装之前 sc stop + sc delete 干净收场,见 inno_setup.iss);
    // 呢度加长重试係第二道保险,畀 SCM 时间收场,唔好一失败就摆烂。
    final retryStatus = await retry(
      task: checkService,
      maxAttempts: 15,
      retryIf: (status) => status != WindowsHelperServiceStatus.running,
      delay: const Duration(seconds: 1),
    );
    return res && retryStatus == WindowsHelperServiceStatus.running;
  }

  Future<bool> registerTask(String appName) async {
    final taskXml =
        '''
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Triggers>
    <LogonTrigger/>
  </Triggers>
  <Settings>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>"${Platform.resolvedExecutable}"</Command>
    </Exec>
  </Actions>
</Task>''';
    final taskPath = join(await appPath.tempPath, 'task.xml');
    await File(taskPath).create(recursive: true);
    await File(
      taskPath,
    ).writeAsBytes(taskXml.encodeUtf16LeWithBom, flush: true);
    final commandLine = [
      '/Create',
      '/TN',
      appName,
      '/XML',
      '%s',
      '/F',
    ].join(' ');
    return runas('schtasks', commandLine.replaceFirst('%s', taskPath));
  }
}

final windows = system.isWindows ? Windows() : null;

class MacOS {
  static MacOS? _instance;

  List<String>? originDns;
  String? originDnsServiceName;
  bool dnsAppendedByVoguesly = false;
  Future<void> _dnsOperation = Future<void>.value();

  MacOS._internal();

  factory MacOS() {
    _instance ??= MacOS._internal();
    return _instance!;
  }

  Future<String?> get defaultServiceName async {
    final result = await Process.run('route', ['-n', 'get', 'default']);
    final output = result.stdout.toString();
    final deviceLine = output
        .split('\n')
        .firstWhere((s) => s.contains('interface:'), orElse: () => '');
    final lineSplits = deviceLine.trim().split(' ');
    if (lineSplits.length != 2) {
      return null;
    }
    final device = lineSplits[1];
    final serviceResult = await Process.run('networksetup', [
      '-listnetworkserviceorder',
    ]);
    final serviceResultOutput = serviceResult.stdout.toString();
    final currentService = serviceResultOutput
        .split('\n\n')
        .firstWhere((s) => s.contains('Device: $device'), orElse: () => '');
    if (currentService.isEmpty) {
      return null;
    }
    final currentServiceNameLine = currentService
        .split('\n')
        .firstWhere(
          (line) => RegExp(r'^\(\d+\).*').hasMatch(line),
          orElse: () => '',
        );
    final currentServiceNameLineSplits = currentServiceNameLine.trim().split(
      ' ',
    );
    if (currentServiceNameLineSplits.length < 2) {
      return null;
    }
    return currentServiceNameLineSplits[1];
  }

  Future<List<String>?> _readDns(String serviceName) async {
    final result = await Process.run('networksetup', [
      '-getdnsservers',
      serviceName,
    ]);
    final output = result.stdout.toString().trim();
    if (output.startsWith("There aren't any DNS Servers set on")) {
      return [];
    }
    if (result.exitCode != 0 || output.isEmpty) return null;
    return output.split('\n');
  }

  Future<List<String>?> get systemDns async {
    final serviceName = await defaultServiceName;
    if (serviceName == null) return null;
    return _readDns(serviceName);
  }

  Future<void> updateDns(bool restore) {
    // AppStateManager 的监听不会阻塞 UI；串行化 enable/restore，避免用户
    // 快速开关 TUN 时 restore 先于 append 或反过来执行。
    _dnsOperation = _dnsOperation.then((_) => _updateDns(restore));
    return _dnsOperation;
  }

  Future<void> _updateDns(bool restore) async {
    final serviceName = await defaultServiceName;
    if (serviceName == null) return;
    late List<String> nextDns;
    if (restore) {
      // 只撤销本次由易联追加的 223.5.5.5。用户在 TUN 运行期间手动改过
      // 其他 DNS 时，不要用旧快照覆盖那些改动。
      if (!dnsAppendedByVoguesly ||
          originDnsServiceName != serviceName ||
          originDns == null) {
        return;
      }
      final currentDns = await _readDns(serviceName);
      if (currentDns == null || !currentDns.contains('223.5.5.5')) {
        dnsAppendedByVoguesly = false;
        originDns = null;
        originDnsServiceName = null;
        return;
      }
      nextDns = currentDns.where((dns) => dns != '223.5.5.5').toList();
    } else {
      // 同一轮 TUN 生命周期只保存一次原始 DNS。旧实现每次启动都会刷新
      // originDns，第二次启动时会把已追加的 223.5.5.5 误存成“原始值”。
      if (originDns == null || originDnsServiceName != serviceName) {
        originDns = await _readDns(serviceName);
        originDnsServiceName = serviceName;
      }
      final currentDns = await _readDns(serviceName);
      if (currentDns == null) return;
      const needAddDns = '223.5.5.5';
      if (currentDns.contains(needAddDns)) {
        return;
      }
      nextDns = List.from(currentDns)..add(needAddDns);
    }
    final result = await Process.run('networksetup', [
      '-setdnsservers',
      serviceName,
      if (nextDns.isNotEmpty) ...nextDns,
      if (nextDns.isEmpty) 'Empty',
    ]);
    if (result.exitCode != 0) return;
    if (restore) {
      dnsAppendedByVoguesly = false;
      originDns = null;
      originDnsServiceName = null;
    } else {
      dnsAppendedByVoguesly = true;
    }
  }
}

final macOS = system.isMacOS ? MacOS() : null;


/// [0.9.96] 畀用户睇嘅产品名:去走「(服务模式)」呢类诊断后缀。
/// 09-30 实测:Verge 开 TUN 时 tasklist 第一个係 clash-verge-service.exe ⇒ 弹框写「请先退出「Clash Verge(服务模式)」」
/// 同「重新打开「Clash Verge(服务模式)」」,用户根本冇得「打开」一个服务。诊断报告仍然用完整名。
String userFacingProxyName(String name) => name.replaceAll(RegExp(r'\s*[（(]服务模式[)）]$'), '');

/// [0.9.100] 呢个网卡名係咪「易联自己」嘅。
///
/// 🔴 点解唔可以只认 [appName]:内核 Windows 侧有一条**换名自愈**
/// (Clash.Meta `listener/sing_tun/fallback.go` ⇒ `fallbackTunName(name) = name + "-2"`):
/// 原网卡名撞到 wintun「找不到文件」错、且单次创建耗时 ≥10 秒时,内核会改用 `原名-2` 重建。
/// **呢个时候网卡其实已经建好、流量照走**,但 Dart 侧如果只认 `appName`,就会漏认 ⇒
/// 判「TUN 冇起到」⇒ 触发 `controlled core/TUN recovery` ⇒ 内核重启 ⇒ 再判错 ⇒ 死循环。
/// (2026-10-13 uid 44 工单 #39 日志实证:`desktop transport ok=false` 反复 + `CORE-RECOVER`。)
///
/// ⚠️ **只收内核真实会产生嘅后缀**(目前唯一:`-2`),唔可以用 `startsWith('$appName-')` ——
/// 咁样会连 `易联 voguesly-随便咩名` 都当自己,增加把残留 / 人为改名网卡认作本次会话嘅风险。Codex 2026-10-13 审计意见。
bool isOurTunName(String raw) {
  final name = raw.trim();
  return name == appName || name == '$appName-2' || name == kLinuxTunDevice;
}

/// [0.9.96] 由网卡名认出第三方代理软件嘅虚拟网卡(Windows 网卡「名称」,即 Get-NetAdapter 嘅 Name)。
/// 易联自己张叫 [appName],永远唔算。「Meta」/「Mihomo」係 mihomo 内核默认名,多个软件共用 ⇒ 返通用名,由调用方再按进程细分。
/// ⚠️ 只认代理软件嘅网卡,唔好将公司 VPN / WireGuard 等当冲突(佢哋名由用户自定,冇固定特征)。
String? foreignTunOwnerFromNames(Iterable<String> names) {
  for (final raw in names) {
    final name = raw.trim();
    // 易联自己:Windows 网卡叫 appName(**或换名自愈后嘅 appName-2**);Linux 叫 kLinuxTunDevice。
    if (name.isEmpty || isOurTunName(name)) continue;
    final n = name.toLowerCase();
    if (n == 'flclash' || n.startsWith('flclash')) return 'FlClash(官方版)';
    if (n == 'meta' || n.startsWith('mihomo') || n == 'clash' || n.startsWith('clash')) return 'Clash 类代理软件';
    if (n.contains('sing-box') || n.contains('singbox') || n.contains('sing_box')) return 'sing-box';
    if (n.contains('hiddify')) return 'Hiddify';
    if (n.contains('nekoray') || n.contains('nekobox')) return 'NekoBox';
    if (n.contains('karing')) return 'Karing';
    if (n.contains('xray_tun') || n.contains('v2rayn')) return 'v2rayN';
  }
  return null;
}

/// [0.9.96 Mac] 由 `scutil --nc list` 揾出「已连接」嘅系统 VPN(Shadowrocket / Surge / Stash / SFM 呢类 NetworkExtension)。
/// ⚠️ 呢类 VPN 退出 App 之后仍然连住(09-30 实测 Shadowrocket:App 退出后 MacPacketTunnel 照跑、流量照行佢)⇒ 要叫用户关 VPN 开关。
/// Tailscale / ZeroTier 係组网工具,长期连住但唔接管公网流量,唔当冲突。
List<String> macConnectedVpnNames(String scutilNcList) {
  final found = <String>[];
  for (final line in scutilNcList.split('\n')) {
    if (!line.contains('(Connected)')) continue;
    final lower = line.toLowerCase();
    if (lower.contains('tailscale') || lower.contains('zerotier')) continue;
    final name = RegExp(r'"([^"]+)"').firstMatch(line)?.group(1)?.trim();
    if (name != null && name.isNotEmpty && !found.contains(name)) found.add(name);
  }
  return found;
}

/// [0.9.96 Mac] 由 `ps -axo comm=`(macOS 返完整路径)揾出正在跑嘅第三方代理**内核**,返产品名(去重)。
/// 只认真正会开 TUN 嘅内核进程;常驻服务 / helper(clash-verge-service、com.follow.clash.tunhelper)
/// 装咗就一直喺度,唔代表佢占住网络 —— 旧逻辑就係被 clash-verge-service 骗到,乜都报「请先退出 Clash Verge」。
/// [vergeTunOn]:Clash Verge 设置入面「虚拟网卡模式」开关(读唔到传 null ⇒ 只要内核喺度就算)。
List<String> macTunCoreOwners(String psOutput, {bool? vergeTunOn}) {
  final found = <String>[];
  void add(String name) {
    if (!found.contains(name)) found.add(name);
  }

  for (final raw in psOutput.split('\n')) {
    final p = raw.trim().toLowerCase();
    if (p.isEmpty) continue;
    if (p.contains('voguesly')) continue; // 易联自己(核心喺 com.voguesly.app/FlClashCore)
    if (p.contains('clash-verge-service') || p.contains('tunhelper')) continue;
    final base = p.split('/').last;
    if (base == 'verge-mihomo' || base == 'verge-mihomo-alpha') {
      if (vergeTunOn != false) add('Clash Verge');
    } else if (p.contains('/flclash.app/') && base == 'flclashcore') {
      add('FlClash(官方版)');
    } else if (p.contains('clash party') || p.contains('mihomo party') || p.contains('mihomo-party')) {
      add('Clash Party');
    } else if (p.contains('clashx')) {
      add('ClashX');
    } else if (p.contains('hiddify')) {
      add('Hiddify');
    } else if (p.contains('karing')) {
      add('Karing');
    } else if (p.contains('nekoray') || p.contains('nekobox')) {
      add('NekoBox');
    } else if (p.contains('v2rayn')) {
      add('v2rayN');
    } else if (base == 'sing-box') {
      add('sing-box');
    } else if (base == 'mihomo' || base == 'clash-meta') {
      add('Clash 类代理软件');
    }
  }
  return found;
}

/// [2026-09-29] 由进程列表(Windows `tasklist /FO CSV /NH` 或 `ps -axo comm=`)揾出其他代理软件,返产品名(去重)。
/// 用「完整进程名」对比,唔用子串:易联自己嘅核心叫 FlClashCore,唔可以被当成官方 FlClash。
List<String> matchOtherProxyProcesses(String output, {required bool windows}) {
  const known = <String, String>{
    'verge-mihomo': 'Clash Verge',
    'verge-mihomo-alpha': 'Clash Verge',
    'clash-verge': 'Clash Verge',
    'clash verge': 'Clash Verge',
    'clash-verge-service': 'Clash Verge(服务模式)',
    'clash for windows': 'Clash for Windows',
    'clash-win64': 'Clash for Windows',
    'clash-meta': 'Clash Meta',
    'mihomo': 'Clash Meta(mihomo)',
    'mihomo-party': 'Mihomo Party',
    'v2rayn': 'v2rayN',
    'xray': 'v2rayN / Xray',
    'v2ray': 'V2Ray',
    'nekoray': 'NekoBox',
    'nekobox': 'NekoBox',
    'hiddify': 'Hiddify',
    'hiddifycli': 'Hiddify',
    'karing': 'Karing',
    'flclash': 'FlClash(官方版)',
    'sing-box': 'sing-box',
    'clashx': 'ClashX',
    'clashx meta': 'ClashX Meta',
    'surge': 'Surge',
    'shadowrocket': 'Shadowrocket',
    'stash': 'Stash',
    'quantumult x': 'Quantumult X',
    'daed': 'daed',
  };
  final hits = <String>{};
  for (final raw in output.split(RegExp(r'\r?\n'))) {
    var name = raw.trim();
    if (name.isEmpty) continue;
    if (windows) {
      final m = RegExp(r'^"([^"]+)"').firstMatch(name);
      if (m == null) continue;
      name = m.group(1)!;
    } else {
      name = name.split('/').last;
    }
    name = name.toLowerCase();
    if (name.endsWith('.exe')) name = name.substring(0, name.length - 4);
    // [0.9.96 Mac] Mac / Linux 嘅 clash-verge-service 只係装完就常驻嘅特权助手,Verge 退出咗佢都喺度 ⇒
    //   唔好报「Clash Verge 正在运行」(09-30 Air 实测:Verge 早就退出,软提示仍然话佢喺度)。
    //   Windows 嘅服务模式会令内核一直跑(09-29 客户个案),照报。
    if (!windows && name == 'clash-verge-service') continue;
    final hit = known[name];
    if (hit != null) hits.add(hit);
  }
  return hits.toList();
}
