use anyhow::{anyhow, Context, Result};
use flutter_rust_bridge::frb;
use russh::keys::{load_secret_key, ssh_key, PrivateKeyWithHashAlg};
use russh::{client, Disconnect};
use russh_sftp::client::SftpSession;
use russh_sftp::protocol::{FileType, OpenFlags};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicI32, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, UNIX_EPOCH};
use tokio::fs as tokio_fs;
use tokio::io::AsyncWriteExt;
use tokio::runtime::Runtime;
use tokio::time::timeout;

const SFTP_CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
static NEXT_SFTP_SESSION_ID: AtomicI32 = AtomicI32::new(1);
static SFTP_SESSION_REGISTRY: OnceLock<Mutex<HashMap<i32, Arc<SftpSessionHandle>>>> =
    OnceLock::new();

#[frb]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SftpEntryType {
    File,
    Directory,
    Symlink,
    Other,
}

#[frb]
#[derive(Clone, Debug)]
pub struct SftpEntry {
    pub name: String,
    pub path: String,
    pub entry_type: SftpEntryType,
    pub size: u64,
    pub modified_unix: Option<u64>,
    pub permissions: String,
}

#[frb]
#[derive(Clone, Debug)]
pub struct SftpDirectoryListing {
    pub path: String,
    pub entries: Vec<SftpEntry>,
}

struct ClientHandler;

impl client::Handler for ClientHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &ssh_key::PublicKey,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }
}

struct ActiveSftpSession {
    handle: client::Handle<ClientHandler>,
    sftp: SftpSession,
}

struct SftpSessionHandle {
    runtime: Runtime,
    active: Mutex<Option<ActiveSftpSession>>,
}

impl SftpSessionHandle {
    fn new() -> Self {
        Self {
            runtime: Runtime::new().expect("failed to create tokio runtime"),
            active: Mutex::new(None),
        }
    }
}

#[frb(sync)]
pub fn create_sftp_session() -> i32 {
    let session_id = NEXT_SFTP_SESSION_ID.fetch_add(1, Ordering::Relaxed);
    sftp_registry()
        .lock()
        .unwrap()
        .insert(session_id, Arc::new(SftpSessionHandle::new()));
    session_id
}

#[frb]
pub fn sftp_connect(session_id: i32, config: crate::api::ssh::SshConfig) -> Result<String> {
    let session = get_sftp_session(session_id)?;
    if session.active.lock().unwrap().is_some() {
        return Err(anyhow!("sftp session is already active"));
    }

    let path = session.runtime.block_on(async move {
        let client_config = Arc::new(client::Config {
            inactivity_timeout: Some(Duration::from_secs(60)),
            ..<_>::default()
        });

        let mut handle = timeout(
            SFTP_CONNECT_TIMEOUT,
            client::connect(
                client_config,
                (config.host.as_str(), config.port),
                ClientHandler,
            ),
        )
        .await
        .map_err(|_| {
            anyhow!(
                "sftp connection timed out after {}s",
                SFTP_CONNECT_TIMEOUT.as_secs()
            )
        })?
        .with_context(|| format!("unable to reach {}:{}", config.host, config.port))?;

        authenticate(&mut handle, &config).await?;

        let channel = handle
            .channel_open_session()
            .await
            .context("unable to open ssh session for sftp")?;
        channel
            .request_subsystem(true, "sftp")
            .await
            .context("unable to start sftp subsystem")?;

        let sftp = SftpSession::new(channel.into_stream())
            .await
            .context("unable to create sftp session")?;
        let cwd = sftp
            .canonicalize(".")
            .await
            .unwrap_or_else(|_| "/".to_string());

        Ok::<_, anyhow::Error>((cwd, ActiveSftpSession { handle, sftp }))
    })?;

    *session.active.lock().unwrap() = Some(path.1);
    Ok(path.0)
}

#[frb(sync)]
pub fn sftp_list_dir(session_id: i32, path: Option<String>) -> Result<SftpDirectoryListing> {
    with_active_session(session_id, |runtime, active| {
        runtime.block_on(async {
            let requested = path.unwrap_or_else(|| ".".to_string());
            let canonical = active
                .sftp
                .canonicalize(requested)
                .await
                .unwrap_or_else(|_| "/".to_string());
            let mut entries = Vec::new();
            for entry in active
                .sftp
                .read_dir(canonical.clone())
                .await
                .with_context(|| format!("unable to read remote directory {canonical}"))?
            {
                let name = entry.file_name();
                let metadata = entry.metadata();
                let entry_path = join_remote_path(&canonical, &name);
                let modified_unix = metadata
                    .modified()
                    .ok()
                    .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
                    .map(|duration| duration.as_secs());
                entries.push(SftpEntry {
                    name,
                    path: entry_path,
                    entry_type: match entry.file_type() {
                        FileType::Dir => SftpEntryType::Directory,
                        FileType::File => SftpEntryType::File,
                        FileType::Symlink => SftpEntryType::Symlink,
                        FileType::Other => SftpEntryType::Other,
                    },
                    size: metadata.len(),
                    modified_unix,
                    permissions: metadata.permissions().to_string(),
                });
            }
            entries.sort_by(|left, right| {
                let left_dir = matches!(left.entry_type, SftpEntryType::Directory);
                let right_dir = matches!(right.entry_type, SftpEntryType::Directory);
                right_dir
                    .cmp(&left_dir)
                    .then_with(|| left.name.to_lowercase().cmp(&right.name.to_lowercase()))
            });
            Ok(SftpDirectoryListing {
                path: canonical,
                entries,
            })
        })
    })
}

#[frb(sync)]
pub fn sftp_download_file(session_id: i32, remote_path: String, local_path: String) -> Result<()> {
    with_active_session(session_id, |runtime, active| {
        runtime.block_on(async {
            let data = active
                .sftp
                .read(remote_path.clone())
                .await
                .with_context(|| format!("unable to download {remote_path}"))?;
            let local = PathBuf::from(local_path);
            if let Some(parent) = local.parent() {
                tokio_fs::create_dir_all(parent)
                    .await
                    .with_context(|| format!("unable to create {}", parent.display()))?;
            }
            tokio_fs::write(&local, data)
                .await
                .with_context(|| format!("unable to save {}", local.display()))?;
            Ok(())
        })
    })
}

#[frb(sync)]
pub fn sftp_upload_file(session_id: i32, local_path: String, remote_path: String) -> Result<()> {
    with_active_session(session_id, |runtime, active| {
        runtime.block_on(async {
            let data = tokio_fs::read(&local_path)
                .await
                .with_context(|| format!("unable to read local file {local_path}"))?;
            let mut file = active
                .sftp
                .open_with_flags(
                    remote_path.clone(),
                    OpenFlags::CREATE | OpenFlags::TRUNCATE | OpenFlags::WRITE,
                )
                .await
                .with_context(|| format!("unable to open remote file {remote_path}"))?;
            file.write_all(&data)
                .await
                .with_context(|| format!("unable to upload to {remote_path}"))?;
            file.flush().await.context("unable to flush remote file")?;
            file.shutdown().await.ok();
            Ok(())
        })
    })
}

#[frb(sync)]
pub fn sftp_create_dir(session_id: i32, path: String) -> Result<()> {
    with_active_session(session_id, |runtime, active| {
        runtime.block_on(async {
            active
                .sftp
                .create_dir(path.clone())
                .await
                .with_context(|| format!("unable to create remote directory {path}"))?;
            Ok(())
        })
    })
}

#[frb(sync)]
pub fn sftp_delete_path(session_id: i32, path: String, is_dir: bool) -> Result<()> {
    with_active_session(session_id, |runtime, active| {
        runtime.block_on(async {
            if is_dir {
                active
                    .sftp
                    .remove_dir(path.clone())
                    .await
                    .with_context(|| format!("unable to remove remote directory {path}"))?;
            } else {
                active
                    .sftp
                    .remove_file(path.clone())
                    .await
                    .with_context(|| format!("unable to remove remote file {path}"))?;
            }
            Ok(())
        })
    })
}

#[frb(sync)]
pub fn sftp_disconnect(session_id: i32) -> Result<()> {
    let session = get_sftp_session(session_id)?;
    let mut active = session.active.lock().unwrap();
    if let Some(active_session) = active.take() {
        session.runtime.block_on(async move {
            let _ = active_session.sftp.close().await;
            let _ = active_session
                .handle
                .disconnect(Disconnect::ByApplication, "client disconnect", "en")
                .await;
        });
    }
    Ok(())
}

#[frb(sync)]
pub fn sftp_dispose_session(session_id: i32) {
    let _ = sftp_disconnect(session_id);
    sftp_registry().lock().unwrap().remove(&session_id);
}

fn sftp_registry() -> &'static Mutex<HashMap<i32, Arc<SftpSessionHandle>>> {
    SFTP_SESSION_REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

fn get_sftp_session(session_id: i32) -> Result<Arc<SftpSessionHandle>> {
    sftp_registry()
        .lock()
        .unwrap()
        .get(&session_id)
        .cloned()
        .ok_or_else(|| anyhow!("sftp session {session_id} not found"))
}

fn with_active_session<T>(
    session_id: i32,
    f: impl FnOnce(&Runtime, &mut ActiveSftpSession) -> Result<T>,
) -> Result<T> {
    let session = get_sftp_session(session_id)?;
    let mut active = session.active.lock().unwrap();
    let active = active
        .as_mut()
        .ok_or_else(|| anyhow!("sftp session is not connected"))?;
    f(&session.runtime, active)
}

async fn authenticate(
    handle: &mut client::Handle<ClientHandler>,
    config: &crate::api::ssh::SshConfig,
) -> Result<()> {
    if let Some(password) = &config.password {
        let result = handle
            .authenticate_password(config.username.clone(), password.clone())
            .await
            .context("password authentication failed")?;

        if result.success() {
            return Ok(());
        }

        return Err(anyhow!("password authentication was rejected"));
    }

    if let Some(private_key) = &config.private_key {
        let temp_path = write_private_key(private_key)?;
        let key_pair = load_secret_key(&temp_path, None).context("unable to load private key")?;
        let _ = fs::remove_file(&temp_path);

        let hash_alg = handle.best_supported_rsa_hash().await?.flatten();
        let result = handle
            .authenticate_publickey(
                config.username.clone(),
                PrivateKeyWithHashAlg::new(Arc::new(key_pair), hash_alg),
            )
            .await
            .context("private key authentication failed")?;

        if result.success() {
            return Ok(());
        }

        return Err(anyhow!("private key authentication was rejected"));
    }

    Err(anyhow!("either password or private key is required"))
}

fn write_private_key(private_key: &str) -> Result<PathBuf> {
    let path = std::env::temp_dir().join(format!(
        "terminal_sftp_key_{}_{}.pem",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
    ));
    fs::write(&path, private_key).context("unable to write private key file")?;
    Ok(path)
}

fn join_remote_path(base: &str, name: &str) -> String {
    if base == "/" {
        format!("/{name}")
    } else {
        format!("{}/{}", base.trim_end_matches('/'), name)
    }
}

#[frb(sync)]
pub fn sftp_suggest_download_path(file_name: String) -> String {
    let mut root = std::env::temp_dir();
    root.push("terminal-downloads");
    root.push(file_name);
    root.to_string_lossy().to_string()
}

#[frb(sync)]
pub fn sftp_file_name(path: String) -> String {
    Path::new(&path)
        .file_name()
        .map(|name| name.to_string_lossy().to_string())
        .unwrap_or(path)
}
