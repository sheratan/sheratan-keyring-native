import { X } from "lucide-react";
import { useEffect, useState } from "react";
import { itemTypes } from "../data";

const blankItem = {
  name: "",
  type: "Password",
  value: "",
  username: "",
  website: "",
  tags: [],
  notes: "",
  favorite: false
};

export default function ItemDialog({ open, item, onClose, onSave }) {
  const [form, setForm] = useState(blankItem);

  useEffect(() => {
    if (open) setForm(item || blankItem);
  }, [item, open]);

  if (!open) return null;

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }));
  }

  function submit(event) {
    event.preventDefault();
    onSave({
      ...form,
      tags: Array.isArray(form.tags)
        ? form.tags
        : form.tags.split(",").map((tag) => tag.trim()).filter(Boolean)
    });
  }

  return (
    <div className="dialog-backdrop" onMouseDown={onClose}>
      <section className="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title" onMouseDown={(e) => e.stopPropagation()}>
        <header>
          <div>
            <h2 id="dialog-title">{item ? "Edit item" : "Add item"}</h2>
            <p>{item ? "Update this credential's details." : "Save a password, token, key, or secure note."}</p>
          </div>
          <button className="icon-button" onClick={onClose} aria-label="Close">
            <X size={19} />
          </button>
        </header>
        <form onSubmit={submit}>
          <label>
            Name
            <input autoFocus required value={form.name} onChange={(e) => update("name", e.target.value)} placeholder="e.g. Production API" />
          </label>
          <div className="form-row">
            <label>
              Type
              <select value={form.type} onChange={(e) => update("type", e.target.value)}>
                {itemTypes.map((type) => <option key={type}>{type}</option>)}
              </select>
            </label>
            <label>
              Username
              <input value={form.username} onChange={(e) => update("username", e.target.value)} placeholder="Optional" />
            </label>
          </div>
          <label>
            Secret value
            <input required value={form.value} onChange={(e) => update("value", e.target.value)} placeholder="Paste your password, key, or token" />
          </label>
          <label>
            Website
            <input type="url" value={form.website} onChange={(e) => update("website", e.target.value)} placeholder="https://example.com" />
          </label>
          <label>
            Tags
            <input
              value={Array.isArray(form.tags) ? form.tags.join(", ") : form.tags}
              onChange={(e) => update("tags", e.target.value)}
              placeholder="work, production, billing"
            />
          </label>
          <label>
            Notes
            <textarea rows="3" value={form.notes} onChange={(e) => update("notes", e.target.value)} placeholder="Add any helpful context" />
          </label>
          <footer>
            <button type="button" className="ghost-button" onClick={onClose}>Cancel</button>
            <button type="submit" className="primary-button">{item ? "Save changes" : "Add to vault"}</button>
          </footer>
        </form>
      </section>
    </div>
  );
}
