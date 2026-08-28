use serde::{Deserialize, Serialize};
use std::fs;
use std::io::{Read, Seek, SeekFrom};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;
use tauri::{AppHandle, Emitter};

#[derive(Debug, Serialize, Deserialize, Clone)]
struct Disk {
    name: String,
    size: String,
    model: String,
    path: String,
}

#[derive(Debug, Deserialize)]
struct LsblkOutput {
    blockdevices: Vec<LsblkDevice>,
}

#[derive(Debug, Deserialize)]
struct LsblkDevice {
    name: Option<String>,
    size: Option<String>,
    model: Option<String>,
    #[serde(rename = "type")]
    dev_type: Option<String>,
    tran: Option<String>,
    rm: Option<bool>,
}

fn engine_path() -> &'static str {
    "/usr/lib/metta/metta-installer-engine.sh"
}

#[tauri::command]
fn list_disks() -> Result<Vec<Disk>, String> {
    let output = Command::new("lsblk")
        .args(["-J", "-d", "-o", "NAME,SIZE,MODEL,TYPE,TRAN,RM,ROTA"])
        .output()
        .map_err(|e| e.to_string())?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let parsed: LsblkOutput =
        serde_json::from_slice(&output.stdout).map_err(|e| e.to_string())?;

    let mut disks = Vec::new();
    for dev in parsed.blockdevices {
        if dev.dev_type.as_deref() != Some("disk") {
            continue;
        }
        let name = dev.name.unwrap_or_default();
        if name.is_empty() {
            continue;
        }
        let is_usb = dev.tran.as_deref() == Some("usb") || dev.rm.unwrap_or(false);
        let is_live = name.starts_with("loop");
        if is_usb || is_live {
            continue;
        }
        disks.push(Disk {
            path: format!("/dev/{name}"),
            name: name.clone(),
            size: dev.size.unwrap_or_else(|| "?".into()),
            model: dev.model.unwrap_or_else(|| "Disco".into()),
        });
    }
    Ok(disks)
}

fn tail_log(app: &AppHandle, path: &str, from: u64) -> Result<u64, String> {
    let mut file = fs::File::open(path).map_err(|e| e.to_string())?;
    let len = file.metadata().map_err(|e| e.to_string())?.len();
    if len <= from {
        return Ok(from);
    }
    file.seek(SeekFrom::Start(from)).map_err(|e| e.to_string())?;
    let mut buf = String::new();
    file.read_to_string(&mut buf).map_err(|e| e.to_string())?;
    if !buf.is_empty() {
        let _ = app.emit("install-log", buf);
    }
    Ok(len)
}

#[tauri::command]
async fn start_install(
    app: AppHandle,
    disk: String,
    username: String,
    password: String,
    hostname: String,
) -> Result<(), String> {
    if !disk.starts_with("/dev/") {
        return Err("Disco inválido".into());
    }
    if username.is_empty()
        || !username
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '-')
    {
        return Err("El usuario solo puede contener minúsculas, números, _ y -".into());
    }
    if hostname.is_empty()
        || !hostname
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-')
    {
        return Err("Nombre de equipo inválido".into());
    }
    if password.len() < 4 || password.contains(['\n', '\r', ':']) {
        return Err("La contraseña es inválida".into());
    }

    let log_path = "/tmp/metta-install.log";
    let _ = fs::write(log_path, "");
    let password_path = format!("/tmp/metta-installer-password-{}", std::process::id());
    fs::write(&password_path, password.as_bytes()).map_err(|e| e.to_string())?;
    let _ = Command::new("chmod").args(["600", &password_path]).status();

    let script = engine_path();
    let child = Command::new("pkexec")
        .args([
            "env",
            &format!("METTA_INSTALL_LOG={log_path}"),
            script,
            "install",
            &disk,
            &username,
            &password_path,
            &hostname,
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| {
            let _ = fs::remove_file(&password_path);
            format!("No se pudo ejecutar pkexec: {e}")
        })?;

    let app_handle = app.clone();
    let log_file = log_path.to_string();
    let poll = thread::spawn(move || {
        let mut child = child;
        let mut offset = 0u64;
        loop {
            if let Ok(new_off) = tail_log(&app_handle, &log_file, offset) {
                offset = new_off;
            }
            if let Ok(Some(status)) = child.try_wait() {
                if !status.success() {
                    let _ = tail_log(&app_handle, &log_file, offset);
                    return Err(format!("Instalación falló (código {status})"));
                }
                let _ = tail_log(&app_handle, &log_file, offset);
                return Ok(());
            }
            thread::sleep(Duration::from_millis(400));
        }
    });

    poll.join()
        .map_err(|_| "Hilo de instalación interrumpido".to_string())?
}

#[tauri::command]
fn reboot_system() -> Result<(), String> {
    Command::new("pkexec")
        .args(["systemctl", "reboot"])
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![list_disks, start_install, reboot_system])
        .run(tauri::generate_context!())
        .expect("error running METTA Installer");
}
