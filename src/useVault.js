import { useEffect, useMemo, useState } from "react";
import { seedItems } from "./data";

const STORAGE_KEY = "keyring-vault-items-v1";

function loadItems() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved ? JSON.parse(saved) : seedItems;
  } catch {
    return seedItems;
  }
}

export function useVault() {
  const [items, setItems] = useState(loadItems);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  }, [items]);

  return useMemo(
    () => ({
      items,
      addItem(item) {
        setItems((current) => [
          { ...item, id: crypto.randomUUID(), updatedAt: new Date().toISOString() },
          ...current
        ]);
      },
      updateItem(item) {
        setItems((current) =>
          current.map((entry) =>
            entry.id === item.id ? { ...item, updatedAt: new Date().toISOString() } : entry
          )
        );
      },
      deleteItem(id) {
        setItems((current) => current.filter((item) => item.id !== id));
      },
      toggleFavorite(id) {
        setItems((current) =>
          current.map((item) =>
            item.id === id ? { ...item, favorite: !item.favorite } : item
          )
        );
      }
    }),
    [items]
  );
}
