import { ArrowDownAZ, Check, Menu, Plus, Search, SlidersHorizontal, X } from "lucide-react";
import { useMemo, useState } from "react";
import DetailsPanel from "./components/DetailsPanel";
import ItemDialog from "./components/ItemDialog";
import Sidebar from "./components/Sidebar";
import VaultTable from "./components/VaultTable";
import { useVault } from "./useVault";

export default function App() {
  const vault = useVault();
  const [active, setActive] = useState("All items");
  const [search, setSearch] = useState("");
  const [sort, setSort] = useState("updated");
  const [selectedId, setSelectedId] = useState(null);
  const [dialog, setDialog] = useState({ open: false, item: null });
  const [toast, setToast] = useState("");
  const [mobileNav, setMobileNav] = useState(false);

  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase();
    const result = vault.items.filter((item) => {
      const categoryMatch =
        active === "All items" ||
        (active === "Favorites" ? item.favorite : item.type === active);
      const searchMatch =
        !query ||
        [item.name, item.type, item.username, item.website, item.notes, ...item.tags]
          .join(" ")
          .toLowerCase()
          .includes(query);
      return categoryMatch && searchMatch;
    });

    return result.sort((a, b) => {
      if (sort === "name") return a.name.localeCompare(b.name);
      if (sort === "type") return a.type.localeCompare(b.type);
      return new Date(b.updatedAt) - new Date(a.updatedAt);
    });
  }, [active, search, sort, vault.items]);

  const selected = vault.items.find((item) => item.id === selectedId);
  const title = active === "Password" ? "Passwords" : active === "API key" ? "API keys" : active === "Token" ? "Tokens" : active === "Secure note" ? "Secure notes" : active;

  function notify(message) {
    setToast(message);
    window.clearTimeout(notify.timeout);
    notify.timeout = window.setTimeout(() => setToast(""), 2200);
  }

  async function copy(value) {
    await navigator.clipboard.writeText(value);
    notify("Copied to clipboard");
  }

  function save(item) {
    if (item.id) vault.updateItem(item);
    else vault.addItem(item);
    setDialog({ open: false, item: null });
    notify(item.id ? "Item updated" : "Item added to vault");
  }

  function remove(id) {
    if (!window.confirm("Delete this item from your vault?")) return;
    vault.deleteItem(id);
    setSelectedId(null);
    notify("Item deleted");
  }

  function exportMigration() {
    const accepted = window.confirm(
      "This migration file contains plaintext secrets. Import it into the native app immediately, then delete it and empty Trash. Continue?"
    );
    if (!accepted) return;
    const document = {
      format: "keyring-browser-migration",
      version: 1,
      exportedAt: new Date().toISOString(),
      items: vault.items
    };
    const blob = new Blob([JSON.stringify(document, null, 2)], {
      type: "application/json"
    });
    const url = URL.createObjectURL(blob);
    const link = window.document.createElement("a");
    link.href = url;
    link.download = `keyring-migration-${new Date().toISOString().slice(0, 10)}.json`;
    link.click();
    URL.revokeObjectURL(url);
    notify("Plaintext migration exported — import it, then delete it");
  }

  return (
    <div className="app-shell">
      <div className={`mobile-sidebar ${mobileNav ? "open" : ""}`}>
        <Sidebar
          active={active}
          setActive={(value) => { setActive(value); setMobileNav(false); }}
          count={vault.items.length}
          openSettings={exportMigration}
        />
      </div>
      {mobileNav && <button className="nav-scrim" onClick={() => setMobileNav(false)} aria-label="Close navigation" />}

      <Sidebar
        active={active}
        setActive={setActive}
        count={vault.items.length}
        openSettings={exportMigration}
      />

      <main className="main">
        <header className="topbar">
          <button className="icon-button menu-button" onClick={() => setMobileNav(true)} aria-label="Open navigation">
            <Menu size={20} />
          </button>
          <div className="page-title">
            <h1>{title}</h1>
            <p>{filtered.length} {filtered.length === 1 ? "item" : "items"} in this view</p>
          </div>
          <div className="toolbar">
            <label className="search-field">
              <Search size={18} />
              <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search vault" aria-label="Search vault" />
              {search && <button onClick={() => setSearch("")} aria-label="Clear search"><X size={15} /></button>}
            </label>
            <label className="sort-control">
              <ArrowDownAZ size={17} />
              <select value={sort} onChange={(e) => setSort(e.target.value)} aria-label="Sort items">
                <option value="updated">Recently updated</option>
                <option value="name">Name</option>
                <option value="type">Type</option>
              </select>
            </label>
            <button className="filter-button" aria-label="Filter"><SlidersHorizontal size={18} /></button>
            <button className="primary-button add-button" onClick={() => setDialog({ open: true, item: null })}>
              <Plus size={18} /> Add item
            </button>
          </div>
        </header>

        <div className={`content-grid ${selected ? "with-details" : ""}`}>
          <section className="vault-content" aria-label="Vault items">
            <VaultTable
              items={filtered}
              selectedId={selectedId}
              setSelectedId={setSelectedId}
              toggleFavorite={vault.toggleFavorite}
              onCopy={copy}
              onEdit={(item) => setDialog({ open: true, item })}
            />
          </section>
          <DetailsPanel
            item={selected}
            onClose={() => setSelectedId(null)}
            onCopy={copy}
            onEdit={(item) => setDialog({ open: true, item })}
            onDelete={remove}
            toggleFavorite={vault.toggleFavorite}
          />
        </div>
      </main>

      <ItemDialog
        open={dialog.open}
        item={dialog.item}
        onClose={() => setDialog({ open: false, item: null })}
        onSave={save}
      />

      {toast && <div className="toast"><Check size={17} />{toast}</div>}
    </div>
  );
}
