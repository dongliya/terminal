import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:terminal/src/models/ssh_connection.dart';
import 'package:terminal/src/rust/api/ssh.dart';
import 'package:xterm/xterm.dart';

const bool _showDebugLogs = !kReleaseMode;

class TerminalSessionController extends ChangeNotifier {
  TerminalSessionController({required this.connection}) {
    viewController = TerminalController()..addListener(_handleViewChanged);
    terminal = _createTerminal();
    unawaited(_connect());
  }

  static const Duration _activePollInterval = Duration(milliseconds: 120);
  static const Duration _inactivePollInterval = Duration(milliseconds: 700);

  final SshConnection connection;
  final List<String> connectionLogs = <String>[];
  late Terminal terminal;
  late final TerminalController viewController;
  final ValueNotifier<SessionStatus?> statusNotifier =
      ValueNotifier<SessionStatus?>(null);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int> logsRevision = ValueNotifier<int>(0);
  final ValueNotifier<bool> selectionNotifier = ValueNotifier<bool>(false);

  int? _sessionId;
  Timer? _pollTimer;
  SessionStatus? _status;
  bool _polling = false;
  bool _connectedBannerShown = false;
  int _pollCounter = 0;
  bool _pollStartedLogged = false;
  bool _firstStatusLogged = false;
  String? _connectionError;
  bool _isActive = true;
  bool _isDisposed = false;
  bool _resizeSuspended = false;
  int? _lastCols;
  int? _lastRows;
  bool _retryInFlight = false;
  int _connectionGeneration = 0;

  SessionStatus? get status => _status;
  String? get connectionError => _connectionError;
  bool get isConnected =>
      _status?.phase == SessionPhase.connected && _connectionError == null;
  bool get isRetrying => _retryInFlight;
  bool get isConnecting =>
      _status?.phase == SessionPhase.connecting ||
      _status?.phase == SessionPhase.authenticating;
  bool get canRetry {
    if (_retryInFlight) {
      return false;
    }
    return switch (_status?.phase) {
      null || SessionPhase.disconnected || SessionPhase.error => true,
      SessionPhase.connecting || SessionPhase.authenticating => false,
      SessionPhase.connected => true,
    };
  }
  bool get hasSelection => selectionNotifier.value;
  String? get selectedText {
    final selection = viewController.selection;
    if (selection == null) {
      return null;
    }
    return terminal.buffer.getText(selection);
  }

  void setActive(bool isActive) {
    if (_isActive == isActive || _isDisposed) {
      return;
    }
    _isActive = isActive;
    _startPolling();
  }

  Future<void> retryConnection() async {
    if (_retryInFlight || _isDisposed) {
      return;
    }
    _retryInFlight = true;
    notifyListeners();

    final sessionId = _sessionId;
    if (sessionId != null) {
      try {
        sshDisconnect(sessionId: sessionId);
      } catch (_) {}
      sshDisposeSession(sessionId: sessionId);
    }
    _sessionId = null;
    _pollTimer?.cancel();
    _polling = false;
    _connectedBannerShown = false;
    _pollCounter = 0;
    _pollStartedLogged = false;
    _firstStatusLogged = false;
    connectionLogs.clear();
    _touchLogs();
    clearSelection();
    terminal = _createTerminal();
    _setConnectionError(null);
    _setStatus(
      const SessionStatus(
        phase: SessionPhase.connecting,
        message: 'Retrying connection',
      ),
    );
    try {
      await _connect();
    } finally {
      _retryInFlight = false;
      notifyListeners();
    }
  }

  void sendInput(String data) {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    try {
      sshSendInput(sessionId: sessionId, input: data);
    } catch (_) {}
  }

  void pasteText(String text) {
    if (text.isEmpty) {
      return;
    }
    terminal.paste(text);
    clearSelection();
  }

  void clearSelection() {
    if (viewController.selection != null) {
      viewController.clearSelection();
    }
  }

  void clearLogs() {
    if (connectionLogs.isEmpty) {
      return;
    }
    connectionLogs.clear();
    _touchLogs();
  }

  void clearTerminalViewport() {
    clearSelection();
    terminal.buffer.clear();
    terminal.setCursor(0, 0);
    terminal.notifyListeners();
  }

  void setResizeSuspended(bool suspended) {
    if (_resizeSuspended == suspended) {
      return;
    }
    _resizeSuspended = suspended;
    if (!suspended) {
      _flushResize();
    }
  }

  Future<void> disconnect() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      try {
        _appendLog('Disconnect requested');
        sshDisconnect(sessionId: sessionId);
      } catch (_) {}
      sshDisposeSession(sessionId: sessionId);
      _sessionId = null;
    }
    _pollTimer?.cancel();
    _setStatus(
      const SessionStatus(
        phase: SessionPhase.disconnected,
        message: 'Disconnected',
      ),
    );
  }

  Future<void> _connect() async {
    final generation = ++_connectionGeneration;
    final sessionId = createSshSession();
    _sessionId = sessionId;
    _appendLog('Starting connection workflow');
    _appendLog('Rust session handle created');
    _setStatus(
      const SessionStatus(
        phase: SessionPhase.connecting,
        message: 'Starting connection',
      ),
    );
    _setConnectionError(null);
    _startPolling();

    try {
      _appendLog('Calling Rust sshConnect(...)');
      await sshConnect(
        sessionId: sessionId,
        config: SshConfig(
          host: connection.host,
          port: connection.port,
          username: connection.username,
          password: connection.password,
          privateKey: connection.privateKey,
        ),
        cols: terminal.viewWidth,
        rows: terminal.viewHeight,
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Rust sshConnect() did not return in time');
        },
      );
      if (!_isCurrentAttempt(generation, sessionId)) {
        return;
      }
      _appendLog('Rust sshConnect(...) returned');
    } catch (error) {
      if (!_isCurrentAttempt(generation, sessionId)) {
        return;
      }
      _appendLog('Connect call failed: $error');
      terminal.write('\r\n[connect failed] $error\r\n');
      _setConnectionError(error.toString());
      _setStatus(
        SessionStatus(phase: SessionPhase.error, message: error.toString()),
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final interval = _isActive ? _activePollInterval : _inactivePollInterval;
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_pollSession());
    });
  }

  Future<void> _pollSession() async {
    if (_polling || _isDisposed) {
      return;
    }

    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    final generation = _connectionGeneration;

    _polling = true;
    try {
      _pollCounter += 1;
      if (!_pollStartedLogged) {
        _pollStartedLogged = true;
        _appendLog('Polling loop started');
      }

      if (_pollCounter == 1) {
        _appendLog('Reading Rust output queue');
      }
      final chunks = sshReadOutput(sessionId: sessionId);
      if (_pollCounter == 1) {
        _appendLog('Rust output queue returned ${chunks.length} chunk(s)');
      }
      for (final chunk in chunks) {
        terminal.write(chunk.data);
        _captureVisibleLogs(chunk);
      }

      if (_pollCounter == 1) {
        _appendLog('Reading Rust session status');
      }
      final nextStatus = sshGetStatus(sessionId: sessionId);
      if (!_isCurrentAttempt(generation, sessionId)) {
        return;
      }
      if (!_firstStatusLogged) {
        _firstStatusLogged = true;
        _appendLog(
          'First Rust status: ${nextStatus.phase.name}${nextStatus.message == null ? '' : ' - ${nextStatus.message}'}',
        );
      }

      if (!_connectedBannerShown &&
          nextStatus.phase == SessionPhase.connected) {
        _connectedBannerShown = true;
        _setConnectionError(null);
        _appendLog('Remote shell is ready');
      }

      _setStatus(nextStatus);
      if (nextStatus.phase == SessionPhase.error) {
        _setConnectionError(nextStatus.message);
      }
    } catch (error) {
      if (!_isCurrentAttempt(generation, sessionId)) {
        return;
      }
      _appendLog('Polling failed: $error');
      _setConnectionError(error.toString());
      _setStatus(
        SessionStatus(phase: SessionPhase.error, message: error.toString()),
      );
    } finally {
      _polling = false;
    }
  }

  void _appendLog(String message) {
    if (!_showDebugLogs) {
      return;
    }
    connectionLogs.add('[${DateTime.now().toIso8601String()}] $message');
    _touchLogs();
  }

  void _captureVisibleLogs(TerminalChunk chunk) {
    final normalized = chunk.data.replaceAll('\r', '');
    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('[step]') ||
          line.startsWith('[error]') ||
          line.startsWith('[ready]') ||
          line.startsWith('[connecting]')) {
        _appendLog(line);
      }
    }
  }

  Terminal _createTerminal() {
    final nextTerminal = Terminal(maxLines: 5000);
    nextTerminal.onOutput = sendInput;
    nextTerminal.onResize = (width, height, _, _) {
      _lastCols = width;
      _lastRows = height;
      if (_resizeSuspended) {
        return;
      }
      final sessionId = _sessionId;
      if (sessionId == null) {
        return;
      }
      try {
        sshResize(sessionId: sessionId, cols: width, rows: height);
      } catch (_) {}
    };
    selectionNotifier.value = false;
    return nextTerminal;
  }

  void _handleViewChanged() {
    final hasSelection = viewController.selection != null;
    if (selectionNotifier.value != hasSelection) {
      selectionNotifier.value = hasSelection;
    }
  }

  void _setStatus(SessionStatus? status) {
    _status = status;
    statusNotifier.value = status;
  }

  void _setConnectionError(String? error) {
    _connectionError = error;
    errorNotifier.value = error;
  }

  void _touchLogs() {
    logsRevision.value += 1;
  }

  void _flushResize() {
    final sessionId = _sessionId;
    final cols = _lastCols;
    final rows = _lastRows;
    if (sessionId == null || cols == null || rows == null) {
      return;
    }
    try {
      sshResize(sessionId: sessionId, cols: cols, rows: rows);
    } catch (_) {}
  }

  bool _isCurrentAttempt(int generation, int sessionId) =>
      !_isDisposed &&
      generation == _connectionGeneration &&
      sessionId == _sessionId;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollTimer?.cancel();
    viewController
      ..removeListener(_handleViewChanged)
      ..dispose();
    statusNotifier.dispose();
    errorNotifier.dispose();
    logsRevision.dispose();
    selectionNotifier.dispose();
    super.dispose();
  }
}
