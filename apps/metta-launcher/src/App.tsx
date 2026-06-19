import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { useEffect, useState } from "react";

type Item = { id: string; label: string; category: string; exec: string; score: number };

export default function App() {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState<Item[]>([]);
  const [idx, setIdx] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => {
      invoke<Item[]>("search", { query }).then(setItems).catch(console.error);
      setIdx(0);
    }, 80);
    return () => clearTimeout(t);
  }, [query]);

  useEffect(() => {
    const onKey = async (e: KeyboardEvent) => {
      if (e.key === "Escape") await getCurrentWindow().close();
      if (e.key === "ArrowDown") setIdx((i) => Math.min(i + 1, items.length - 1));
      if (e.key === "ArrowUp") setIdx((i) => Math.max(i - 1, 0));
      if (e.key === "Enter" && items[idx]) {
        await invoke("launch", { exec: items[idx].exec, inTerminal: e.ctrlKey });
        await getCurrentWindow().close();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [items, idx]);

  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "var(--surface-overlay)" }}>
      <div className="metta-card" style={{ width: 640, padding: 0, overflow: "hidden" }}>
        <input
          autoFocus
          className="metta-input"
          style={{ border: "none", borderRadius: 0, borderBottom: "1px solid var(--border-subtle)" }}
          placeholder="Buscar apps, herramientas, archivos…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <ul style={{ listStyle: "none", margin: 0, padding: 0, maxHeight: 360, overflow: "auto" }}>
          {items.map((item, i) => (
            <li
              key={item.id}
              style={{
                padding: "10px 16px",
                background: i === idx ? "var(--surface-elevated)" : "transparent",
                cursor: "pointer",
              }}
              onMouseEnter={() => setIdx(i)}
              onClick={async () => {
                await invoke("launch", { exec: item.exec, inTerminal: false });
                await getCurrentWindow().close();
              }}
            >
              <strong>{item.label}</strong>
              <span style={{ color: "var(--text-secondary)", marginLeft: 8 }}>{item.category}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
