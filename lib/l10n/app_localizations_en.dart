// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Terminal';

  @override
  String get remoteTerminal => 'Remote Terminal';

  @override
  String get addSession => 'Add session';

  @override
  String get refresh => 'Refresh';

  @override
  String get savedHosts => 'Saved Hosts';

  @override
  String get savedHostsHint =>
      'Tap any saved server to open a shell from your phone.';

  @override
  String get addHost => 'Add Host';

  @override
  String get newConnection => 'New Connection';

  @override
  String get editConnection => 'Edit Connection';

  @override
  String get name => 'Name';

  @override
  String get nameHint => 'Production Server';

  @override
  String get host => 'Host';

  @override
  String get hostHint => 'example.com';

  @override
  String get username => 'Username';

  @override
  String get port => 'Port';

  @override
  String get password => 'Password';

  @override
  String get privateKey => 'Private Key';

  @override
  String get privateKeyHint => '-----BEGIN OPENSSH PRIVATE KEY-----';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get enterConnectionName => 'Enter a connection name';

  @override
  String get enterHost => 'Enter a host';

  @override
  String get enterUsername => 'Enter a username';

  @override
  String get enterValidPort => '1-65535';

  @override
  String get pastePrivateKey => 'Paste your private key';

  @override
  String get passwordLogin => 'Password login';

  @override
  String get privateKeyLogin => 'Private key login';

  @override
  String get connect => 'Connect';

  @override
  String get test => 'Test';

  @override
  String get edit => 'Edit';

  @override
  String get setAsDefault => 'Set as Default';

  @override
  String get removeDefault => 'Remove Default';

  @override
  String get delete => 'Delete';

  @override
  String get more => 'More';

  @override
  String get defaultBadge => 'Default';

  @override
  String get deleteConnection => 'Delete Connection';

  @override
  String deleteConnectionPrompt(Object name) {
    return 'Delete \"$name\" from this device?';
  }

  @override
  String testingAddress(Object host, Object port) {
    return 'Testing $host:$port ...';
  }

  @override
  String get portReachable => 'Port Reachable';

  @override
  String get portUnreachable => 'Port Unreachable';

  @override
  String get files => 'Files';

  @override
  String get sftpFiles => 'SFTP Files';

  @override
  String get remoteFiles => 'Remote files';

  @override
  String get loadingFiles => 'Loading files...';

  @override
  String get showHiddenFiles => 'Show hidden files';

  @override
  String get hideHiddenFiles => 'Hide hidden files';

  @override
  String get emptyFolder => 'This folder is empty';

  @override
  String get folderUp => 'Parent folder';

  @override
  String get download => 'Download';

  @override
  String get uploadFile => 'Upload file';

  @override
  String get newFolder => 'New folder';

  @override
  String get deleteRemote => 'Delete';

  @override
  String deleteRemotePrompt(Object name) {
    return 'Delete \"$name\" on the remote server?';
  }

  @override
  String get createFolderPrompt => 'Folder name';

  @override
  String get createFolderHint => 'new-folder';

  @override
  String get create => 'Create';

  @override
  String downloadedTo(Object path) {
    return 'Downloaded to $path';
  }

  @override
  String uploadedFile(Object name) {
    return 'Uploaded $name';
  }

  @override
  String get createdFolder => 'Created folder';

  @override
  String get deletedRemote => 'Deleted';

  @override
  String get pickFileFailed => 'Unable to pick a local file';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get sftpConnectFailed => 'Unable to open SFTP connection';

  @override
  String get ok => 'OK';

  @override
  String get noSavedHosts => 'No saved hosts yet';

  @override
  String get noSavedHostsHint =>
      'Create an SSH profile and connect to your remote shell from Android.';

  @override
  String get createConnection => 'Create Connection';

  @override
  String get specialKeys => 'Special keys';

  @override
  String get copyOutput => 'Copy output';

  @override
  String get clearScreen => 'Clear screen';

  @override
  String get copyLogs => 'Copy logs';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connectingProgress => 'Connecting...';

  @override
  String get connectionFailed => 'Connection Failed';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get terminalOutputCopied => 'Terminal output copied';

  @override
  String get terminalCleared => 'Terminal cleared';

  @override
  String get connectionLogsCopied => 'Connection logs copied';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting';

  @override
  String get statusAuthenticating => 'Authenticating';

  @override
  String get statusError => 'Connection error';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get connectionLogs => 'Connection Logs';

  @override
  String get noLogsYet => 'No logs yet';

  @override
  String logLineCount(int count) {
    return '$count log lines';
  }

  @override
  String get waitingForConnectionLogs => 'Waiting for connection logs...';
}
