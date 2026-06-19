use metta_core::{read_state, write_state, MettaState};
use std::fs;
use std::path::PathBuf;

#[tauri::command]
async fn finish_welcome(profile: String, wine: bool) -> Result<(), String> {
    let mut state = read_state();
    state.profile = Some(profile);
    write_state(&state)?;
    if wine {
        std::process::Command::new("bash")
            .arg("-lc")
            .arg("mkdir -p ~/.metta/wine-base && WINEPREFIX=~/.metta/wine-base winetricks -q corefonts vcrun2019 2>/dev/null || true")
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
fn remove_autostart() -> Result<(), String> {
    let path = dirs::home_dir()
        .unwrap_or_default()
        .join(".config/autostart/metta-welcome.desktop");
    if path.is_file() {
        fs::remove_file(path).map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
fn open_app(name: String) -> Result<(), String> {
    std::process::Command::new(name).spawn().map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
async fn close_window(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(w) = app.get_webview_window("main") {
        w.close().map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![finish_welcome, remove_autostart, open_app, close_window])
        .run(tauri::generate_context!())
        .expect("error running METTA Welcome");
}
