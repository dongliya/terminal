import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:terminal/l10n/app_localizations.dart';
import 'package:terminal/src/models/ssh_connection.dart';
import 'package:terminal/src/rust/api/sftp.dart';
import 'package:terminal/src/rust/api/ssh.dart';

class SftpScreen extends StatefulWidget {
  const SftpScreen({
    super.key,
    required this.connection,
  });

  final SshConnection connection;

  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  int? _sessionId;
  String _currentPath = '/';
  List<SftpEntry> _entries = const <SftpEntry>[];
  bool _connecting = true;
  bool _loading = false;
  bool _showHiddenFiles = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final sessionId = createSftpSession();
    setState(() {
      _sessionId = sessionId;
      _connecting = true;
      _loading = true;
      _error = null;
    });
    try {
      final initialPath = await sftpConnect(
        sessionId: sessionId,
        config: SshConfig(
          host: widget.connection.host,
          port: widget.connection.port,
          username: widget.connection.username,
          password: widget.connection.password,
          privateKey: widget.connection.privateKey,
        ),
      );
      await _loadDirectory(path: initialPath, replaceConnecting: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadDirectory({
    String? path,
    bool replaceConnecting = false,
  }) async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    setState(() {
      _loading = true;
      if (replaceConnecting) {
        _connecting = false;
      }
      _error = null;
    });
    try {
      final listing = sftpListDir(sessionId: sessionId, path: path);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPath = listing.path;
        _entries = listing.entries;
        _loading = false;
        _connecting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _connecting = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _downloadFile(SftpEntry entry) async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      final Directory baseDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final localPath = '${baseDir.path}/${entry.name}';
      setState(() {
        _loading = true;
      });
      sftpDownloadFile(
        sessionId: sessionId,
        remotePath: entry.path,
        localPath: localPath,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(l10n.downloadedTo(localPath)),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.downloadFailed}: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _uploadFile() async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      final picked = await FilePicker.platform.pickFiles(withData: false);
      final path = picked?.files.single.path;
      if (path == null || path.isEmpty) {
        return;
      }
      final name = path.split(Platform.pathSeparator).last;
      final remotePath = _joinRemote(_currentPath, name);
      setState(() {
        _loading = true;
      });
      sftpUploadFile(
        sessionId: sessionId,
        localPath: path,
        remotePath: remotePath,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(l10n.uploadedFile(name)),
        ),
      );
      await _loadDirectory(path: _currentPath);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.uploadFailed}: $error')),
      );
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _createFolder() async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.newFolder),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.createFolderHint),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) {
      return;
    }
    try {
      setState(() {
        _loading = true;
      });
      sftpCreateDir(sessionId: sessionId, path: _joinRemote(_currentPath, name));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(l10n.createdFolder),
        ),
      );
      await _loadDirectory(path: _currentPath);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteEntry(SftpEntry entry) async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteRemote),
          content: Text(l10n.deleteRemotePrompt(entry.name)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.deleteRemote),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      setState(() {
        _loading = true;
      });
      sftpDeletePath(
        sessionId: sessionId,
        path: entry.path,
        isDir: entry.entryType == SftpEntryType.directory,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(l10n.deletedRemote),
        ),
      );
      await _loadDirectory(path: _currentPath);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _goUp() async {
    if (_currentPath == '/' || _currentPath.isEmpty) {
      return;
    }
    final normalized = _currentPath.endsWith('/')
        ? _currentPath.substring(0, _currentPath.length - 1)
        : _currentPath;
    final slash = normalized.lastIndexOf('/');
    final parent = slash <= 0 ? '/' : normalized.substring(0, slash);
    await _loadDirectory(path: parent);
  }

  @override
  void dispose() {
    final sessionId = _sessionId;
    if (sessionId != null) {
      sftpDisposeSession(sessionId: sessionId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.sftpFiles,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              widget.connection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : () => _loadDirectory(path: _currentPath),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
          IconButton(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _showHiddenFiles = !_showHiddenFiles;
                    });
                  },
            icon: Icon(
              _showHiddenFiles
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            tooltip: _showHiddenFiles
                ? l10n.hideHiddenFiles
                : l10n.showHiddenFiles,
          ),
          IconButton(
            onPressed: _loading ? null : _goUp,
            icon: const Icon(Icons.drive_folder_upload_outlined),
            tooltip: l10n.folderUp,
          ),
          IconButton(
            onPressed: _loading ? null : _uploadFile,
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: l10n.uploadFile,
          ),
          IconButton(
            onPressed: _loading ? null : _createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.newFolder,
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
            tooltip: l10n.disconnect,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.remoteFiles),
              subtitle: Text(_currentPath),
            ),
          ),
          Expanded(
            child: _buildBody(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.loadingFiles),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.folder_off_outlined, size: 44),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _open,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    final visibleEntries = _visibleEntries;
    if (visibleEntries.isEmpty && !_loading) {
      return Center(child: Text(l10n.emptyFolder));
    }
    return Stack(
      children: <Widget>[
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: visibleEntries.length + (_currentPath == '/' ? 0 : 1),
          itemBuilder: (context, index) {
            if (_currentPath != '/' && index == 0) {
              return ListTile(
                leading: const Icon(Icons.arrow_upward_rounded),
                title: Text(l10n.folderUp),
                onTap: _goUp,
              );
            }
            final entry = visibleEntries[_currentPath == '/' ? index : index - 1];
            return ListTile(
              leading: Icon(_iconFor(entry.entryType)),
              title: Text(entry.name),
              subtitle: Text(_subtitleFor(entry)),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'download':
                      _downloadFile(entry);
                      break;
                    case 'delete':
                      _deleteEntry(entry);
                      break;
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  if (entry.entryType != SftpEntryType.directory)
                    PopupMenuItem<String>(
                      value: 'download',
                      child: ListTile(
                        leading: const Icon(Icons.download_outlined),
                        title: Text(l10n.download),
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(l10n.deleteRemote),
                    ),
                  ),
                ],
              ),
              onTap: () {
                if (entry.entryType == SftpEntryType.directory) {
                  _loadDirectory(path: entry.path);
                } else {
                  _downloadFile(entry);
                }
              },
            );
          },
        ),
        if (_loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }

  List<SftpEntry> get _visibleEntries {
    if (_showHiddenFiles) {
      return _entries;
    }
    return _entries
        .where((entry) => !entry.name.startsWith('.'))
        .toList(growable: false);
  }

  String _subtitleFor(SftpEntry entry) {
    final parts = <String>[];
    if (entry.entryType != SftpEntryType.directory) {
      parts.add(_humanSize(entry.size.toInt()));
    }
    if (entry.permissions.isNotEmpty) {
      parts.add(entry.permissions);
    }
    if (entry.modifiedUnix != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        entry.modifiedUnix!.toInt() * 1000,
      );
      parts.add(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
    }
    return parts.join('  ·  ');
  }

  IconData _iconFor(SftpEntryType type) {
    return switch (type) {
      SftpEntryType.directory => Icons.folder_outlined,
      SftpEntryType.symlink => Icons.link_outlined,
      SftpEntryType.other => Icons.insert_drive_file_outlined,
      SftpEntryType.file => Icons.description_outlined,
    };
  }

  String _joinRemote(String base, String name) {
    if (base == '/') {
      return '/$name';
    }
    return '${base.replaceFirst(RegExp(r'/$'), '')}/$name';
  }

  String _humanSize(int bytes) {
    const units = <String>['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit += 1;
    }
    final fixed = size >= 10 || unit == 0 ? 0 : 1;
    return '${size.toStringAsFixed(fixed)} ${units[unit]}';
  }
}
