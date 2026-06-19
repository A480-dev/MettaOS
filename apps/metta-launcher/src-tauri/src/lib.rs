use nucleo_matcher::pattern::{AtomKind, CaseMatching, Normalization, Pattern};
use nucleo_matcher::{Matcher, Utf32Str};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;
use walkdir::WalkDir;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LaunchItem {
    pub id: String,
    pub label: String,
    pub category: String,
    pub exec: String,
    pub score: i32,
}

fn desktop_dirs() -> Vec<PathBuf> {
    vec![
        PathBuf::from("/usr/share/applications"),
        dirs::home_dir()
            .unwrap_or_default()
            .join(".local/share/applications"),
    ]
}

fn parse_desktop(path: &PathBuf) -> Option<LaunchItem> {
    let text = std::fs::read_to_string(path).ok()?;
    let mut name = None;
    let mut exec = None;
    let mut hidden = false;
    for line in text.lines() {
        if line.starts_with("Name=") {
            name = Some(line.trim_start_matches("Name=").to_string());
        } else if line.starts_with("Exec=") {
            exec = Some(line.trim_start_matches("Exec=").split_whitespace().next()?.to_string());
        } else if line == "Hidden=true" || line == "NoDisplay=true" {
            hidden = true;
        }
    }
    if hidden {
        return None;
    }
    let label = name?;
    let exec = exec?;
    Some(LaunchItem {
        id: path.file_stem()?.to_string_lossy().to_string(),
        label,
        category: "Apps".into(),
        exec,
        score: 0,
    })
}

fn load_items() -> Vec<LaunchItem> {
    let mut items = Vec::new();
    for dir in desktop_dirs() {
        if !dir.is_dir() {
            continue;
        }
        for entry in WalkDir::new(dir).max_depth(1).into_iter().flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
                continue;
            }
            if let Some(item) = parse_desktop(&path.to_path_buf()) {
                items.push(item);
            }
        }
    }
    items.sort_by(|a, b| a.label.cmp(&b.label));
    items
}

#[tauri::command]
fn search(query: String) -> Vec<LaunchItem> {
    let mut items = load_items();
    if query.trim().is_empty() {
        return items.into_iter().take(20).collect();
    }
    let mut matcher = Matcher::new(nucleo_matcher::Config::DEFAULT);
    let mut buf = Vec::<char>::new();
    let mut pattern = Pattern::parse(&query, CaseMatching::Ignore, Normalization::Smart);
    for item in &mut items {
        buf.clear();
        let hay = Utf32Str::new(&item.label, &mut buf);
        item.score = pattern.score(hay, &mut matcher);
    }
    items.retain(|i| i.score > 0);
    items.sort_by(|a, b| b.score.cmp(&a.score));
    items.truncate(20);
    items
}

#[tauri::command]
fn launch(exec: String, in_terminal: bool) -> Result<(), String> {
    if in_terminal {
        Command::new("kitty")
            .arg("-e")
            .arg(&exec)
            .spawn()
            .map_err(|e| e.to_string())?;
    } else {
        Command::new("sh")
            .arg("-lc")
            .arg(&exec)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![search, launch])
        .run(tauri::generate_context!())
        .expect("error running METTA Launcher");
}
