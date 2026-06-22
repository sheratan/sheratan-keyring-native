import { Copy, ExternalLink, Eye, EyeOff, Pencil, Star, Trash2, X } from "lucide-react";
import { useState } from "react";
import { typeColor } from "../data";

export default function DetailsPanel({
  item,
  onClose,
  onCopy,
  onEdit,
  onDelete,
  toggleFavorite
}) {
  const [revealed, setRevealed] = useState(false);

  if (!item) return null;

  return (
    <aside className="details-panel">
      <div className="details-head">
        <button className="icon-button mobile-close" onClick={onClose} aria-label="Close details">
          <X size={18} />
        </button>
        <button className="icon-button" onClick={() => toggleFavorite(item.id)} aria-label="Favorite">
          <Star size={18} fill={item.favorite ? "currentColor" : "none"} />
        </button>
        <button className="icon-button danger-hover" onClick={() => onDelete(item.id)} aria-label="Delete">
          <Trash2 size={18} />
        </button>
      </div>

      <div className={`details-avatar ${typeColor(item.type)}`}>{item.name.slice(0, 1)}</div>
      <h2>{item.name}</h2>
      <span className={`type-label ${typeColor(item.type)}`}>{item.type}</span>

      <div className="detail-section">
        <span className="detail-label">Secret</span>
        <div className="secret-field">
          <code>{revealed ? item.value : "••••••••••••••••"}</code>
          <button className="icon-button" onClick={() => setRevealed(!revealed)} aria-label="Reveal secret">
            {revealed ? <EyeOff size={17} /> : <Eye size={17} />}
          </button>
          <button className="icon-button" onClick={() => onCopy(item.value)} aria-label="Copy secret">
            <Copy size={17} />
          </button>
        </div>
      </div>

      <dl className="detail-list">
        <div>
          <dt>Username</dt>
          <dd>{item.username || "—"}</dd>
        </div>
        <div>
          <dt>Website</dt>
          <dd>
            {item.website ? (
              <a href={item.website} target="_blank" rel="noreferrer">
                {item.website.replace(/^https?:\/\//, "")} <ExternalLink size={13} />
              </a>
            ) : "—"}
          </dd>
        </div>
        <div>
          <dt>Tags</dt>
          <dd className="tags">
            {item.tags.length ? item.tags.map((tag) => <span key={tag}>{tag}</span>) : "—"}
          </dd>
        </div>
        <div>
          <dt>Notes</dt>
          <dd>{item.notes || "—"}</dd>
        </div>
        <div>
          <dt>Last updated</dt>
          <dd>{new Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(item.updatedAt))}</dd>
        </div>
      </dl>

      <button className="secondary-button edit-button" onClick={() => onEdit(item)}>
        <Pencil size={16} /> Edit item
      </button>
    </aside>
  );
}
