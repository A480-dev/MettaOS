use metta_core::{catalog_path, run_shell};
use serde::{Deserialize, Serialize};
use std::fs;
use tauri::{Emitter, Window};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CatalogApp {
    pub id: String,
    pub name: String,
    pub description: String,
    pub category: String,
    pub install: String,
    pub icon: String,
}

#[tauri::command]
fn list_catalog() -> Result<Vec<CatalogApp>, String> {
    let data = fs::read_to_string(catalog_path("app-catalog.json")).map_err(|e| e.to_string())?;
    serde_json::from_str(&data).map_err(|e| e.to_string())
}

#[tauri::command]
async fn get_installed() -> Result<Vec<String>, String> {
    let out = run_shell("dpkg-query -W -f='${Package}\n' 2>/dev/null | head -5000").await?;
    Ok(out.lines().map(String::from).collect())
}

#[tauri::command]
async fn install_tool(app_id: String, window: Window) -> Result<(), String> {
    let apps = list_catalog()?;
    let app = apps.into_iter().find(|a| a.id == app_id).ok_or("App no encontrada")?;
    let _ = window.emit("install_progress", format!("Instalando {}…", app.name));
    run_shell(&format!("sudo {}", app.install)).await?;
    let _ = window.emit("install_progress", "Completado");
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![list_catalog, get_installed, install_tool])
        .run(tauri::generate_context!())
        .expect("error running METTA App Store");
}
