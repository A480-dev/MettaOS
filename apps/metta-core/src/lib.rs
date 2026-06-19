use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use tokio::process::Command;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct MettaState {
    pub version: String,
    pub theme: String,
    pub profile: Option<String>,
    #[serde(rename = "hudEnabled")]
    pub hud_enabled: bool,
    #[serde(rename = "stealthMode")]
    pub stealth_mode: bool,
}

pub fn config_dir() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join(".config/metta")
}

pub fn state_path() -> PathBuf {
    config_dir().join("state.json")
}

pub fn read_state() -> MettaState {
    let path = state_path();
    if let Ok(data) = std::fs::read_to_string(&path) {
        if let Ok(state) = serde_json::from_str(&data) {
            return state;
        }
    }
    MettaState {
        version: "2.0.0".into(),
        theme: "Metta-Dark".into(),
        profile: None,
        hud_enabled: true,
        stealth_mode: false,
    }
}

pub fn write_state(state: &MettaState) -> Result<(), String> {
    let dir = config_dir();
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let data = serde_json::to_string_pretty(state).map_err(|e| e.to_string())?;
    std::fs::write(state_path(), data).map_err(|e| e.to_string())
}

pub async fn run_shell(cmd: &str) -> Result<String, String> {
    let output = Command::new("bash")
        .arg("-lc")
        .arg(cmd)
        .output()
        .await
        .map_err(|e| e.to_string())?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).trim().to_string())
    }
}

pub async fn run_shell_stream(cmd: &str) -> Result<String, String> {
    run_shell(cmd).await
}

pub fn catalog_path(name: &str) -> PathBuf {
    PathBuf::from(format!("/usr/share/metta/{name}"))
}
