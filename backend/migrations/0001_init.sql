CREATE TABLE users (
  id TEXT PRIMARY KEY,
  apple_sub TEXT NOT NULL UNIQUE,
  apple_refresh_token TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  key_id TEXT UNIQUE,
  public_key TEXT,
  counter INTEGER NOT NULL DEFAULT 0,
  user_id TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE refresh_tokens (
  token_hash TEXT PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL
);

CREATE TABLE challenges (
  id TEXT PRIMARY KEY,
  expires_at INTEGER NOT NULL
);

CREATE TABLE entitlements (
  id TEXT PRIMARY KEY,
  owner_kind TEXT NOT NULL CHECK (owner_kind IN ('user', 'device')),
  owner_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  original_transaction_id TEXT UNIQUE
);
CREATE INDEX idx_entitlements_owner ON entitlements (owner_kind, owner_id);

CREATE TABLE usage (
  owner_kind TEXT NOT NULL CHECK (owner_kind IN ('user', 'device')),
  owner_id TEXT NOT NULL,
  day TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (owner_kind, owner_id, day)
);
