use metta_core::run_shell;
use serde::{Deserialize, Serialize};
use tauri::Emitter;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpgradePkg {
    pub name: String,
    pub line: String,
}

#[tauri::command]
async fn refresh_upgrades() -> Result<Vec<UpgradePkg>, String> {
    run_shell("sudo apt-get update -qq").await.ok();
    let out = run_shell("apt list --upgradable 2>/dev/null | tail -n +2").await?;
    Ok(out
        .lines()
        .filter(|l| !l.is_empty())
        .map(|line| UpgradePkg {
            name: line.split('/').next().unwrap_or(line).to_string(),
            line: line.to_string(),
        })
        .collect())
}

#[tauri::command]
async fn upgrade_all(window: tauri::Window) -> Result<String, String> {
    let _ = window.emit("upgrade_progress", "Actualizando paquetes…");
    run_shell("sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y").await
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![refresh_upgrades, upgrade_all])
        .run(tauri::generate_context!())
        .expect("error running METTA Updater");
}
