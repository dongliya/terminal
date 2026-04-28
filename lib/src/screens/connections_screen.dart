import 'package:flutter/material.dart';
import 'package:terminal/l10n/app_localizations.dart';
import 'package:terminal/src/models/ssh_connection.dart';
import 'package:terminal/src/rust/api/ssh.dart';
import 'package:terminal/src/screens/connection_editor_sheet.dart';
import 'package:terminal/src/screens/sftp_screen.dart';
import 'package:terminal/src/screens/terminal_workspace_screen.dart';
import 'package:terminal/src/services/connection_storage.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  List<SshConnection> _connections = const <SshConnection>[];
  String? _defaultConnectionId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final connections = await ConnectionStorage.loadConnections();
    final defaultConnectionId = await ConnectionStorage.loadDefaultConnectionId();
    if (!mounted) {
      return;
    }
    setState(() {
      _connections = connections;
      _defaultConnectionId = defaultConnectionId;
      _loading = false;
    });
  }

  Future<void> _openEditor([SshConnection? connection]) async {
    final saved = await showModalBottomSheet<SshConnection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => ConnectionEditorSheet(initialConnection: connection),
    );

    if (saved == null) {
      return;
    }

    await ConnectionStorage.saveConnection(saved);
    await _refresh();
  }

  Future<void> _deleteConnection(SshConnection connection) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteConnection),
          content: Text(l10n.deleteConnectionPrompt(connection.name)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ConnectionStorage.deleteConnection(connection.id);
    await _refresh();
  }

  Future<void> _toggleDefault(SshConnection connection) async {
    final next = _defaultConnectionId == connection.id ? null : connection.id;
    await ConnectionStorage.setDefaultConnectionId(next);
    await _refresh();
  }

  Future<void> _probeConnection(SshConnection connection) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(l10n.testingAddress(connection.host, connection.port)),
      ),
    );

    final result = sshProbeTcp(host: connection.host, port: connection.port);
    if (!mounted) {
      return;
    }

    final latency = result.latencyMs == null ? '' : ' (${result.latencyMs} ms)';
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(result.reachable ? l10n.portReachable : l10n.portUnreachable),
          content: Text('${result.message}$latency'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  void _connect(SshConnection connection) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TerminalWorkspaceScreen(initialConnection: connection),
      ),
    );
  }

  void _openFiles(SshConnection connection) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SftpScreen(connection: connection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.remoteTerminal),
        actions: <Widget>[
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _connections.isEmpty
              ? _EmptyState(onCreate: _openEditor)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: <Widget>[
                      Text(
                        l10n.savedHosts,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.savedHostsHint,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      for (final connection in _connections)
                        _ConnectionCard(
                          connection: connection,
                          isDefault: _defaultConnectionId == connection.id,
                          onConnect: () => _connect(connection),
                          onEdit: () => _openEditor(connection),
                          onDelete: () => _deleteConnection(connection),
                          onToggleDefault: () => _toggleDefault(connection),
                          onProbe: () => _probeConnection(connection),
                          onFiles: () => _openFiles(connection),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: Text(l10n.addHost),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.isDefault,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleDefault,
    required this.onProbe,
    required this.onFiles,
  });

  final SshConnection connection;
  final bool isDefault;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleDefault;
  final VoidCallback onProbe;
  final VoidCallback onFiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = _avatarColorsFor(connection.name);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onConnect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: accent.$1,
                    child: Text(
                      connection.name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: accent.$2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          connection.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: isDefault ? FontWeight.w700 : FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${connection.username}@${connection.host}:${connection.port}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (isDefault)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Tooltip(
                        message: l10n.defaultBadge,
                        child: Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: l10n.more,
                    onSelected: (value) {
                      switch (value) {
                        case 'connect':
                          onConnect();
                          break;
                        case 'probe':
                          onProbe();
                          break;
                        case 'files':
                          onFiles();
                          break;
                        case 'edit':
                          onEdit();
                          break;
                        case 'default':
                          onToggleDefault();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'connect',
                        child: ListTile(
                          leading: const Icon(Icons.play_arrow_rounded),
                          title: Text(l10n.connect),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'files',
                        child: ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(l10n.files),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'probe',
                        child: ListTile(
                          leading: const Icon(Icons.network_check),
                          title: Text(l10n.test),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(l10n.edit),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'default',
                        child: ListTile(
                          leading: Icon(
                            isDefault ? Icons.star : Icons.star_outline,
                          ),
                          title: Text(
                            isDefault ? l10n.removeDefault : l10n.setAsDefault,
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(l10n.delete),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    final index = seed.trim().isEmpty ? 0 : seed.runes.fold<int>(0, (sum, rune) => sum + rune) % palette.length;
    return palette[index];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final Future<void> Function([SshConnection? connection]) onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noSavedHosts,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noSavedHostsHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.createConnection),
            ),
          ],
        ),
      ),
    );
  }
}
