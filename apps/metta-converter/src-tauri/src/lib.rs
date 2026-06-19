use metta_core::run_shell;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use tauri::{Emitter, Window};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConvertConfig {
    pub name: String,
    pub category: String,
    pub icon_path: Option<String>,
}

fn emit(window: &Window, pct: u8, msg: &str) {
    let _ = window.emit("convert_progress", serde_json::json!({ "pct": pct, "msg": msg }));
}

fn detect_type(source: &Path) -> Result<String, String> {
    if source.extension().and_then(|e| e.to_str()) == Some("exe") {
        return Ok("exe".into());
    }
    if source.extension().and_then(|e| e.to_str()) == Some("app") || source.join("Contents").is_dir() {
        return Ok("app".into());
    }
    Err("Tipo no soportado".into())
}

fn write_meta(tmp: &Path, config: &ConvertConfig, app_type: &str) -> Result<(), String> {
    fs::create_dir_all(tmp.join("META")).map_err(|e| e.to_string())?;
    let id = format!("com.metta.{}", config.name.to_lowercase().replace(' ', "_"));
    let manifest = serde_json::json!({
        "name": config.name,
        "id": id,
        "version": "1.0.0",
        "author": "METTA Converter",
        "description": format!("Convertido desde {}", app_type),
        "category": config.category,
        "arch": ["amd64"],
        "mettapp_version": "2",
        "entry": "AppRun",
        "icon": "assets/icon.png"
    });
    fs::write(tmp.join("META/manifest.json"), serde_json::to_string_pretty(&manifest).unwrap())
        .map_err(|e| e.to_string())?;
    let compat = serde_json::json!({
        "layer": if app_type == "exe" { "wine" } else { "darling" },
        "wine_version": if app_type == "exe" { "9.x" } else { null },
        "darling_required": app_type == "app",
        "min_wine": null
    });
    fs::write(tmp.join("META/compat.json"), serde_json::to_string_pretty(&compat).unwrap())
        .map_err(|e| e.to_string())?;
    fs::write(
        tmp.join("META/permissions.json"),
        r#"{"network": false, "filesystem": "user"}"#,
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

fn write_apprun(tmp: &Path, app_type: &str) -> Result<(), String> {
    let script = r#"#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
COMPAT=$(python3 -c "import json;print(json.load(open('$HERE/META/compat.json'))['layer'])")
case "$COMPAT" in
  native) exec "$HERE/APP/main" "$@" ;;
  wine)   exec wine "$HERE/APP/main.exe" "$@" ;;
  darling) exec darling shell "$HERE/APP/main.app/Contents/MacOS/"* "$@" ;;
esac
"#;
    fs::write(tmp.join("AppRun"), script.replace("$HERE", "$HERE")).map_err(|e| e.to_string())?;
    let mut perms = fs::metadata(tmp.join("AppRun")).map_err(|e| e.to_string())?.permissions();
    use std::os::unix::fs::PermissionsExt;
    perms.set_mode(0o755);
    fs::set_permissions(tmp.join("AppRun"), perms).map_err(|e| e.to_string())?;
    let _ = app_type;
    Ok(())
}

#[tauri::command]
async fn convert_to_mettapp(
    source: String,
    config: ConvertConfig,
    window: Window,
) -> Result<String, String> {
    let src = PathBuf::from(&source);
    if !src.exists() {
        return Err("Archivo no encontrado".into());
    }
    emit(&window, 10, "Detectando tipo de archivo...");
    let app_type = detect_type(&src)?;
    let tmp = tempfile::tempdir().map_err(|e| e.to_string())?;
    let root = tmp.path();

    emit(&window, 20, "Extrayendo ícono...");
    fs::create_dir_all(root.join("assets")).map_err(|e| e.to_string())?;
    fs::create_dir_all(root.join("APP")).map_err(|e| e.to_string())?;
    if let Some(icon) = &config.icon_path {
        if Path::new(icon).exists() {
            fs::copy(icon, root.join("assets/icon.png")).ok();
        }
    }
    if !root.join("assets/icon.png").exists() {
        fs::copy(
            "/usr/share/icons/metta/128x128/apps/mettaos.png",
            root.join("assets/icon.png"),
        )
        .ok();
    }

    emit(&window, 35, "Copiando archivos...");
    if app_type == "exe" {
        fs::copy(&src, root.join("APP/main.exe")).map_err(|e| e.to_string())?;
    } else {
        let dest = root.join("APP/main.app");
        run_shell(&format!("cp -a '{}' '{}'", src.display(), dest.display())).await?;
    }

    if app_type == "exe" {
        emit(&window, 55, "Configurando entorno Wine...");
        run_shell("WINEPREFIX=$HOME/.metta/wine-base wineboot --init 2>/dev/null || true").await.ok();
    }

    emit(&window, 70, "Generando metadatos...");
    write_meta(root, &config, &app_type)?;
    write_apprun(root, &app_type)?;

    emit(&window, 85, "Empaquetando .mettapp...");
    let output = dirs::download_dir()
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join(format!("{}.mettapp", config.name.to_lowercase().replace(' ', "_")));
    let status = Command::new("mksquashfs")
        .arg(root)
        .arg(&output)
        .args(["-noappend", "-comp", "xz", "-all-root"])
        .status()
        .map_err(|e| e.to_string())?;
    if !status.success() {
        return Err("mksquashfs falló".into());
    }
    emit(&window, 100, "¡Listo!");
    Ok(output.display().to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![convert_to_mettapp])
        .run(tauri::generate_context!())
        .expect("error running METTA Converter");
}
