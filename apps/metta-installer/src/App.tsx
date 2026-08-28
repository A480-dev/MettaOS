import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { useCallback, useEffect, useState } from "react";

type Disk = { name: string; size: string; model: string; path: string };

const STEPS = ["Bienvenida", "Disco", "Usuario", "Confirmar", "Instalar", "Listo"];

export default function App() {
  const [step, setStep] = useState(0);
  const [disks, setDisks] = useState<Disk[]>([]);
  const [disk, setDisk] = useState("");
  const [username, setUsername] = useState("metta");
  const [password, setPassword] = useState("");
  const [hostname, setHostname] = useState("mettaos");
  const [log, setLog] = useState("");
  const [installing, setInstalling] = useState(false);
  const [error, setError] = useState("");

  const loadDisks = useCallback(async () => {
    try {
      const list = await invoke<Disk[]>("list_disks");
      setDisks(list);
      if (list.length > 0 && !disk) setDisk(list[0].path);
    } catch (e) {
      setError(String(e));
    }
  }, [disk]);

  useEffect(() => {
    loadDisks();
  }, [loadDisks]);

  useEffect(() => {
    const unlisten = listen<string>("install-log", (ev) => {
      setLog((prev) => prev + ev.payload);
    });
    return () => {
      unlisten.then((fn) => fn());
    };
  }, []);

  const runInstall = async () => {
    setInstalling(true);
    setError("");
    setLog("");
    try {
      await invoke("start_install", { disk, username, password, hostname });
      setStep(5);
    } catch (e) {
      setError(String(e));
    } finally {
      setInstalling(false);
    }
  };

  return (
    <div className="app-shell">
      <div className="step-indicator">
        {STEPS.map((_, i) => (
          <div key={i} className={`step-dot ${i <= step ? "active" : ""}`} />
        ))}
      </div>

      {step === 0 && (
        <>
          <h1>Instalar METTA OS</h1>
          <p>
            Instalador nativo de METTA OS. Copia el sistema live a tu disco, configura GRUB/EFI
            y deja Plasma listo con branding Matrix.
          </p>
          <div className="actions">
            <button className="metta-btn metta-btn-primary" onClick={() => setStep(1)}>
              Comenzar
            </button>
          </div>
        </>
      )}

      {step === 1 && (
        <>
          <h1>Seleccionar disco</h1>
          <p>Se borrarán todos los datos del disco elegido.</p>
          <div className="disk-list">
            {disks.map((d) => (
              <button
                key={d.path}
                type="button"
                className={`disk-option ${disk === d.path ? "selected" : ""}`}
                onClick={() => setDisk(d.path)}
              >
                <strong>{d.path}</strong>
                <span>
                  {d.size} — {d.model || "Disco"}
                </span>
              </button>
            ))}
          </div>
          {disks.length === 0 && <p>No se detectaron discos internos.</p>}
          <div className="actions">
            <button className="metta-btn" onClick={() => setStep(0)}>
              Atrás
            </button>
            <button
              className="metta-btn metta-btn-primary"
              disabled={!disk}
              onClick={() => setStep(2)}
            >
              Siguiente
            </button>
          </div>
        </>
      )}

      {step === 2 && (
        <>
          <h1>Usuario del sistema</h1>
          <div className="field">
            <label>Nombre de usuario</label>
            <input
              className="metta-input"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
          </div>
          <div className="field">
            <label>Contraseña</label>
            <input
              className="metta-input"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          <div className="field">
            <label>Nombre del equipo</label>
            <input
              className="metta-input"
              value={hostname}
              onChange={(e) => setHostname(e.target.value)}
            />
          </div>
          <div className="actions">
            <button className="metta-btn" onClick={() => setStep(1)}>
              Atrás
            </button>
            <button
              className="metta-btn metta-btn-primary"
              disabled={!username || password.length < 4}
              onClick={() => setStep(3)}
            >
              Siguiente
            </button>
          </div>
        </>
      )}

      {step === 3 && (
        <>
          <h1>Confirmar instalación</h1>
          <div className="warn-box">
            Se borrará <strong>{disk}</strong> e instalará METTA OS con usuario{" "}
            <strong>{username}</strong> en <strong>{hostname}</strong>.
          </div>
          <div className="actions">
            <button className="metta-btn" onClick={() => setStep(2)}>
              Atrás
            </button>
            <button
              className="metta-btn metta-btn-primary"
              disabled={installing}
              onClick={async () => {
                setStep(4);
                await runInstall();
              }}
            >
              Instalar ahora
            </button>
          </div>
        </>
      )}

      {step === 4 && (
        <>
          <h1>Instalando…</h1>
          <div className="progress-log">{log || "Iniciando instalador…"}</div>
          {error && <p style={{ color: "var(--error)" }}>{error}</p>}
        </>
      )}

      {step === 5 && (
        <>
          <div className="done-icon">✓</div>
          <h1>Instalación completada</h1>
          <p>METTA OS está listo en {disk}. Reinicia y arranca desde el disco instalado.</p>
          <div className="progress-log">{log}</div>
          <div className="actions">
            <button className="metta-btn metta-btn-primary" onClick={() => invoke("reboot_system")}>
              Reiniciar
            </button>
          </div>
        </>
      )}
    </div>
  );
}
