use metta_core::read_state;
use std::collections::HashMap;
use tauri::Manager;

#[tauri::command]
fn load_settings(module: String) -> HashMap<String, String> {
    let mut map = HashMap::new();
    match module.as_str() {
        "apariencia" => {
            map.insert("Tema GTK".into(), "Metta-Dark".into());
            map.insert("HUD escritorio".into(), if read_state().hud_enabled { "Activado" } else { "Desactivado" }.into());
        }
        "pantalla" => {
            map.insert("Backend".into(), "xrandr".into());
        }
        "red" => {
            map.insert("NetworkManager".into(), "activo".into());
        }
        "sonido" => {
            map.insert("PipeWire".into(), "activo".into());
        }
        "sistema" => {
            map.insert("Versión".into(), "METTA OS 2.0.0".into());
            map.insert("Locale".into(), "es_419.UTF-8".into());
        }
        "seguridad" => {
            let state = read_state();
            map.insert("Modo Stealth".into(), if state.stealth_mode { "ON" } else { "OFF" }.into());
            map.insert("Firewall (ufw)".into(), "configurable".into());
        }
        "apps" => {
            map.insert("App Store".into(), "metta-app-store".into());
            map.insert("Updater".into(), "metta-updater".into());
        }
        _ => {}
    }
    map
}

#[tauri::command]
async fn open_app(name: String) -> Result<(), String> {
    std::process::Command::new(name)
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let module = std::env::args()
        .skip_while(|a| !a.starts_with("--module="))
        .find_map(|a| a.strip_prefix("--module=").map(String::from));

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![load_settings, open_app])
        .setup(move |app| {
            if let Some(m) = &module {
                let _ = app.emit("set-module", m.clone());
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error running METTA Control Center");
}
