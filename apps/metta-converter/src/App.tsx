import { listen } from "@tauri-apps/api/event";
import { invoke } from "@tauri-apps/api/core";
import { open } from "@tauri-apps/plugin-dialog";
import { useEffect, useState } from "react";

const CircularProgress = ({ value }: { value: number }) => {
  const r = 90;
  const circ = 2 * Math.PI * r;
  const offset = circ - (value / 100) * circ;
  return (
    <svg width="200" height="200" viewBox="0 0 200 200">
      <circle cx="100" cy="100" r={r} fill="none" stroke="var(--surface-elevated)" strokeWidth="8" />
      <circle
        cx="100"
        cy="100"
        r={r}
        fill="none"
        stroke="var(--accent-primary)"
        strokeWidth="8"
        strokeLinecap="round"
        strokeDasharray={circ}
        strokeDashoffset={offset}
        transform="rotate(-90 100 100)"
        style={{ transition: "stroke-dashoffset 0.4s ease" }}
      />
      <text x="100" y="105" textAnchor="middle" fill="var(--text-primary)" fontSize="28" fontFamily="JetBrains Mono, monospace">
        {value}%
      </text>
    </svg>
  );
};

export default function App() {
  const [step, setStep] = useState(1);
  const [source, setSource] = useState("");
  const [name, setName] = useState("");
  const [pct, setPct] = useState(0);
  const [msg, setMsg] = useState("");
  const [result, setResult] = useState("");

  useEffect(() => {
    const un = listen<{ pct: number; msg: string }>("convert_progress", (e) => {
      setPct(e.payload.pct);
      setMsg(e.payload.msg);
    });
    return () => {
      un.then((f) => f());
    };
  }, []);

  const pick = async () => {
    const file = await open({ multiple: false });
    if (typeof file === "string") {
      setSource(file);
      setName(file.split("/").pop()?.replace(/\.(exe|app)$/i, "") ?? "App");
      setStep(2);
    }
  };

  const convert = async () => {
    setStep(3);
    const out = await invoke<string>("convert_to_mettapp", {
      source,
      config: { name, category: "utility", icon_path: null },
    });
    setResult(out);
    setStep(4);
  };

  return (
    <div className="app-shell" style={{ alignItems: "center", textAlign: "center" }}>
      <h1>METTA Converter</h1>
      {step === 1 && (
        <div className="metta-card" style={{ width: 480, cursor: "pointer" }} onClick={pick}>
          <p>Arrastra tu .exe o .app aquí — o haz click para seleccionar</p>
        </div>
      )}
      {step === 2 && (
        <div className="metta-card" style={{ width: 480 }}>
          <p>{source}</p>
          <input className="metta-input" value={name} onChange={(e) => setName(e.target.value)} />
          <button className="metta-btn metta-btn-primary" style={{ marginTop: 12 }} onClick={convert}>
            Convertir
          </button>
        </div>
      )}
      {step === 3 && (
        <>
          <CircularProgress value={pct} />
          <p>{msg}</p>
        </>
      )}
      {step === 4 && (
        <div className="metta-card">
          <p style={{ color: "var(--success)" }}>Tu app está lista</p>
          <code>{result}</code>
        </div>
      )}
    </div>
  );
}
