import { invoke } from "@tauri-apps/api/core";
import { Monitor, Palette, Shield, Volume2, Wifi, AppWindow, Settings2 } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

const MODULES = [
  { id: "apariencia", label: "Apariencia", icon: Palette },
  { id: "pantalla", label: "Pantalla", icon: Monitor },
  { id: "red", label: "Red", icon: Wifi },
  { id: "sonido", label: "Sonido", icon: Volume2 },
  { id: "sistema", label: "Sistema", icon: Settings2 },
  { id: "seguridad", label: "Seguridad", icon: Shield },
  { id: "apps", label: "Apps", icon: AppWindow },
] as const;

type ModuleId = (typeof MODULES)[number]["id"];

export default function App() {
  const [module, setModule] = useState<ModuleId>("apariencia");
  const [query, setQuery] = useState("");
  const [settings, setSettings] = useState<Record<string, string>>({});

  useEffect(() => {
    invoke<Record<string, string>>("load_settings", { module }).then(setSettings).catch(console.error);
  }, [module]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return MODULES;
    return MODULES.filter((m) => m.label.toLowerCase().includes(q));
  }, [query]);

  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      <aside style={{ width: 220, background: "var(--surface-panel)", borderRight: "1px solid var(--border-subtle)", padding: 16 }}>
        <h2 style={{ margin: "0 0 12px", color: "var(--accent-primary)", fontSize: 18 }}>METTA</h2>
        <input className="metta-input" placeholder="Buscar…" value={query} onChange={(e) => setQuery(e.target.value)} />
        <nav style={{ marginTop: 16, display: "flex", flexDirection: "column", gap: 6 }}>
          {filtered.map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              className="metta-btn"
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                background: module === id ? "var(--surface-elevated)" : "transparent",
                borderColor: module === id ? "var(--accent-primary)" : "var(--border-subtle)",
              }}
              onClick={() => setModule(id)}
            >
              <Icon size={16} /> {label}
            </button>
          ))}
        </nav>
      </aside>
      <main style={{ flex: 1, padding: 24 }}>
        <h1>{MODULES.find((m) => m.id === module)?.label}</h1>
        <div className="metta-card" style={{ marginTop: 16 }}>
          {Object.entries(settings).length === 0 ? (
            <p>Sin opciones cargadas para este módulo.</p>
          ) : (
            Object.entries(settings).map(([k, v]) => (
              <div key={k} style={{ display: "flex", justifyContent: "space-between", padding: "8px 0", borderBottom: "1px solid var(--border-subtle)" }}>
                <span>{k}</span>
                <code>{v}</code>
              </div>
            ))
          )}
        </div>
        {module === "apps" && (
          <div style={{ marginTop: 16, display: "flex", gap: 8 }}>
            <button className="metta-btn metta-btn-primary" onClick={() => invoke("open_app", { name: "metta-app-store" })}>App Store</button>
            <button className="metta-btn" onClick={() => invoke("open_app", { name: "metta-updater" })}>Updater</button>
          </div>
        )}
        {module === "red" && (
          <button className="metta-btn metta-btn-primary" style={{ marginTop: 16 }} onClick={() => invoke("open_app", { name: "metta-vpn-manager" })}>
            VPN Manager
          </button>
        )}
      </main>
    </div>
  );
}
