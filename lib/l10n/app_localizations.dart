import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get appTitle;

  /// No description provided for @remoteTerminal.
  ///
  /// In en, this message translates to:
  /// **'Remote Terminal'**
  String get remoteTerminal;

  /// No description provided for @addSession.
  ///
  /// In en, this message translates to:
  /// **'Add session'**
  String get addSession;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @savedHosts.
  ///
  /// In en, this message translates to:
  /// **'Saved Hosts'**
  String get savedHosts;

  /// No description provided for @savedHostsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap any saved server to open a shell from your phone.'**
  String get savedHostsHint;

  /// No description provided for @addHost.
  ///
  /// In en, this message translates to:
  /// **'Add Host'**
  String get addHost;

  /// No description provided for @newConnection.
  ///
  /// In en, this message translates to:
  /// **'New Connection'**
  String get newConnection;

  /// No description provided for @editConnection.
  ///
  /// In en, this message translates to:
  /// **'Edit Connection'**
  String get editConnection;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Production Server'**
  String get nameHint;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @hostHint.
  ///
  /// In en, this message translates to:
  /// **'example.com'**
  String get hostHint;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get privateKey;

  /// No description provided for @privateKeyHint.
  ///
  /// In en, this message translates to:
  /// **'-----BEGIN OPENSSH PRIVATE KEY-----'**
  String get privateKeyHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @enterConnectionName.
  ///
  /// In en, this message translates to:
  /// **'Enter a connection name'**
  String get enterConnectionName;

  /// No description provided for @enterHost.
  ///
  /// In en, this message translates to:
  /// **'Enter a host'**
  String get enterHost;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter a username'**
  String get enterUsername;

  /// No description provided for @enterValidPort.
  ///
  /// In en, this message translates to:
  /// **'1-65535'**
  String get enterValidPort;

  /// No description provided for @pastePrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Paste your private key'**
  String get pastePrivateKey;

  /// No description provided for @passwordLogin.
  ///
  /// In en, this message translates to:
  /// **'Password login'**
  String get passwordLogin;

  /// No description provided for @privateKeyLogin.
  ///
  /// In en, this message translates to:
  /// **'Private key login'**
  String get privateKeyLogin;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get setAsDefault;

  /// No description provided for @removeDefault.
  ///
  /// In en, this message translates to:
  /// **'Remove Default'**
  String get removeDefault;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @defaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultBadge;

  /// No description provided for @deleteConnection.
  ///
  /// In en, this message translates to:
  /// **'Delete Connection'**
  String get deleteConnection;

  /// No description provided for @deleteConnectionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" from this device?'**
  String deleteConnectionPrompt(Object name);

  /// No description provided for @testingAddress.
  ///
  /// In en, this message translates to:
  /// **'Testing {host}:{port} ...'**
  String testingAddress(Object host, Object port);

  /// No description provided for @portReachable.
  ///
  /// In en, this message translates to:
  /// **'Port Reachable'**
  String get portReachable;

  /// No description provided for @portUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Port Unreachable'**
  String get portUnreachable;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @sftpFiles.
  ///
  /// In en, this message translates to:
  /// **'SFTP Files'**
  String get sftpFiles;

  /// No description provided for @remoteFiles.
  ///
  /// In en, this message translates to:
  /// **'Remote files'**
  String get remoteFiles;

  /// No description provided for @loadingFiles.
  ///
  /// In en, this message translates to:
  /// **'Loading files...'**
  String get loadingFiles;

  /// No description provided for @showHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHiddenFiles;

  /// No description provided for @hideHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden files'**
  String get hideHiddenFiles;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get emptyFolder;

  /// No description provided for @folderUp.
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get folderUp;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get uploadFile;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @deleteRemote.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteRemote;

  /// No description provided for @deleteRemotePrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" on the remote server?'**
  String deleteRemotePrompt(Object name);

  /// No description provided for @createFolderPrompt.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get createFolderPrompt;

  /// No description provided for @createFolderHint.
  ///
  /// In en, this message translates to:
  /// **'new-folder'**
  String get createFolderHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @downloadedTo.
  ///
  /// In en, this message translates to:
  /// **'Downloaded to {path}'**
  String downloadedTo(Object path);

  /// No description provided for @uploadedFile.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {name}'**
  String uploadedFile(Object name);

  /// No description provided for @createdFolder.
  ///
  /// In en, this message translates to:
  /// **'Created folder'**
  String get createdFolder;

  /// No description provided for @deletedRemote.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deletedRemote;

  /// No description provided for @pickFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to pick a local file'**
  String get pickFileFailed;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @sftpConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open SFTP connection'**
  String get sftpConnectFailed;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @noSavedHosts.
  ///
  /// In en, this message translates to:
  /// **'No saved hosts yet'**
  String get noSavedHosts;

  /// No description provided for @noSavedHostsHint.
  ///
  /// In en, this message translates to:
  /// **'Create an SSH profile and connect to your remote shell from Android.'**
  String get noSavedHostsHint;

  /// No description provided for @createConnection.
  ///
  /// In en, this message translates to:
  /// **'Create Connection'**
  String get createConnection;

  /// No description provided for @specialKeys.
  ///
  /// In en, this message translates to:
  /// **'Special keys'**
  String get specialKeys;

  /// No description provided for @copyOutput.
  ///
  /// In en, this message translates to:
  /// **'Copy output'**
  String get copyOutput;

  /// No description provided for @clearScreen.
  ///
  /// In en, this message translates to:
  /// **'Clear screen'**
  String get clearScreen;

  /// No description provided for @copyLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy logs'**
  String get copyLogs;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connectingProgress.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectingProgress;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get connectionFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @terminalOutputCopied.
  ///
  /// In en, this message translates to:
  /// **'Terminal output copied'**
  String get terminalOutputCopied;

  /// No description provided for @terminalCleared.
  ///
  /// In en, this message translates to:
  /// **'Terminal cleared'**
  String get terminalCleared;

  /// No description provided for @connectionLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Connection logs copied'**
  String get connectionLogsCopied;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get statusConnecting;

  /// No description provided for @statusAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating'**
  String get statusAuthenticating;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get statusError;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @connectionLogs.
  ///
  /// In en, this message translates to:
  /// **'Connection Logs'**
  String get connectionLogs;

  /// No description provided for @noLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get noLogsYet;

  /// No description provided for @logLineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} log lines'**
  String logLineCount(int count);

  /// No description provided for @waitingForConnectionLogs.
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection logs...'**
  String get waitingForConnectionLogs;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
