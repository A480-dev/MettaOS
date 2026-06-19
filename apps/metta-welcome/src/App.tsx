import { invoke } from "@tauri-apps/api/core";
import { useState } from "react";

const PROFILES = [
  { id: "ctf", label: "CTF / Competencias" },
  { id: "pro", label: "Pentesting profesional" },
  { id: "learn", label: "Aprendizaje" },
  { id: "dev", label: "Desarrollo" },
  { id: "general", label: "Uso general" },
];

export default function App() {
  const [step, setStep] = useState(1);
  const [profile, setProfile] = useState("general");
  const [wine, setWine] = useState(false);

  const finish = async () => {
    await invoke("finish_welcome", { profile, wine });
    await invoke("remove_autostart");
    await invoke("close_window");
  };

  return (
    <div className="app-shell" style={{ maxWidth: 720, margin: "0 auto" }}>
      {step === 1 && (
        <>
          <h1>Bienvenido a METTA OS 2.0</h1>
          <p>Distro Matrix para pentesting y productividad.</p>
          <button className="metta-btn metta-btn-primary" onClick={() => setStep(2)}>Continuar</button>
        </>
      )}
      {step === 2 && (
        <>
          <h1>¿Cuál es tu caso de uso?</h1>
          {PROFILES.map((p) => (
            <label key={p.id} style={{ display: "block", margin: "8px 0" }}>
              <input type="radio" name="profile" checked={profile === p.id} onChange={() => setProfile(p.id)} /> {p.label}
            </label>
          ))}
          <button className="metta-btn metta-btn-primary" onClick={() => setStep(3)}>Siguiente</button>
        </>
      )}
      {step === 3 && (
        <>
          <h1>Compatibilidad Windows</h1>
          <label>
            <input type="checkbox" checked={wine} onChange={(e) => setWine(e.target.checked)} />
            Inicializar Wine (winetricks corefonts vcrun2019)
          </label>
          <button className="metta-btn metta-btn-primary" onClick={() => setStep(4)}>Continuar</button>
        </>
      )}
      {step === 4 && (
        <>
          <h1>¡Listo!</h1>
          <p>Tu perfil: {profile}</p>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            <button className="metta-btn" onClick={() => invoke("open_app", { name: "metta-terminal" })}>Terminal</button>
            <button className="metta-btn" onClick={() => invoke("open_app", { name: "metta-app-store" })}>App Store</button>
            <button className="metta-btn metta-btn-primary" onClick={finish}>Cerrar</button>
          </div>
        </>
      )}
    </div>
  );
}
