// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '终端';

  @override
  String get remoteTerminal => '远程终端';

  @override
  String get addSession => '添加会话';

  @override
  String get refresh => '刷新';

  @override
  String get savedHosts => '主机列表';

  @override
  String get savedHostsHint => '点击已保存的服务器，即可在手机上打开远程终端。';

  @override
  String get addHost => '添加主机';

  @override
  String get newConnection => '新建连接';

  @override
  String get editConnection => '编辑连接';

  @override
  String get name => '名称';

  @override
  String get nameHint => '生产服务器';

  @override
  String get host => '主机';

  @override
  String get hostHint => 'example.com';

  @override
  String get username => '用户名';

  @override
  String get port => '端口';

  @override
  String get password => '密码';

  @override
  String get privateKey => '私钥';

  @override
  String get privateKeyHint => '-----BEGIN OPENSSH PRIVATE KEY-----';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get enterConnectionName => '请输入连接名称';

  @override
  String get enterHost => '请输入主机地址';

  @override
  String get enterUsername => '请输入用户名';

  @override
  String get enterValidPort => '1-65535';

  @override
  String get pastePrivateKey => '请粘贴私钥';

  @override
  String get passwordLogin => '密码登录';

  @override
  String get privateKeyLogin => '私钥登录';

  @override
  String get connect => '连接';

  @override
  String get test => '测试';

  @override
  String get edit => '编辑';

  @override
  String get setAsDefault => '设为默认';

  @override
  String get removeDefault => '取消默认';

  @override
  String get delete => '删除';

  @override
  String get more => '更多';

  @override
  String get defaultBadge => '默认';

  @override
  String get deleteConnection => '删除连接';

  @override
  String deleteConnectionPrompt(Object name) {
    return '要从本机删除“$name”吗？';
  }

  @override
  String testingAddress(Object host, Object port) {
    return '正在测试 $host:$port ...';
  }

  @override
  String get portReachable => '端口可达';

  @override
  String get portUnreachable => '端口不可达';

  @override
  String get files => '文件';

  @override
  String get sftpFiles => 'SFTP 文件';

  @override
  String get remoteFiles => '远程文件';

  @override
  String get loadingFiles => '正在加载文件...';

  @override
  String get showHiddenFiles => '显示隐藏文件';

  @override
  String get hideHiddenFiles => '隐藏隐藏文件';

  @override
  String get emptyFolder => '这个文件夹是空的';

  @override
  String get folderUp => '上级目录';

  @override
  String get download => '下载';

  @override
  String get uploadFile => '上传文件';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get deleteRemote => '删除';

  @override
  String deleteRemotePrompt(Object name) {
    return '要删除远程服务器上的“$name”吗？';
  }

  @override
  String get createFolderPrompt => '文件夹名称';

  @override
  String get createFolderHint => 'new-folder';

  @override
  String get create => '创建';

  @override
  String downloadedTo(Object path) {
    return '已下载到 $path';
  }

  @override
  String uploadedFile(Object name) {
    return '已上传 $name';
  }

  @override
  String get createdFolder => '文件夹已创建';

  @override
  String get deletedRemote => '已删除';

  @override
  String get pickFileFailed => '无法选择本地文件';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get uploadFailed => '上传失败';

  @override
  String get sftpConnectFailed => '无法打开 SFTP 连接';

  @override
  String get ok => '确定';

  @override
  String get noSavedHosts => '还没有已保存主机';

  @override
  String get noSavedHostsHint => '创建一个 SSH 配置后，就可以在安卓手机上连接远程终端。';

  @override
  String get createConnection => '创建连接';

  @override
  String get specialKeys => '特殊按键';

  @override
  String get copyOutput => '复制输出';

  @override
  String get clearScreen => '清屏';

  @override
  String get copyLogs => '复制日志';

  @override
  String get disconnect => '断开连接';

  @override
  String get connectingProgress => '连接中...';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get retry => '重试';

  @override
  String get back => '返回';

  @override
  String get terminalOutputCopied => '已复制终端输出';

  @override
  String get terminalCleared => '终端已清空';

  @override
  String get connectionLogsCopied => '已复制连接日志';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusConnecting => '连接中';

  @override
  String get statusAuthenticating => '认证中';

  @override
  String get statusError => '连接错误';

  @override
  String get statusDisconnected => '已断开';

  @override
  String get connectionLogs => '连接日志';

  @override
  String get noLogsYet => '暂无日志';

  @override
  String logLineCount(int count) {
    return '$count 条日志';
  }

  @override
  String get waitingForConnectionLogs => '等待连接日志...';
}
