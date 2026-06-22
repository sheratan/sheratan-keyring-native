import {
  Braces,
  FileLock2,
  Heart,
  KeyRound,
  List,
  LockKeyhole,
  Upload,
  ShieldCheck
} from "lucide-react";

const navigation = [
  { label: "All items", value: "All items", icon: List },
  { label: "Favorites", value: "Favorites", icon: Heart },
  { label: "Passwords", value: "Password", icon: LockKeyhole },
  { label: "API keys", value: "API key", icon: KeyRound },
  { label: "Tokens", value: "Token", icon: Braces },
  { label: "Secure notes", value: "Secure note", icon: FileLock2 }
];

export default function Sidebar({ active, setActive, count, openSettings }) {
  return (
    <aside className="sidebar">
      <div className="brand">
        <span className="brand-mark"><LockKeyhole size={18} strokeWidth={2.2} /></span>
        <span>Keyring</span>
      </div>

      <nav className="nav-list" aria-label="Vault categories">
        {navigation.map(({ label, value, icon: Icon }) => (
          <button
            className={`nav-item ${active === value ? "active" : ""}`}
            key={value}
            onClick={() => setActive(value)}
          >
            <Icon size={18} />
            <span>{label}</span>
            {value === "All items" && <span className="nav-count">{count}</span>}
          </button>
        ))}
      </nav>

      <div className="sidebar-footer">
        <button className="nav-item" onClick={openSettings}>
          <Upload size={18} />
          <span>Export migration</span>
        </button>
        <div className="security-note">
          <ShieldCheck size={18} />
          <div>
            <strong>Stored locally</strong>
            <span>On this browser only</span>
          </div>
        </div>
      </div>
    </aside>
  );
}
