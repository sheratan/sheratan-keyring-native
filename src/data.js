export const seedItems = [
  {
    id: crypto.randomUUID(),
    name: "OpenAI Production",
    type: "API key",
    value: "sk-proj-7zYq9aK2mX4pR8vN",
    username: "platform@studio.dev",
    website: "https://platform.openai.com",
    notes: "Production key for the main application.",
    tags: ["production", "ai"],
    favorite: true,
    updatedAt: "2026-06-19T15:30:00.000Z"
  },
  {
    id: crypto.randomUUID(),
    name: "GitHub Personal",
    type: "Token",
    value: "ghp_w9R4jH2xQ8kL7aC5",
    username: "shera-dev",
    website: "https://github.com",
    notes: "Personal access token for CLI workflows.",
    tags: ["development"],
    favorite: true,
    updatedAt: "2026-06-17T12:00:00.000Z"
  },
  {
    id: crypto.randomUUID(),
    name: "Stripe Test",
    type: "API key",
    value: "sk_test_51Qx84m3AcX9",
    username: "billing@studio.dev",
    website: "https://dashboard.stripe.com",
    notes: "Test-mode secret key.",
    tags: ["billing", "test"],
    favorite: false,
    updatedAt: "2026-06-13T18:20:00.000Z"
  },
  {
    id: crypto.randomUUID(),
    name: "AWS Root",
    type: "Password",
    value: "K!9r-W2p-Q7z-L4x",
    username: "root@studio.dev",
    website: "https://console.aws.amazon.com",
    notes: "Root account. Prefer IAM users for routine access.",
    tags: ["cloud", "critical"],
    favorite: false,
    updatedAt: "2026-06-02T10:15:00.000Z"
  },
  {
    id: crypto.randomUUID(),
    name: "Figma Token",
    type: "Token",
    value: "figd_N8x6L2s9P3qR",
    username: "design@studio.dev",
    website: "https://figma.com",
    notes: "Design automation token.",
    tags: ["design"],
    favorite: false,
    updatedAt: "2026-05-28T09:45:00.000Z"
  },
  {
    id: crypto.randomUUID(),
    name: "Router Admin",
    type: "Password",
    value: "homeNet#4821",
    username: "admin",
    website: "http://192.168.1.1",
    notes: "Home office router.",
    tags: ["network"],
    favorite: false,
    updatedAt: "2026-05-21T20:00:00.000Z"
  }
];

export const itemTypes = ["Password", "API key", "Token", "Secure note"];

export function typeColor(type) {
  return {
    Password: "violet",
    "API key": "blue",
    Token: "teal",
    "Secure note": "amber"
  }[type] || "blue";
}
