import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';

import 'interface.dart';
import 'transport.dart';

/// 核心起咗但 IPC 一直冇连返嚟(逾时)。`CoreManager.onCrash` 靠呢个标识
/// 把「启动失败」同「运行中掉线」分开,畀唔同文案。
const kCoreStartTimeoutReason = 'core-start-timeout';

/// [0.9.89] 核心进程根本起唔到(`Process.start` 抛错)。以前同「运行中掉线」共用 'core done',
/// UI 分唔出,而家独立一个标识 ⇒ `CoreManager.onCrash` 畀「启动失败」文案。
const kCoreProcessStartFailedReason = 'core-process-start-failed';

/// 核心运行中意外断开(唔係我哋主动停)。技术标识,唔畀用户睇 —— UI 喺 onCrash 转中文。
const kCoreUnexpectedExitReason = 'core done';

/// Windows 硬杀核心之前,等核心自己关好虚拟网卡(ActionMethod.shutdown)的最长时间。
/// ⚠️ 不能比 2s 长:`SystemAction.handleExit` 有个 3s 后强制 `system.exit()` 的兜底,
/// 核心卡死时「优雅等待 + helper /stop」必须赶在它之前,否则 App 先退、核心变孤儿。
const kCoreGracefulStopTimeout = Duration(seconds: 2);

/// [0.9.89] 断线係咪我哋主动停核心引起(10 秒内)。抽出嚟方便单测。
bool isIntentionalCoreDisconnect(DateTime? stopAt, DateTime now) =>
    stopAt != null && now.difference(stopAt) < const Duration(seconds: 10);

class CoreService extends CoreHandlerInterface {
  static CoreService? _instance;

  late final IPCCoreTransport _transport;

  Completer<bool> _shutdownCompleter = Completer();

  final Map<String, Completer> _callbackCompleterMap = {};

  Process? _process;
  final AsyncLock _lifecycleLock = AsyncLock();

  /// [0.9.89] 我哋**主动**停核心嘅时间(启动时接管旧核心、切增强 / 兼容、用户断开)。
  /// 停核心 ⇒ Rust 侧会回一个断线帧 ⇒ onDisconnect。0.9.87 起 onCrash 唔再早退,
  /// 呢类「自己停自己」嘅断线被当成崩溃,弹咗英文「core done」(Sam 09-24 实机见到)。
  /// 10 秒内嘅断线当主动,唔报;过咗 10 秒仍然当意外(防止标记永远吞咗真崩溃)。
  DateTime? _intentionalStopAt;
  Future<void>? _startFuture;

  factory CoreService() {
    _instance ??= CoreService._internal();
    return _instance!;
  }

  CoreService._internal() {
    _transport = IPCCoreTransport(
      address: system.isWindows ? windowsPipeName : unixSocketPath,
    );
    _initServer();
  }

  Future<void> handleResult(ActionResult result) async {
    final completer = _callbackCompleterMap[result.id];
    final data = await parasResult(result);
    if (result.id?.isEmpty == true) {
      coreEventManager.sendEvent(CoreEvent.fromJson(result.data));
    }
    if (completer?.isCompleted == true) {
      return;
    }
    completer?.complete(data);
  }

  Future<void> _initServer() async {
    await _transport.init();

    _transport.onDisconnect = () {
      final stopAt = _intentionalStopAt;
      _intentionalStopAt = null;
      final intentional = isIntentionalCoreDisconnect(stopAt, DateTime.now());
      if (intentional) {
        commonPrint.log('Core disconnected after intentional stop (not a crash)');
      } else {
        commonPrint.log(
          'Core disconnected unexpectedly',
          logLevel: LogLevel.warning,
        );
        _handleInvokeCrashEvent();
      }
      if (!_shutdownCompleter.isCompleted) {
        _shutdownCompleter.complete(true);
      }
    };

    _transport.dataStream
        .transform(uint8ListToListIntConverter)
        .transform(utf8.decoder)
        .listen(
          (data) async {
            try {
              final dataJson = await data.trim().commonToJSON<dynamic>();
              handleResult(ActionResult.fromJson(dataJson));
            } catch (e) {
              commonPrint.log(
                'Failed to parse transport data: $e',
                logLevel: LogLevel.error,
              );
            }
          },
          onError: (error) {
            commonPrint.log(
              'Transport data stream error: $error',
              logLevel: LogLevel.error,
            );
          },
        );
  }

  /// [reason] 係**技术原因标识**(唔係畀用户睇嘅文案)。
  /// UI 文案喺 `CoreManager.onCrash` 转 —— core 层唔应该依赖 l10n。
  void _handleInvokeCrashEvent([String reason = kCoreUnexpectedExitReason]) {
    coreEventManager.sendEvent(
      CoreEvent(type: CoreEventType.crash, data: reason),
    );
  }

  Future<void> start() {
    final existing = _startFuture;
    if (existing != null) return existing;
    final future = _lifecycleLock.run(_startImpl);
    _startFuture = future;
    return future.whenComplete(() {
      if (identical(_startFuture, future)) _startFuture = null;
    });
  }

  Future<void> _startImpl() async {
    if (_process != null) {
      // A stale process after a crash must be torn down before the next start.
      // Concurrent callers are coalesced by _startFuture, so this does not
      // create a second helper/TUN cycle.
      await _shutdownImpl(false);
    }
    if (system.isWindows && await system.checkIsAdmin()) {
      final isSuccess = await request.startCoreByHelper(_transport.address);
      if (isSuccess) {
        // [2026-09-23] 逾时唔可以当成功 —— helper 报咗 success 唔代表核心真係连返嚟。
        if (!await _transport.waitConnected()) {
          commonPrint.log(
            'Core started by helper but never connected back within timeout',
            logLevel: LogLevel.error,
          );
          _handleInvokeCrashEvent(kCoreStartTimeoutReason);
        }
        return;
      }
    }
    // [TUN-DIAG] 核心启动前:打印核心路径 + 属主/权限位(看 setuid rws 有冇)。
    // 仅 macOS —— `stat -f` 是 BSD 格式,Linux 的 `stat -f` 语义不同、Windows 无 stat。
    if (system.isMacOS) {
      final corePathForStart = appPath.corePath;
      final statResult = await Process.run('stat', [
        '-f',
        '%Su:%Sg %Sp',
        corePathForStart,
      ]);
      commonPrint.log(
        '[TUN-DIAG] core start corePath=$corePathForStart '
        'stat="${statResult.stdout.toString().trim()}"',
        logLevel: LogLevel.info,
      );
    }
    try {
      _process = await Process.start(appPath.corePath, [_transport.address]);
    } catch (e) {
      commonPrint.log(
        'Failed to start core process: $e',
        logLevel: LogLevel.error,
      );
      _handleInvokeCrashEvent(kCoreProcessStartFailedReason);
      return;
    }
    _process?.stdout.listen((_) {});
    _process?.stderr.listen((e) {
      final error = utf8.decode(e);
      if (error.isNotEmpty) {
        commonPrint.log(error, logLevel: LogLevel.warning);
      }
    });
    // [2026-09-23] 🔴 原本係 `await _transport.connectionCompleter.future;`,冇逾时。
    //   `_completer` 喺断线时会被整个换走,呢度攞住嘅係旧引用 ⇒ **永久卡死**。
    //   实锤现场(Sam 部 Mac,0.9.85):核心进程活住、係 root、socket 连咗,但零监听埠、
    //   零 config(收唔到指令);App 一直转圈 39–53% CPU;而 isStart 已经 true ⇒
    //   http.dart 把所有请求掟去未监听嘅 mixedPort ⇒ 连订阅都更新唔到。
    //   ⇒ 改用 waitConnected()(读当前状态 + 广播 + 逾时),逾时就当启动失败,
    //     畀上层去 crash 处理 / 重试,唔好静静吊死。
    if (!await _transport.waitConnected()) {
      commonPrint.log(
        'Core process started but IPC never connected within timeout; '
        'treating as start failure',
        logLevel: LogLevel.error,
      );
      _process?.kill();
      _process = null;
      _handleInvokeCrashEvent(kCoreStartTimeoutReason);
    }
  }

  @override
  FutureOr<bool> destroy() async {
    await shutdown(false);
    await _transport.close();
    return true;
  }

  Future<void> sendMessage(String message) async {
    // [2026-09-23] 同上:唔可以无限等。核心断咗就唔好静静吊住调用方
    // (呢度吊住会令成个 UI 冇反应 —— 每一个核心指令都经呢度)。
    if (!await _transport.waitConnected()) {
      commonPrint.log(
        'Drop core message: IPC not connected',
        logLevel: LogLevel.warning,
      );
      return;
    }
    _transport.send(message);
  }

  @override
  Future<bool> shutdown(bool isUser) =>
      _lifecycleLock.run(() => _shutdownImpl(isUser));

  Future<bool> _shutdownImpl(bool isUser) async {
    _shutdownCompleter = Completer();
    // 只有真係有核心喺度先标记;冇核心就唔会有断线帧,标记会白白吞咗之后 10 秒嘅真崩溃。
    if (_process != null || _transport.isConnected) {
      _intentionalStopAt = DateTime.now();
    }
    if (system.isWindows) {
      // [2026-10-12] helper 的 /stop 是 TerminateProcess,核心来不及 tun.Close() →
      // WintunCloseAdapter,虚拟网卡设备节点留给内核/PnP 善后;客户日志里出现过之后同名网卡
      // 再也建不起来(15s 超时 + 「系统找不到指定的文件」)、只有重启 Windows 才恢复。
      // 所以硬杀之前先让核心自己收尾(ActionMethod.shutdown 会同步等到网卡关闭才返回)。
      // 带逾时、失败照旧硬杀:这里绝不能把 UI 卡住。
      if (_transport.isConnected) {
        await _gracefulStopCore();
      }
      await request.stopCoreByHelper();
    }
    _transport.disconnected();
    _process?.kill();
    _process = null;
    _clearCompleter();
    if (isUser) {
      return _shutdownCompleter.future;
    } else {
      return true;
    }
  }

  Future<void> _gracefulStopCore() async {
    try {
      final done = await invoke<bool>(
        method: ActionMethod.shutdown,
        timeout: kCoreGracefulStopTimeout,
      );
      if (done != true) {
        commonPrint.log(
          'Core graceful shutdown did not confirm within '
          '${kCoreGracefulStopTimeout.inSeconds}s; falling back to hard stop',
          logLevel: LogLevel.warning,
        );
      }
    } catch (e) {
      commonPrint.log(
        'Core graceful shutdown failed: $e; falling back to hard stop',
        logLevel: LogLevel.warning,
      );
    }
  }

  void _clearCompleter() {
    for (final completer in _callbackCompleterMap.values) {
      completer.safeCompleter(null);
    }
  }

  @override
  Future<String> preload() async {
    await start();
    return '';
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    final id = '${method.name}#${utils.id}';
    _callbackCompleterMap[id] = Completer<T?>();
    sendMessage(json.encode(Action(id: id, method: method, data: data)));
    return (_callbackCompleterMap[id] as Completer<T?>).future.withTimeout(
      timeout: timeout,
      onLast: () {
        final completer = _callbackCompleterMap[id];
        completer?.safeCompleter(null);
        _callbackCompleterMap.remove(id);
      },
      tag: id,
      onTimeout: () => null,
    );
  }

  @override
  Completer get completer => _transport.connectionCompleter;
}

final coreService = system.isDesktop ? CoreService() : null;
