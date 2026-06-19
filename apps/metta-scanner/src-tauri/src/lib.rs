use metta_core::run_shell;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Host {
    pub ip: String,
    pub hostname: Option<String>,
    pub mac: Option<String>,
    pub os: Option<String>,
    pub ports: Vec<u16>,
}

#[tauri::command]
async fn scan_network(range: String, scan_type: String) -> Result<Vec<Host>, String> {
    let speed = match scan_type.as_str() {
        "stealth" => "2",
        "complete" => "4",
        _ => "3",
    };
    let cmd = format!(
        "sudo nmap -sS -O --open -T{speed} {range} -oG - 2>/dev/null | grep 'Host:'"
    );
    let out = run_shell(&cmd).await?;
    let mut hosts = Vec::new();
    for line in out.lines() {
        if let Some(ip) = line.split_whitespace().nth(1) {
            hosts.push(Host {
                ip: ip.to_string(),
                hostname: None,
                mac: None,
                os: None,
                ports: vec![],
            });
        }
    }
    Ok(hosts)
}

#[tauri::command]
async fn get_host_detail(ip: String) -> Result<String, String> {
    run_shell(&format!("sudo nmap -sV -sC {ip} -oN - 2>/dev/null | tail -n +1")).await
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![scan_network, get_host_detail])
        .run(tauri::generate_context!())
        .expect("error running METTA Network Scanner");
}
