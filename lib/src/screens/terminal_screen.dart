import 'package:flutter/material.dart';
import 'package:terminal/src/models/ssh_connection.dart';
import 'package:terminal/src/screens/terminal_session_pane.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({
    super.key,
    required this.connection,
  });

  final SshConnection connection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TerminalSessionPane(
        connection: connection,
        topSafeArea: true,
        onRequestClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
