use anyhow::{anyhow, Context, Result};
use flutter_rust_bridge::frb;
use russh::keys::{load_secret_key, ssh_key, PrivateKeyWithHashAlg};
use russh::{client, ChannelMsg, Disconnect};
use std::collections::HashMap;
use std::fs;
use std::io::{BufRead, BufReader};
use std::net::{TcpStream, ToSocketAddrs};
use std::path::PathBuf;
use std::sync::atomic::{AtomicI32, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;
use std::time::Instant;
use tokio::runtime::Runtime;
use tokio::sync::mpsc;
use tokio::time::timeout;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(8);
const AUTH_TIMEOUT: Duration = Duration::from_secs(10);
const CHANNEL_TIMEOUT: Duration = Duration::from_secs(10);
static NEXT_SESSION_ID: AtomicI32 = AtomicI32::new(1);
static SESSION_REGISTRY: OnceLock<Mutex<HashMap<i32, Arc<SshSessionHandle>>>> = OnceLock::new();

#[frb]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SessionPhase {
    Disconnected,
    Connecting,
    Authenticating,
    Connected,
    Error,
}

#[frb]
#[derive(Clone, Debug)]
pub struct SessionStatus {
    pub phase: SessionPhase,
    pub message: Option<String>,
}

#[frb]
#[derive(Clone, Debug)]
pub struct SshConfig {
    pub host: String,
    pub port: u16,
    pub username: String,
    pub password: Option<String>,
    pub private_key: Option<String>,
}

#[frb]
#[derive(Clone, Debug)]
pub struct TerminalChunk {
    pub data: String,
    pub is_error: bool,
}

#[frb]
#[derive(Clone, Debug)]
pub struct TcpProbeResult {
    pub reachable: bool,
    pub message: String,
    pub latency_ms: Option<u32>,
}

impl TcpProbeResult {
    fn error(message: String) -> Self {
        Self {
            reachable: false,
            message,
            latency_ms: None,
        }
    }
}

enum SessionCommand {
    Input(Vec<u8>),
    Resize { cols: u32, rows: u32 },
    Disconnect,
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

pub struct SshSessionHandle {
    runtime: Runtime,
    status: Arc<Mutex<SessionStatus>>,
    output: Arc<Mutex<Vec<TerminalChunk>>>,
    command_sender: Arc<Mutex<Option<mpsc::UnboundedSender<SessionCommand>>>>,
}

impl SshSessionHandle {
    fn new() -> Self {
        Self {
            runtime: Runtime::new().expect("failed to create tokio runtime"),
            status: Arc::new(Mutex::new(SessionStatus {
                phase: SessionPhase::Disconnected,
                message: None,
            })),
            output: Arc::new(Mutex::new(Vec::new())),
            command_sender: Arc::new(Mutex::new(None)),
        }
    }
}

#[frb(sync)]
pub fn create_ssh_session() -> i32 {
    let session_id = NEXT_SESSION_ID.fetch_add(1, Ordering::Relaxed);
    registry()
        .lock()
        .unwrap()
        .insert(session_id, Arc::new(SshSessionHandle::new()));
    session_id
}

#[frb]
pub fn ssh_connect(session_id: i32, config: SshConfig, cols: u32, rows: u32) -> Result<()> {
    let session = get_session(session_id)?;
    if session.command_sender.lock().unwrap().is_some() {
        return Err(anyhow!("session is already active"));
    }

    set_status(
        &session.status,
        SessionPhase::Connecting,
        Some(format!("Connecting to {}:{}", config.host, config.port)),
    );

    let (command_sender, command_receiver) = mpsc::unbounded_channel();
    *session.command_sender.lock().unwrap() = Some(command_sender);

    let status = Arc::clone(&session.status);
    let output = Arc::clone(&session.output);
    let sender_ref = Arc::clone(&session.command_sender);

    session.runtime.spawn(async move {
        if let Err(err) = run_session(config, cols, rows, command_receiver, &status, &output).await
        {
            set_status(&status, SessionPhase::Error, Some(err.to_string()));
        }

        *sender_ref.lock().unwrap() = None;

        let current = status.lock().unwrap().clone();
        if current.phase != SessionPhase::Error {
            set_status(
                &status,
                SessionPhase::Disconnected,
                Some("Disconnected".to_string()),
            );
        }
    });

    Ok(())
}

#[frb(sync)]
pub fn ssh_send_input(session_id: i32, input: String) -> Result<()> {
    let session = get_session(session_id)?;
    let sender = session.command_sender.lock().unwrap().clone();
    match sender {
        Some(sender) => sender
            .send(SessionCommand::Input(input.into_bytes()))
            .map_err(|_| anyhow!("session is not available")),
        None => Err(anyhow!("session is not connected")),
    }
}

#[frb(sync)]
pub fn ssh_resize(session_id: i32, cols: u32, rows: u32) -> Result<()> {
    let session = get_session(session_id)?;
    let sender = session.command_sender.lock().unwrap().clone();
    match sender {
        Some(sender) => sender
            .send(SessionCommand::Resize { cols, rows })
            .map_err(|_| anyhow!("session is not available")),
        None => Err(anyhow!("session is not connected")),
    }
}

#[frb(sync)]
pub fn ssh_read_output(session_id: i32) -> Result<Vec<TerminalChunk>> {
    let session = get_session(session_id)?;
    let mut output = session.output.lock().unwrap();
    Ok(std::mem::take(&mut *output))
}

#[frb(sync)]
pub fn ssh_get_status(session_id: i32) -> Result<SessionStatus> {
    let session = get_session(session_id)?;
    let status = session.status.lock().unwrap().clone();
    Ok(status)
}

#[frb(sync)]
pub fn ssh_disconnect(session_id: i32) -> Result<()> {
    let session = get_session(session_id)?;
    let sender = session.command_sender.lock().unwrap().clone();
    if let Some(sender) = sender {
        sender
            .send(SessionCommand::Disconnect)
            .map_err(|_| anyhow!("session is not available"))?;
    }
    Ok(())
}

#[frb(sync)]
pub fn ssh_dispose_session(session_id: i32) {
    registry().lock().unwrap().remove(&session_id);
}

#[frb(sync)]
pub fn ssh_probe_tcp(host: String, port: u16) -> TcpProbeResult {
    let address = format!("{host}:{port}");
    let socket_addr = match address.to_socket_addrs() {
        Ok(mut addresses) => match addresses.next() {
            Some(addr) => addr,
            None => {
                return TcpProbeResult::error(format!("cannot resolve {address}"));
            }
        },
        Err(err) => {
            return TcpProbeResult::error(format!("dns lookup failed for {address}: {err}"));
        }
    };

    let start = Instant::now();
    match TcpStream::connect_timeout(&socket_addr, Duration::from_secs(3)) {
        Ok(_) => TcpProbeResult {
            reachable: true,
            message: format!("tcp {address} is reachable"),
            latency_ms: Some(start.elapsed().as_millis().min(u128::from(u32::MAX)) as u32),
        },
        Err(err) => TcpProbeResult {
            reachable: false,
            message: format!("tcp {address} is unreachable: {err}"),
            latency_ms: None,
        },
    }
}

fn probe_ssh_banner(host: &str, port: u16, wait: Duration) -> Result<String> {
    let address = format!("{host}:{port}");
    let socket_addr = address
        .to_socket_addrs()
        .with_context(|| format!("dns lookup failed for {address}"))?
        .next()
        .ok_or_else(|| anyhow!("cannot resolve {address}"))?;

    let stream = TcpStream::connect_timeout(&socket_addr, wait)
        .with_context(|| format!("tcp connect failed for {address}"))?;
    stream
        .set_read_timeout(Some(wait))
        .context("unable to set ssh banner read timeout")?;

    let mut reader = BufReader::new(stream);
    let mut banner = String::new();
    let read = reader
        .read_line(&mut banner)
        .context("failed while reading ssh server banner")?;

    if read == 0 {
        return Err(anyhow!(
            "server closed connection before sending ssh banner"
        ));
    }

    let banner = banner.trim().to_string();
    if !banner.starts_with("SSH-") {
        return Err(anyhow!("unexpected banner from server: {banner}"));
    }

    Ok(banner)
}

fn registry() -> &'static Mutex<HashMap<i32, Arc<SshSessionHandle>>> {
    SESSION_REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

fn get_session(session_id: i32) -> Result<Arc<SshSessionHandle>> {
    registry()
        .lock()
        .unwrap()
        .get(&session_id)
        .cloned()
        .ok_or_else(|| anyhow!("session {session_id} not found"))
}

async fn run_session(
    config: SshConfig,
    cols: u32,
    rows: u32,
    mut command_receiver: mpsc::UnboundedReceiver<SessionCommand>,
    status: &Arc<Mutex<SessionStatus>>,
    output: &Arc<Mutex<Vec<TerminalChunk>>>,
) -> Result<()> {
    log_step(
        output,
        false,
        format!(
            "resolving and connecting to {}:{}",
            config.host, config.port
        ),
    );
    log_step(output, false, "waiting for ssh server banner");
    let banner = probe_ssh_banner(&config.host, config.port, Duration::from_secs(3))?;
    log_step(output, false, format!("server banner: {banner}"));

    let client_config = Arc::new(client::Config {
        inactivity_timeout: Some(Duration::from_secs(60)),
        ..<_>::default()
    });

    let mut handle = timeout(
        CONNECT_TIMEOUT,
        client::connect(
            client_config,
            (config.host.as_str(), config.port),
            ClientHandler,
        ),
    )
    .await
    .map_err(|_| {
        anyhow!(
            "connection timed out after {}s, please check server IP, port 22, and that the phone can reach the LAN",
            CONNECT_TIMEOUT.as_secs()
        )
    })?
    .with_context(|| format!("unable to reach {}:{}", config.host, config.port))?;
    log_step(output, false, "tcp connection established");

    set_status(
        status,
        SessionPhase::Authenticating,
        Some(format!("Authenticating as {}", config.username)),
    );
    log_step(
        output,
        false,
        format!("starting authentication for {}", config.username),
    );

    timeout(AUTH_TIMEOUT, authenticate(&mut handle, &config))
        .await
        .map_err(|_| anyhow!("authentication timed out after {}s", AUTH_TIMEOUT.as_secs()))??;
    log_step(output, false, "authentication accepted");

    let channel_result = timeout(CHANNEL_TIMEOUT, handle.channel_open_session())
        .await
        .map_err(|_| {
            anyhow!(
                "opening ssh channel timed out after {}s",
                CHANNEL_TIMEOUT.as_secs()
            )
        })?;
    let mut channel = channel_result.context("unable to open ssh session channel")?;
    log_step(output, false, "ssh session channel opened");

    let pty_result = timeout(
        CHANNEL_TIMEOUT,
        channel.request_pty(false, "xterm-256color", cols, rows, 0, 0, &[]),
    )
    .await
    .map_err(|_| {
        anyhow!(
            "requesting remote pty timed out after {}s",
            CHANNEL_TIMEOUT.as_secs()
        )
    })?;
    pty_result.context("unable to allocate remote pty")?;
    log_step(
        output,
        false,
        format!("remote pty allocated at {cols}x{rows}"),
    );

    let shell_result = timeout(CHANNEL_TIMEOUT, channel.request_shell(true))
        .await
        .map_err(|_| {
            anyhow!(
                "starting remote shell timed out after {}s",
                CHANNEL_TIMEOUT.as_secs()
            )
        })?;
    shell_result.context("unable to start remote shell")?;
    log_step(output, false, "remote shell started");

    set_status(
        status,
        SessionPhase::Connected,
        Some(format!("Connected to {}:{}", config.host, config.port)),
    );

    loop {
        tokio::select! {
            command = command_receiver.recv() => {
                match command {
                    Some(SessionCommand::Input(data)) => {
                        channel
                            .data(data.as_slice())
                            .await
                            .context("failed to send input")?;
                    }
                    Some(SessionCommand::Resize { cols, rows }) => {
                        channel
                            .window_change(cols, rows, 0, 0)
                            .await
                            .context("failed to resize terminal")?;
                    }
                    Some(SessionCommand::Disconnect) | None => {
                        log_step(output, false, "disconnect requested by client");
                        let _ = channel.eof().await;
                        let _ = channel.close().await;
                        break;
                    }
                }
            }
            message = channel.wait() => {
                match message {
                    Some(ChannelMsg::Data { data }) => {
                        push_output(
                            output,
                            TerminalChunk {
                                data: String::from_utf8_lossy(&data).into_owned(),
                                is_error: false,
                            },
                        );
                    }
                    Some(ChannelMsg::ExtendedData { data, .. }) => {
                        push_output(
                            output,
                            TerminalChunk {
                                data: String::from_utf8_lossy(&data).into_owned(),
                                is_error: true,
                            },
                        );
                    }
                    Some(ChannelMsg::ExitStatus { exit_status }) => {
                        push_output(
                            output,
                            TerminalChunk {
                                data: format!("\r\n[remote exit status: {exit_status}]\r\n"),
                                is_error: false,
                            },
                        );
                    }
                    Some(ChannelMsg::Eof) | Some(ChannelMsg::Close) | None => {
                        break;
                    }
                    _ => {}
                }
            }
        }
    }

    let _ = handle
        .disconnect(Disconnect::ByApplication, "client disconnect", "en")
        .await;

    Ok(())
}

async fn authenticate(
    handle: &mut client::Handle<ClientHandler>,
    config: &SshConfig,
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
        "terminal_key_{}_{}.pem",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
    ));
    fs::write(&path, private_key).context("unable to write private key file")?;
    Ok(path)
}

fn set_status(status: &Arc<Mutex<SessionStatus>>, phase: SessionPhase, message: Option<String>) {
    let mut guard = status.lock().unwrap();
    guard.phase = phase;
    guard.message = message;
}

fn push_output(output: &Arc<Mutex<Vec<TerminalChunk>>>, chunk: TerminalChunk) {
    output.lock().unwrap().push(chunk);
}

fn log_step(output: &Arc<Mutex<Vec<TerminalChunk>>>, is_error: bool, message: impl Into<String>) {
    let _ = (output, is_error, message.into());
}
