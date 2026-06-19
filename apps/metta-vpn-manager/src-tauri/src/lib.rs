use tauri::Manager;

#[tauri::command]
fn app_info() -> String {
    format!("METTA VPN Manager v2.0.0 — METTA OS")
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![app_info])
        .run(tauri::generate_context!())
        .expect("error running METTA VPN Manager");
}
