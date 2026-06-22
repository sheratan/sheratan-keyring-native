import { Copy, MoreHorizontal, Star } from "lucide-react";
import { typeColor } from "../data";

function maskValue(value) {
  return `••••••••••••${value.slice(-4)}`;
}

function relativeDate(date) {
  const days = Math.max(0, Math.round((Date.now() - new Date(date).getTime()) / 86400000));
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 30) return `${days} days ago`;
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(new Date(date));
}

export default function VaultTable({
  items,
  selectedId,
  setSelectedId,
  toggleFavorite,
  onCopy,
  onEdit
}) {
  return (
    <div className="vault-table-wrap">
      <table className="vault-table">
        <thead>
          <tr>
            <th className="star-column"><span className="sr-only">Favorite</span></th>
            <th>Name</th>
            <th>Type</th>
            <th>Value</th>
            <th>Updated</th>
            <th className="actions-column"><span className="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr
              key={item.id}
              className={selectedId === item.id ? "selected" : ""}
              onClick={() => setSelectedId(item.id)}
            >
              <td>
                <button
                  className={`icon-button star-button ${item.favorite ? "favorite" : ""}`}
                  aria-label={item.favorite ? "Remove from favorites" : "Add to favorites"}
                  onClick={(event) => {
                    event.stopPropagation();
                    toggleFavorite(item.id);
                  }}
                >
                  <Star size={17} fill={item.favorite ? "currentColor" : "none"} />
                </button>
              </td>
              <td>
                <div className="item-name-cell">
                  <span className={`type-icon ${typeColor(item.type)}`}>
                    {item.name.slice(0, 1)}
                  </span>
                  <div>
                    <strong>{item.name}</strong>
                    <span>{item.username || item.website || "No username"}</span>
                  </div>
                </div>
              </td>
              <td><span className={`type-label ${typeColor(item.type)}`}>{item.type}</span></td>
              <td><code>{maskValue(item.value)}</code></td>
              <td className="updated-cell">{relativeDate(item.updatedAt)}</td>
              <td>
                <div className="row-actions">
                  <button
                    className="icon-button"
                    aria-label={`Copy ${item.name}`}
                    onClick={(event) => {
                      event.stopPropagation();
                      onCopy(item.value);
                    }}
                  >
                    <Copy size={17} />
                  </button>
                  <button
                    className="icon-button"
                    aria-label={`Edit ${item.name}`}
                    onClick={(event) => {
                      event.stopPropagation();
                      onEdit(item);
                    }}
                  >
                    <MoreHorizontal size={18} />
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {items.length === 0 && (
        <div className="empty-state">
          <span className="empty-icon"><KeyRoundIcon /></span>
          <h3>No items found</h3>
          <p>Try another search or add a new credential.</p>
        </div>
      )}
    </div>
  );
}

function KeyRoundIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="8" cy="15" r="4" />
      <path d="m11 12 8-8m-2 2 2 2m-5 1 2 2" />
    </svg>
  );
}
