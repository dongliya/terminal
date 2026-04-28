import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terminal/l10n/app_localizations.dart';
import 'package:terminal/src/rust/api/ssh.dart';
import 'package:terminal/src/services/terminal_session_controller.dart';
import 'package:xterm/xterm.dart';

const bool _showDebugLogs = !kReleaseMode;

class TerminalSessionPane extends StatefulWidget {
  const TerminalSessionPane({
    super.key,
    required this.controller,
    required this.isActive,
    this.onRequestClose,
    this.topSafeArea = false,
  });

  final TerminalSessionController controller;
  final bool isActive;
  final VoidCallback? onRequestClose;
  final bool topSafeArea;

  @override
  State<TerminalSessionPane> createState() => _TerminalSessionPaneState();
}

class _TerminalSessionPaneState extends State<TerminalSessionPane>
    with WidgetsBindingObserver {
  late final FocusNode _terminalFocusNode;
  bool _showLogPanel = true;
  bool _keyboardVisible = false;

  Listenable get _statusListenable => Listenable.merge(<Listenable>[
    widget.controller.statusNotifier,
    widget.controller.errorNotifier,
  ]);

  Listenable get _terminalUiListenable => Listenable.merge(<Listenable>[
    widget.controller,
    widget.controller.statusNotifier,
    widget.controller.errorNotifier,
    widget.controller.selectionNotifier,
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _terminalFocusNode = FocusNode(debugLabel: 'terminal_focus');
    widget.controller.setActive(widget.isActive);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateKeyboardVisibility(MediaQuery.of(context).viewInsets.bottom > 0);
  }

  @override
  void didChangeMetrics() {
    final view = View.maybeOf(context);
    if (view == null) {
      return;
    }
    _updateKeyboardVisibility(view.viewInsets.bottom > 0);
  }

  @override
  void didUpdateWidget(covariant TerminalSessionPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.setResizeSuspended(false);
      widget.controller.setActive(widget.isActive);
      widget.controller.setResizeSuspended(_keyboardVisible);
    }
    if (oldWidget.isActive != widget.isActive) {
      widget.controller.setActive(widget.isActive);
      if (widget.isActive) {
        _refocusTerminal();
      }
    }
  }

  Future<void> _disconnect() async {
    await widget.controller.disconnect();
    if (mounted) {
      widget.onRequestClose?.call();
    }
  }

  Future<void> _copySelection() async {
    final text = widget.controller.selectedText;
    if (text == null || text.isEmpty) {
      return;
    }
    final localizations = MaterialLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    widget.controller.clearSelection();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(localizations.copyButtonLabel),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final localizations = MaterialLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    widget.controller.pasteText(text);
    _refocusTerminal();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(localizations.pasteButtonLabel),
      ),
    );
  }

  void _copyLogs() {
    if (!_showDebugLogs) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(
      ClipboardData(text: widget.controller.connectionLogs.join('\n')),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(l10n.connectionLogsCopied),
      ),
    );
  }

  void _clearTerminalScreen() {
    final l10n = AppLocalizations.of(context)!;
    widget.controller.clearTerminalViewport();
    widget.controller.clearLogs();
    widget.controller.sendInput('\x0c');
    _refocusTerminal();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(l10n.terminalCleared),
      ),
    );
  }

  void _refocusTerminal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) {
        _terminalFocusNode.requestFocus();
      }
    });
  }

  void _showKeys() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _keyChip('Ctrl+C', '\u0003'),
              _keyChip('Ctrl+D', '\u0004'),
              _keyChip('Ctrl+Z', '\u001A'),
              _keyChip('Tab', '\t'),
              _keyChip('Esc', '\u001B'),
              _keyChip('Up', '\u001B[A'),
              _keyChip('Down', '\u001B[B'),
              _keyChip('Left', '\u001B[D'),
              _keyChip('Right', '\u001B[C'),
              _keyChip('Home', '\u001B[H'),
              _keyChip('End', '\u001B[F'),
            ],
          ),
        );
      },
    );
  }

  void _updateKeyboardVisibility(bool visible) {
    if (_keyboardVisible == visible) {
      return;
    }
    _keyboardVisible = visible;
    widget.controller.setResizeSuspended(visible);
  }

  Widget _keyChip(String label, String value) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        Navigator.of(context).pop();
        widget.controller.sendInput(value);
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.setResizeSuspended(false);
    _terminalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;

    return Column(
      children: <Widget>[
        Material(
          color: const Color(0xFF10161E),
          child: SafeArea(
            top: widget.topSafeArea,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _statusListenable,
                      builder: (context, _) {
                        final status = controller.status;
                        final statusColor = switch (status?.phase) {
                          SessionPhase.connected => const Color(0xFF22C55E),
                          SessionPhase.error => const Color(0xFFEF4444),
                          SessionPhase.authenticating => const Color(
                            0xFFF59E0B,
                          ),
                          _ => const Color(0xFF3B82F6),
                        };
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    controller.connection.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                if (status != null) ...<Widget>[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: statusColor.withValues(
                                          alpha: 0.22,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _statusLabel(status.phase),
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.78,
                                            ),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${controller.connection.username}@${controller.connection.host}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  _ToolbarButton(
                    onPressed: _showKeys,
                    icon: Icons.keyboard_command_key,
                    tooltip: l10n.specialKeys,
                  ),
                  _ToolbarButton(
                    onPressed: _pasteFromClipboard,
                    icon: Icons.content_paste_go_rounded,
                    tooltip: MaterialLocalizations.of(context).pasteButtonLabel,
                  ),
                  _ToolbarButton(
                    onPressed: _clearTerminalScreen,
                    icon: Icons.clear_all_outlined,
                    tooltip: l10n.clearScreen,
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[
                      widget.controller,
                      _statusListenable,
                    ]),
                    builder: (context, _) {
                      return _ToolbarButton(
                        onPressed: controller.canRetry
                            ? () {
                                unawaited(controller.retryConnection());
                              }
                            : null,
                        icon: Icons.refresh_rounded,
                        tooltip: l10n.retry,
                      );
                    },
                  ),
                  if (_showDebugLogs)
                    _ToolbarButton(
                      onPressed: _copyLogs,
                      icon: Icons.receipt_long_outlined,
                      tooltip: l10n.copyLogs,
                    ),
                  _ToolbarButton(
                    onPressed: _disconnect,
                    icon: Icons.close,
                    tooltip: l10n.disconnect,
                    danger: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _terminalUiListenable,
            builder: (context, _) {
              final status = controller.status;
              final connectionError = controller.connectionError;
              final hasSelection = controller.hasSelection;
              return Stack(
                children: <Widget>[
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFF10151C), Color(0xFF05070A)],
                      ),
                    ),
                    child: TerminalView(
                      controller.terminal,
                      key: ValueKey<Object>(controller.terminal),
                      controller: controller.viewController,
                      focusNode: _terminalFocusNode,
                      autofocus: widget.isActive,
                      backgroundOpacity: 0,
                      deleteDetection: true,
                      textStyle: const TerminalStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        height: 1.25,
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  if (status?.phase == SessionPhase.connecting ||
                      status?.phase == SessionPhase.authenticating)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              l10n.connectingProgress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (connectionError != null &&
                      status?.phase != SessionPhase.connecting &&
                      status?.phase != SessionPhase.authenticating)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.connectionFailed,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                connectionError,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: controller.canRetry
                                    ? () {
                                        unawaited(controller.retryConnection());
                                      }
                                    : null,
                                child: Text(l10n.retry),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (hasSelection)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FilledButton.icon(
                        onPressed: _copySelection,
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(
                          MaterialLocalizations.of(context).copyButtonLabel,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (_showDebugLogs)
          Material(
            color: const Color(0xFF0D131A),
            child: ListenableBuilder(
              listenable: controller.logsRevision,
              builder: (context, _) {
                final logs = controller.connectionLogs;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.bug_report_outlined),
                      title: Text(l10n.connectionLogs),
                      subtitle: Text(
                        logs.isEmpty
                            ? l10n.noLogsYet
                            : l10n.logLineCount(logs.length),
                      ),
                      trailing: IconButton(
                        onPressed: () {
                          setState(() {
                            _showLogPanel = !_showLogPanel;
                          });
                        },
                        icon: Icon(
                          _showLogPanel
                              ? Icons.expand_more_outlined
                              : Icons.expand_less_outlined,
                        ),
                      ),
                    ),
                    if (_showLogPanel)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF05070A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: logs.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(l10n.waitingForConnectionLogs),
                                  ),
                                )
                              : ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.all(12),
                                  itemCount: logs.length,
                                  itemBuilder: (context, index) {
                                    final line = logs[logs.length - 1 - index];
                                    final lineColor = line.contains('[error]')
                                        ? const Color(0xFFFF8F8F)
                                        : line.contains('[ready]')
                                        ? const Color(0xFF8FFFC1)
                                        : const Color(0xFFE2E8F0);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        line,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: Color(0xFFE2E8F0),
                                        ).copyWith(color: lineColor),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  String _statusLabel(SessionPhase phase) {
    final l10n = AppLocalizations.of(context)!;
    return switch (phase) {
      SessionPhase.connected => l10n.statusConnected,
      SessionPhase.connecting => l10n.statusConnecting,
      SessionPhase.authenticating => l10n.statusAuthenticating,
      SessionPhase.error => l10n.statusError,
      SessionPhase.disconnected => l10n.statusDisconnected,
    };
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.danger = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = danger
        ? (enabled
              ? const Color(0xFFFDA4AF)
              : const Color(0xFFFDA4AF).withValues(alpha: 0.45))
        : Colors.white.withValues(alpha: enabled ? 0.88 : 0.38);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF18212B)
                  : const Color(0xFF18212B).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
              ),
            ),
            child: Icon(icon, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}
