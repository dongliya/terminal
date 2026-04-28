import 'package:shared_preferences/shared_preferences.dart';
import 'package:terminal/src/models/ssh_connection.dart';

class ConnectionStorage {
  static const _connectionsKey = 'connections';
  static const _defaultKey = 'default_connection_id';

  static Future<List<SshConnection>> loadConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_connectionsKey) ?? <String>[];
    return raw.map(SshConnection.decode).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static Future<void> saveConnection(SshConnection connection) async {
    final prefs = await SharedPreferences.getInstance();
    final connections = await loadConnections();
    final index = connections.indexWhere((item) => item.id == connection.id);
    if (index == -1) {
      connections.add(connection);
    } else {
      connections[index] = connection;
    }
    await prefs.setStringList(
      _connectionsKey,
      connections.map((item) => item.encode()).toList(),
    );
  }

  static Future<void> deleteConnection(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final connections = await loadConnections();
    connections.removeWhere((item) => item.id == id);
    await prefs.setStringList(
      _connectionsKey,
      connections.map((item) => item.encode()).toList(),
    );

    if (prefs.getString(_defaultKey) == id) {
      await prefs.remove(_defaultKey);
    }
  }

  static Future<String?> loadDefaultConnectionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultKey);
  }

  static Future<void> setDefaultConnectionId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_defaultKey);
    } else {
      await prefs.setString(_defaultKey, id);
    }
  }
}
