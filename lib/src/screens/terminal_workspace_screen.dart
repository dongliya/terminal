import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terminal/l10n/app_localizations.dart';
import 'package:terminal/src/models/ssh_connection.dart';
import 'package:terminal/src/screens/terminal_session_pane.dart';
import 'package:terminal/src/services/background_execution_service.dart';
import 'package:terminal/src/services/connection_storage.dart';
import 'package:terminal/src/services/terminal_session_controller.dart';

class TerminalWorkspaceScreen extends StatefulWidget {
  const TerminalWorkspaceScreen({super.key, required this.initialConnection});

  final SshConnection initialConnection;

  @override
  State<TerminalWorkspaceScreen> createState() =>
      _TerminalWorkspaceScreenState();
}

class _TerminalWorkspaceScreenState extends State<TerminalWorkspaceScreen> {
  late final List<_WorkspaceSession> _sessions;
  int _activeIndex = 0;
  bool _handlingPop = false;
  bool _tearingDown = false;

  @override
  void initState() {
    super.initState();
    _sessions = <_WorkspaceSession>[
      _createWorkspaceSession(widget.initialConnection),
    ];
    _syncActiveSessions();
    _enableBackgroundExecution();
  }

  Future<void> _enableBackgroundExecution() async {
    final enabled = await BackgroundExecutionService.acquire();
    if (!enabled) {
      debugPrint('Background execution could not be enabled.');
    }
  }

  _WorkspaceSession _createWorkspaceSession(SshConnection connection) {
    return _WorkspaceSession(
      id: '${connection.id}-${DateTime.now().microsecondsSinceEpoch}',
      connection: connection,
      controller: TerminalSessionController(connection: connection),
      paneKey: GlobalKey(),
    );
  }

  void _syncActiveSessions() {
    for (var i = 0; i < _sessions.length; i++) {
      _sessions[i].controller.setActive(i == _activeIndex);
    }
  }

  Future<void> _disposeSession(_WorkspaceSession session) async {
    await session.controller.disconnect();
    session.controller.dispose();
  }

  Future<void> _shutdownWorkspace() async {
    if (_tearingDown) {
      return;
    }
    _tearingDown = true;
    final sessionsToDispose = List<_WorkspaceSession>.from(_sessions);
    _sessions.clear();
    for (final session in sessionsToDispose) {
      await _disposeSession(session);
    }
    await BackgroundExecutionService.release();
  }

  void _setActiveIndex(int index) {
    if (_activeIndex == index || _tearingDown) {
      return;
    }
    setState(() {
      _activeIndex = index;
    });
    _syncActiveSessions();
  }

  Future<void> _addSession() async {
    final connections = await ConnectionStorage.loadConnections();
    if (!mounted) {
      return;
    }

    final connection = await showModalBottomSheet<SshConnection>(
      context: context,
      backgroundColor: const Color(0xFF111821),
      showDragHandle: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                title: Text(
                  l10n.addSession,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(l10n.savedHostsHint),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final connection in connections)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Material(
                          color: const Color(0xFF16202B),
                          borderRadius: BorderRadius.circular(18),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: _avatarColorsFor(
                                connection.name,
                              ).$1,
                              child: Text(
                                connection.name.characters.first.toUpperCase(),
                                style: TextStyle(
                                  color: _avatarColorsFor(connection.name).$2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(connection.name),
                            subtitle: Text(
                              '${connection.username}@${connection.host}:${connection.port}',
                            ),
                            onTap: () => Navigator.of(context).pop(connection),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (connection == null || !mounted) {
      return;
    }

    setState(() {
      _sessions.add(_createWorkspaceSession(connection));
      _activeIndex = _sessions.length - 1;
    });
    _syncActiveSessions();
  }

  Future<void> _closeSession(String sessionId) async {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) {
      return;
    }

    if (_sessions.length == 1) {
      await _shutdownWorkspace();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final session = _sessions[index];
    await _disposeSession(session);

    if (!mounted) {
      return;
    }

    setState(() {
      _sessions.removeAt(index);
      if (_activeIndex >= _sessions.length) {
        _activeIndex = _sessions.length - 1;
      } else if (_activeIndex > index) {
        _activeIndex -= 1;
      }
    });
    _syncActiveSessions();
  }

  Future<bool> _handlePop() async {
    if (_handlingPop) {
      return false;
    }
    _handlingPop = true;
    await _shutdownWorkspace();
    _handlingPop = false;
    return true;
  }

  @override
  void dispose() {
    if (!_tearingDown) {
      final sessionsToDispose = List<_WorkspaceSession>.from(_sessions);
      _sessions.clear();
      for (final session in sessionsToDispose) {
        unawaited(session.controller.disconnect());
        session.controller.dispose();
      }
      unawaited(BackgroundExecutionService.release());
    }
    super.dispose();
  }

  int _sessionOrdinalFor(String sessionId) {
    final session = _sessions.where((item) => item.id == sessionId).firstOrNull;
    if (session == null) {
      return 1;
    }
    final siblings = _sessions
        .where((item) => item.connection.id == session.connection.id)
        .toList(growable: false);
    final ordinal = siblings.indexWhere((item) => item.id == sessionId);
    return ordinal >= 0 ? ordinal + 1 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final allowPop = await _handlePop();
        if (allowPop && mounted) {
          navigator.pop(result);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF091017),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10161E),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _sessions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final session = _sessions[index];
                              final selected = index == _activeIndex;
                              final accent = _avatarColorsFor(
                                session.connection.name,
                              );
                              final ordinal = _sessionOrdinalFor(session.id);
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _setActiveIndex(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? accent.$1.withValues(alpha: 0.16)
                                        : const Color(0xFF18212B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected
                                          ? accent.$1.withValues(alpha: 0.9)
                                          : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      CircleAvatar(
                                        radius: 11,
                                        backgroundColor: accent.$1,
                                        child: Text(
                                          session
                                              .connection
                                              .name
                                              .characters
                                              .first
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: accent.$2,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 120,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              session.connection.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: selected ? 0.96 : 0.78,
                                                ),
                                                fontSize: 13,
                                                height: 1,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${session.connection.username}  #$ordinal',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: selected ? 0.70 : 0.54,
                                                ),
                                                fontSize: 10,
                                                height: 1,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkResponse(
                                          radius: 18,
                                          onTap: () {
                                            _closeSession(session.id);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 15,
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: FilledButton.tonal(
                          onPressed: _addSession,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF18212B),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(40, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Icon(Icons.add_link_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _activeIndex,
                  children: <Widget>[
                    for (final session in _sessions)
                      TerminalSessionPane(
                        key: session.paneKey,
                        controller: session.controller,
                        isActive: session.id == _sessions[_activeIndex].id,
                        onRequestClose: () => _closeSession(session.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSession {
  const _WorkspaceSession({
    required this.id,
    required this.connection,
    required this.controller,
    required this.paneKey,
  });

  final String id;
  final SshConnection connection;
  final TerminalSessionController controller;
  final GlobalKey paneKey;
}

(Color, Color) _avatarColorsFor(String seed) {
  const palette = <(Color, Color)>[
    (Color(0xFF22C55E), Colors.white),
    (Color(0xFF3B82F6), Colors.white),
    (Color(0xFFF97316), Colors.white),
    (Color(0xFF14B8A6), Colors.white),
    (Color(0xFFEAB308), Color(0xFF1F2937)),
    (Color(0xFF06B6D4), Colors.white),
    (Color(0xFFEC4899), Colors.white),
  ];
  final index = seed.trim().isEmpty
      ? 0
      : seed.runes.fold<int>(0, (sum, rune) => sum + rune) % palette.length;
  return palette[index];
}

extension on Iterable<_WorkspaceSession> {
  _WorkspaceSession? get firstOrNull => isEmpty ? null : first;
}
