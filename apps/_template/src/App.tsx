import { invoke } from "@tauri-apps/api/core";
import { useEffect, useState } from "react";

export default function App() {
  const [info, setInfo] = useState("Cargando…");

  useEffect(() => {
    invoke<string>("app_info")
      .then(setInfo)
      .catch((e) => setInfo(String(e)));
  }, []);

  return (
    <div className="app-shell">
      <h1>__APP_TITLE__</h1>
      <p>{info}</p>
    </div>
  );
}
