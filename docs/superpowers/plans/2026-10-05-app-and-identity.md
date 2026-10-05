# App FilmFinder com login — Backend de identidade + refatoração iOS (Fatias 2 e 3) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o app FilmFinder novo (iOS 18, SwiftData, `Title` unificado) ligado ao Worker, **com identidade real**: dispositivo atestado (App Attest), Sign in with Apple opcional, tokens de sessão, cota diária de buscas por dispositivo/usuário e exclusão de conta. Remove a chave de desenvolvimento embutida.

**Architecture:** Duas partes na mesma entrega. **Parte A (backend, `backend/`)** acrescenta D1 (usuários, devices, cota, entitlements, desafios), tokens (JWT de acesso curto + refresh rotativo), verificação de App Attest, validação do Sign in with Apple e a cota; toda dependência externa é injetada e testada em Vitest/Node (D1 simulado por `node:sqlite`, PKI da Apple simulada por certificados gerados nos testes). **Parte B (app, `FilmFinder/`)** refatora o app em camadas (modelos `@Observable` + serviços; views sem rede) e acrescenta `AuthService` (Keychain + App Attest + renovação de token), `AccountModel`, tela de Ajustes e selo de cota. A Parte A é concluída e publicada em `dev` antes da Parte B.

**Tech Stack:** Backend: TypeScript, Hono, Zod, `jose` (JWT/JWKS), `cbor-x`, `@peculiar/x509` (+ `reflect-metadata`), D1, KV, Vitest. App: Swift (5 durante a migração, 6 no fim), SwiftUI, SwiftData, Swift Testing, CryptoKit, DeviceCheck (App Attest), AuthenticationServices, Security (Keychain), XcodeGen, Lottie.

**Spec:** `docs/superpowers/specs/2026-10-05-filmfinder-relaunch-design.md` (seções 4.2 a 4.4, 4.9, 5.1 a 5.8; itens 2 e 3 da seção 10). Contrato atual do backend: `backend/src/routes/recommendations.ts`, `backend/src/schemas.ts`.

## Global Constraints

**Backend**
- Todos os comandos do backend rodam com `backend/` como diretório de trabalho. Mensagens de commit terminam com `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (ou a atribuição que a sessão exigir).
- Cota: **5** buscas/dia grátis, **100**/dia com a entitlement `unlimited_search` (valores em KV: `limits.free.daily`, `limits.pro.daily`); dia = UTC; `resetsAt` = próxima meia-noite UTC, formato `2026-10-06T00:00:00Z` (sem milissegundos). A busca só consome cota se devolver ≥ 1 título (reserva antes, devolve se falhar ou vier vazio). Vale para o dispositivo **e** para o usuário logado: bloqueia se qualquer um chegou ao limite.
- Token de acesso: JWT HS256, **15 minutos**, só com `sub = deviceId` (o usuário vem do banco a cada requisição, para logout/exclusão valerem na hora). Refresh: aleatório de 32 bytes, guardado como SHA-256, validade **60 dias**, **rotativo** (uso único).
- Desafios (`challenges`): aleatórios de 32 bytes, validade **300 s**, uso único (consumo atômico no D1, não no KV).
- App Attest: `appId = {APPLE_TEAM_ID}.{APPLE_BUNDLE_ID}`; `clientDataHash` do registro = SHA-256(UTF-8 do desafio); `clientData` do refresh = `"{challenge}:{refreshToken}"`; contador da asserção deve crescer; ambientes aceitos vêm de `APPATTEST_ENVS`.
- Sign in with Apple: `aud` = bundle id, `iss` = `https://appleid.apple.com`, claim `nonce` = SHA-256 hex do desafio (o app envia esse hash em `request.nonce`).
- Modo sem atestação (`ALLOW_UNATTESTED=true`) e `x-ai-provider` (`ALLOW_PROVIDER_OVERRIDE=true`) existem **só** no ambiente `dev`; o ambiente de produção os mantém `false`.
- Formato de erro: `{ "error": { "code", "message" } }`. Códigos: `unauthorized` 401, `invalid_input` 400, `invalid_challenge` 400, `forbidden` 403, `attestation_failed` 403, `quota_exceeded` 402, `apple_auth_failed` 401, `apple_unavailable` 502, `ai_unavailable` 503, `internal` 500.
- Nenhuma chave em código ou em commit; segredos via `wrangler secret`; `.dev.vars` continua no `.gitignore`.

**App iOS**
- iOS **18.0** mínimo; Swift 6 com strict concurrency ao final; `@Observable`; `async/await`; SwiftData; XcodeGen e Lottie mantidos; `FilmFinder.xcodeproj` é gerado (já no `.gitignore`).
- Identidade visual mantida (cores `Color.laranja`, `.cinza1`, `.cinza2`, `.roxo`, `.preto`, `.branco`; fonte expandida; animação `pipocascertasmesmo`; onboarding; ícones).
- Views não fazem rede nem acessam `UserDefaults`/Keychain; tipo de mídia é o enum `MediaType`, nunca `"Filmes"`/`"Séries"`.
- O app **não** embute mais chave de API: autentica por token (Bearer) obtido do `AuthService`. `APIBaseURL` vem de `Config/*.xcconfig`.
- Imagens TMDB: pôster `w500`, fundo `w780`, logo `w92`.
- `excludeTmdbIds` = ids do mesmo `mediaType`, favoritos e assistidos primeiro, depois os mais recentes por `recommendedAt`, máx. **200**. Buffer: a busca devolve até 12; mostram-se **3**; trocar usa o buffer sem nova chamada; buffer vazio → nova chamada (consome cota).
- Tela de detalhe mostra o crédito **"Dados de streaming: JustWatch"** (exigência do TMDB) e o `reason` da IA. Sem providers na região: "Não disponível em streaming na sua região".
- Capabilities: `com.apple.developer.applesignin` e `com.apple.developer.devicecheck.appattest-environment` (`development` em Debug, `production` em Release). **App Attest não funciona no simulador**: lá o app registra o dispositivo em modo sem atestação, que só o Worker `dev` aceita.
- Testes do app: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/<Suite>` (sem `-only-testing` roda todos).

## Fora do escopo desta entrega

StoreKit/paywall e webhooks de assinatura (Fatia 4); CI, alertas, produção, App Store Connect (Fatia 5); sincronização da biblioteca entre devices; seletor de região em Ajustes (o app usa a região do aparelho). A entitlement `unlimited_search` já é respeitada pela cota, mas nada a concede ainda além de testes.

## Decisões e desvios da spec (registrados aqui)

1. **Desafios no D1, não no KV:** o KV é eventualmente consistente entre regiões e não permite consumo atômico; o D1 permite `DELETE ... WHERE` com `changes == 1`.
2. **Usuário vem do banco:** o JWT de acesso não carrega `uid`; o middleware lê `devices.user_id` a cada requisição.
3. **Refresh exige asserção** (App Attest) quando o dispositivo foi atestado; dispositivos sem atestação (só `dev`) renovam só com o refresh token.
4. **Token do Apple (`refresh_token`) guardado em texto no D1** para poder revogar na exclusão de conta; endurecer (criptografia em repouso) fica para a Fatia 5.
5. **Exclusão de conta:** se a revogação no Apple falhar, a API devolve 502 e **não** apaga nada (a pessoa pode tentar de novo).
6. **O histórico só recebe os títulos exibidos** (os 12 recebidos viram "já recomendados" para exclusão futura). `LibraryItem` guarda o `Title` como JSON (`snapshotData`).
7. **Importador legado:** `SerieData.duration` = nº de temporadas; o `originalTitle` legado (que guardava a data) é ignorado.
8. **O App Attest só pode ser validado de verdade em iPhone real.** Os testes usam uma PKI simulada com o mesmo formato; a Task BE-9 e a Task iOS-14 trazem o checklist de validação no aparelho.

## Estrutura de arquivos

```
backend/
  migrations/0001_init.sql
  src/
    app.ts, deps.ts, env.ts, settings.ts, config.ts, quota.ts
    lib/        db.ts, crypto.ts, errors.ts (ampliado)
    db/         devices.ts, users.ts, usage.ts, entitlements.ts
    auth/       identity.ts, tokens.ts, challenge.ts, appAttest.ts, appleRootCa.ts, apple.ts, middleware.ts
    routes/     publicAuth.ts, account.ts, recommendations.ts (alterado)
  test/helpers/ sqliteDb.ts, fakeApple.ts, appHarness.ts
  test/         db, quota, tokens, challenge, appAttest, apple, publicAuth, account, recommendations (+ ajustes)
Config/         Debug.xcconfig, Release.xcconfig, Local.xcconfig (gitignored)
project.yml, FilmFinder/FilmFinder.entitlements
FilmFinder/
  App/          FilmFinderApp.swift, AppEnvironment.swift
  Domain/       MediaType, Title, Recommendation (+Quota), Account, TMDBImage, LocaleInfo, Hashing
  Core/API/     APIConfig, APIError, HTTPTransport, AuthorizedAPI, APIClient, AccountService
  Core/Auth/    SecretStore, AppAttestProvider, AuthService
  Data/         LibraryItem, LibraryStore, LegacyImporter
  Features/     Results, Detail, Search, Library, Profile, Account (AccountModel), Settings, Shared, Onboarding, Home
FilmFinderTests/ (Support, Fixtures e uma suíte por unidade)
```

---

# PARTE A — Backend de identidade e cota

### Task BE-1: Dependências, esquema D1 e adaptadores de banco

**Files:**
- Modify: `backend/package.json` (dependências), `backend/tsconfig.json`, `backend/wrangler.jsonc`, `backend/src/env.ts`
- Create: `backend/migrations/0001_init.sql`, `backend/src/lib/db.ts`, `backend/test/helpers/sqliteDb.ts`
- Test: `backend/test/db.test.ts`

**Interfaces:**
- Produces:
  - `type SqlParam = string | number | null`
  - `interface Db { run(sql, params?): Promise<{ changes: number }>; first<T>(sql, params?): Promise<T | null>; all<T>(sql, params?): Promise<T[]>; batch(statements: { sql: string; params?: SqlParam[] }[]): Promise<void> }`
  - `function d1Db(d1: D1Database): Db`
  - Teste: `function createTestDb(): Db` (SQLite em memória com as migrações aplicadas e `foreign_keys = ON`)

- [ ] **Step 1: Instalar dependências** (em `backend/`)

```bash
npm install jose cbor-x @peculiar/x509 reflect-metadata
```
```bash
npm install -D @types/node
```
Expected: sem erros; `package.json` ganha as 4 dependências e `@types/node`.

- [ ] **Step 2: Confirmar que o `node:sqlite` existe nesta versão do Node**

Run: `node -e "const {DatabaseSync}=require('node:sqlite'); new DatabaseSync(':memory:').exec('select 1'); console.log('sqlite ok')" 2>&1 | grep -v Experimental`
Expected: `sqlite ok`.

- [ ] **Step 3: Habilitar tipos do Node nos testes — em `backend/tsconfig.json`** trocar `"types": ["@cloudflare/workers-types"]` por:

```json
    "types": ["@cloudflare/workers-types", "node"],
```
Run: `npx tsc --noEmit`
Expected: sem erros. Se aparecerem conflitos entre os tipos do Workers e do Node (ex.: duplicação de `fetch`/`Response`), resolva mantendo `skipLibCheck: true` e, se necessário, movendo os helpers que importam `node:*` para usar `import type` apenas onde cabe; não remova `workers-types`.

- [ ] **Step 4: Criar `backend/migrations/0001_init.sql`**

```sql
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
```

- [ ] **Step 5: Escrever o teste que falha — `backend/test/db.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import { createTestDb } from './helpers/sqliteDb'

describe('test database', () => {
  it('applies the migrations', async () => {
    const db = createTestDb()
    const tables = await db.all<{ name: string }>(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    )
    expect(tables.map((t) => t.name)).toEqual(['challenges', 'devices', 'entitlements', 'refresh_tokens', 'usage', 'users'])
  })

  it('reports changes and supports first/all', async () => {
    const db = createTestDb()
    expect((await db.run('INSERT INTO challenges (id, expires_at) VALUES (?, ?)', ['a', 10])).changes).toBe(1)
    expect((await db.run('DELETE FROM challenges WHERE id = ?', ['nope'])).changes).toBe(0)
    expect(await db.first<{ id: string }>('SELECT id FROM challenges WHERE id = ?', ['a'])).toMatchObject({ id: 'a' })
    expect(await db.first('SELECT id FROM challenges WHERE id = ?', ['zzz'])).toBeNull()
    expect(await db.all('SELECT id FROM challenges')).toHaveLength(1)
  })

  it('batch is atomic', async () => {
    const db = createTestDb()
    await expect(
      db.batch([
        { sql: 'INSERT INTO challenges (id, expires_at) VALUES (?, ?)', params: ['x', 1] },
        { sql: 'INSERT INTO challenges (id, expires_at) VALUES (?, ?)', params: ['x', 2] }, // viola a PK
      ]),
    ).rejects.toThrow()
    expect(await db.all('SELECT id FROM challenges')).toHaveLength(0)
  })

  it('enforces foreign keys and cascades refresh tokens', async () => {
    const db = createTestDb()
    await expect(
      db.run('INSERT INTO refresh_tokens (token_hash, device_id, expires_at) VALUES (?, ?, ?)', ['h', 'missing', 1]),
    ).rejects.toThrow()
    await db.run('INSERT INTO devices (id, created_at) VALUES (?, ?)', ['d1', 1])
    await db.run('INSERT INTO refresh_tokens (token_hash, device_id, expires_at) VALUES (?, ?, ?)', ['h', 'd1', 1])
    await db.run('DELETE FROM devices WHERE id = ?', ['d1'])
    expect(await db.all('SELECT * FROM refresh_tokens')).toHaveLength(0)
  })

  it('upsert with a WHERE clause reports 0 changes when the limit is reached', async () => {
    const db = createTestDb()
    const sql = `INSERT INTO usage (owner_kind, owner_id, day, count) VALUES ('device', 'd', '2026-10-05', 1)
      ON CONFLICT (owner_kind, owner_id, day) DO UPDATE SET count = count + 1 WHERE count < ?`
    expect((await db.run(sql, [2])).changes).toBe(1) // insere
    expect((await db.run(sql, [2])).changes).toBe(1) // incrementa para 2
    expect((await db.run(sql, [2])).changes).toBe(0) // bloqueado
  })
})
```

- [ ] **Step 6: Rodar e ver falhar**

Run: `npx vitest run test/db.test.ts 2>&1 | grep -E "Error|FAIL" | head -3`
Expected: FAIL — `Cannot find module './helpers/sqliteDb'`.

- [ ] **Step 7: Criar `backend/src/lib/db.ts`**

```ts
export type SqlParam = string | number | null

export interface Db {
  run(sql: string, params?: SqlParam[]): Promise<{ changes: number }>
  first<T>(sql: string, params?: SqlParam[]): Promise<T | null>
  all<T>(sql: string, params?: SqlParam[]): Promise<T[]>
  /** Executa todas as instruções de forma atômica. */
  batch(statements: { sql: string; params?: SqlParam[] }[]): Promise<void>
}

export function d1Db(d1: D1Database): Db {
  const statement = (sql: string, params: SqlParam[] = []) => d1.prepare(sql).bind(...params)
  return {
    async run(sql, params) {
      const result = await statement(sql, params).run()
      return { changes: result.meta.changes ?? 0 }
    },
    async first<T>(sql: string, params?: SqlParam[]) {
      return (await statement(sql, params).first<T>()) ?? null
    },
    async all<T>(sql: string, params?: SqlParam[]) {
      return (await statement(sql, params).all<T>()).results
    },
    async batch(statements) {
      await d1.batch(statements.map((s) => statement(s.sql, s.params)))
    },
  }
}
```

- [ ] **Step 8: Criar `backend/test/helpers/sqliteDb.ts`**

```ts
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { DatabaseSync } from 'node:sqlite'
import type { Db, SqlParam } from '../../src/lib/db'

const MIGRATIONS_DIR = join(import.meta.dirname, '../../migrations')

/** SQLite em memória com as migrações reais aplicadas (mesmo SQL do D1). */
export function createTestDb(): Db {
  const sqlite = new DatabaseSync(':memory:')
  sqlite.exec('PRAGMA foreign_keys = ON')
  for (const file of readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql')).sort()) {
    sqlite.exec(readFileSync(join(MIGRATIONS_DIR, file), 'utf8'))
  }

  const run = (sql: string, params: SqlParam[] = []) => sqlite.prepare(sql).run(...params)

  return {
    async run(sql, params) {
      return { changes: Number(run(sql, params).changes) }
    },
    async first<T>(sql: string, params: SqlParam[] = []) {
      return ((sqlite.prepare(sql).get(...params) as T | undefined) ?? null) as T | null
    },
    async all<T>(sql: string, params: SqlParam[] = []) {
      return sqlite.prepare(sql).all(...params) as T[]
    },
    async batch(statements) {
      sqlite.exec('BEGIN')
      try {
        for (const s of statements) run(s.sql, s.params)
        sqlite.exec('COMMIT')
      } catch (error) {
        sqlite.exec('ROLLBACK')
        throw error
      }
    },
  }
}
```

- [ ] **Step 9: Atualizar `backend/src/env.ts`**

```ts
export interface Env {
  CACHE: KVNamespace
  CONFIG: KVNamespace
  DB: D1Database
  AI_EVENTS?: AnalyticsEngineDataset
  ANTHROPIC_API_KEY: string
  OPENAI_API_KEY?: string
  GEMINI_API_KEY?: string
  TMDB_TOKEN: string
  CF_ACCOUNT_ID: string
  CF_AIG_TOKEN?: string
  AI_GATEWAY_ID: string
  JWT_SECRET: string
  APPLE_TEAM_ID: string
  APPLE_KEY_ID: string
  APPLE_BUNDLE_ID: string
  APPLE_PRIVATE_KEY: string
  ALLOW_UNATTESTED: string
  ALLOW_PROVIDER_OVERRIDE: string
  APPATTEST_ENVS: string
}
```
(`DEV_API_KEY` sai: a autenticação por `x-dev-key` é removida na Task BE-6.)

- [ ] **Step 10: Declarar o D1 e as variáveis em `backend/wrangler.jsonc`**

No bloco **raiz** (produção), acrescentar `d1_databases` e substituir `vars`:
```jsonc
  "d1_databases": [
    { "binding": "DB", "database_name": "filmfinder", "database_id": "local", "migrations_dir": "migrations" }
  ],
  "vars": {
    "AI_GATEWAY_ID": "filmfinder",
    "APPLE_BUNDLE_ID": "com.andre.filmfinder",
    "APPLE_TEAM_ID": "",
    "APPLE_KEY_ID": "",
    "ALLOW_UNATTESTED": "false",
    "ALLOW_PROVIDER_OVERRIDE": "false",
    "APPATTEST_ENVS": "production"
  },
```
No bloco `env.dev`, acrescentar `d1_databases` e substituir `vars`:
```jsonc
      "d1_databases": [
        { "binding": "DB", "database_name": "filmfinder-dev", "database_id": "local", "migrations_dir": "migrations" }
      ],
      "vars": {
        "AI_GATEWAY_ID": "default",
        "APPLE_BUNDLE_ID": "com.andre.filmfinder",
        "APPLE_TEAM_ID": "",
        "APPLE_KEY_ID": "",
        "ALLOW_UNATTESTED": "true",
        "ALLOW_PROVIDER_OVERRIDE": "true",
        "APPATTEST_ENVS": "development,production"
      }
```
(`database_id` e os IDs da Apple são preenchidos na Task BE-9.)

- [ ] **Step 11: Rodar tudo**

Run: `npx vitest run 2>&1 | tail -4; npx tsc --noEmit 2>&1 | head -5`
Expected: testes PASS; `tsc` pode reclamar de `DEV_API_KEY` removido de `Env` em `src/app.ts`/testes — é esperado e é corrigido na Task BE-6. Se só aparecerem erros por `DEV_API_KEY`, siga em frente; qualquer outro erro, corrija agora.

- [ ] **Step 12: Commit**

```bash
git add backend
git commit -m "feat(backend): add D1 schema, db adapters and test sqlite helper"
```

---

### Task BE-2: Limites em config, uso, entitlements e cota

**Files:**
- Modify: `backend/src/config.ts`, `backend/test/config.test.ts`
- Create: `backend/src/auth/identity.ts`, `backend/src/db/usage.ts`, `backend/src/db/entitlements.ts`, `backend/src/quota.ts`
- Test: `backend/test/quota.test.ts`

**Interfaces:**
- Consumes: `Db` (BE-1), `AppConfig` (existente)
- Produces:
  - `type Identity = { deviceId: string; userId: string | null }`
  - `AppConfig.limits: { free: number; pro: number }`
  - `type OwnerKind = 'user' | 'device'`; `reserveUsage(db, kind, id, day, limit): Promise<boolean>`; `refundUsage(db, kind, id, day): Promise<void>`; `getUsage(db, kind, id, day): Promise<number>`; `raiseUsageTo(db, kind, id, day, count): Promise<void>`
  - `UNLIMITED_SEARCH = 'unlimited_search'`; `grantEntitlement(db, { id, ownerKind, ownerId, kind, expiresAt, originalTransactionId? })`; `hasActiveEntitlement(db, owners, kind, nowSec)`; `listActiveEntitlements(db, owners, nowSec): Promise<string[]>`; `moveDeviceEntitlementsToUser(db, deviceId, userId)`
  - `type Quota = { used: number; limit: number; resetsAt: string }`; `class QuotaExceededError extends Error { quota: Quota }`; `dayKey(nowMs)`, `resetsAt(nowMs)`; `reserveSearch(db, config, identity, nowMs): Promise<Quota>`; `refundSearch(db, identity, nowMs): Promise<void>`; `quotaSnapshot(db, config, identity, nowMs): Promise<Quota>`; `ownersOf(identity)`

- [ ] **Step 1: Atualizar os testes de config — `backend/test/config.test.ts`**

Substituir o teste `reads overrides from KV` por:
```ts
  it('reads overrides from KV', async () => {
    const kv = new MemoryKV({
      'ai.primary': 'gemini',
      'ai.secondary': 'openai',
      'ai.models.anthropic': 'claude-x',
      'ai.models.openai': 'gpt-y',
      'ai.models.gemini': 'gem-z',
      'limits.free.daily': '3',
      'limits.pro.daily': '50',
    })
    expect(await loadConfig(kv)).toEqual({
      primary: 'gemini',
      secondary: 'openai',
      models: { anthropic: 'claude-x', openai: 'gpt-y', gemini: 'gem-z' },
      limits: { free: 3, pro: 50 },
    })
  })

  it('uses default limits for missing or invalid values', async () => {
    expect((await loadConfig(new MemoryKV())).limits).toEqual({ free: 5, pro: 100 })
    const bad = new MemoryKV({ 'limits.free.daily': 'abc', 'limits.pro.daily': '0' })
    expect((await loadConfig(bad)).limits).toEqual({ free: 5, pro: 100 })
  })
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run test/config.test.ts 2>&1 | grep -E "FAIL|Tests " | head -4`
Expected: FAIL (`limits` não existe).

- [ ] **Step 3: Atualizar `backend/src/config.ts`** — acrescentar `limits` ao tipo, ao padrão e ao carregamento:

```ts
export type AppConfig = {
  primary: ProviderName
  secondary: ProviderName
  models: Record<ProviderName, string>
  limits: { free: number; pro: number }
}

export const DEFAULT_CONFIG: AppConfig = {
  primary: 'gemini',
  secondary: 'anthropic',
  models: { anthropic: 'claude-haiku-4-5', openai: 'gpt-5-mini', gemini: 'gemini-3.5-flash-lite' },
  limits: { free: 5, pro: 100 },
}

const isProvider = (v: string | null): v is ProviderName => v === 'anthropic' || v === 'openai' || v === 'gemini'

function positiveInt(value: string | null, fallback: number): number {
  const n = Number.parseInt(value ?? '', 10)
  return Number.isFinite(n) && n >= 1 ? n : fallback
}

export async function loadConfig(kv: KVLike): Promise<AppConfig> {
  const [primary, secondary, anthropic, openai, gemini, freeLimit, proLimit] = await Promise.all([
    kv.get('ai.primary'),
    kv.get('ai.secondary'),
    kv.get('ai.models.anthropic'),
    kv.get('ai.models.openai'),
    kv.get('ai.models.gemini'),
    kv.get('limits.free.daily'),
    kv.get('limits.pro.daily'),
  ])
  const p = isProvider(primary) ? primary : DEFAULT_CONFIG.primary
  const fallbackDefault: ProviderName = p === 'gemini' ? 'anthropic' : DEFAULT_CONFIG.primary
  const s = isProvider(secondary) && secondary !== p ? secondary : fallbackDefault
  return {
    primary: p,
    secondary: s,
    models: {
      anthropic: anthropic ?? DEFAULT_CONFIG.models.anthropic,
      openai: openai ?? DEFAULT_CONFIG.models.openai,
      gemini: gemini ?? DEFAULT_CONFIG.models.gemini,
    },
    limits: {
      free: positiveInt(freeLimit, DEFAULT_CONFIG.limits.free),
      pro: positiveInt(proLimit, DEFAULT_CONFIG.limits.pro),
    },
  }
}
```
(Mantenha o `import type { KVLike }` e o `ProviderName` existentes no topo do arquivo.)

- [ ] **Step 4: Escrever os testes de cota — `backend/test/quota.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import { DEFAULT_CONFIG, type AppConfig } from '../src/config'
import { grantEntitlement, UNLIMITED_SEARCH } from '../src/db/entitlements'
import { getUsage } from '../src/db/usage'
import { dayKey, QuotaExceededError, quotaSnapshot, refundSearch, reserveSearch, resetsAt } from '../src/quota'
import { createTestDb } from './helpers/sqliteDb'

const NOW = Date.UTC(2026, 9, 5, 12, 0, 0)
const small: AppConfig = { ...DEFAULT_CONFIG, limits: { free: 2, pro: 4 } }

async function seed() {
  const db = createTestDb()
  await db.run('INSERT INTO users (id, apple_sub, created_at) VALUES (?, ?, ?)', ['u1', 'sub', 1])
  await db.run('INSERT INTO devices (id, user_id, created_at) VALUES (?, ?, ?)', ['d1', null, 1])
  await db.run('INSERT INTO devices (id, user_id, created_at) VALUES (?, ?, ?)', ['d2', 'u1', 1])
  return db
}

describe('dayKey / resetsAt', () => {
  it('uses UTC days and the next UTC midnight without milliseconds', () => {
    expect(dayKey(NOW)).toBe('2026-10-05')
    expect(resetsAt(NOW)).toBe('2026-10-06T00:00:00Z')
    expect(resetsAt(Date.UTC(2026, 11, 31, 23, 59, 59))).toBe('2027-01-01T00:00:00Z')
  })
})

describe('reserveSearch', () => {
  it('counts per device and blocks past the free limit', async () => {
    const db = await seed()
    const id = { deviceId: 'd1', userId: null }
    expect((await reserveSearch(db, small, id, NOW)).used).toBe(1)
    expect((await reserveSearch(db, small, id, NOW)).used).toBe(2)
    await expect(reserveSearch(db, small, id, NOW)).rejects.toBeInstanceOf(QuotaExceededError)
    expect(await getUsage(db, 'device', 'd1', '2026-10-05')).toBe(2)
  })

  it('resets on the next UTC day', async () => {
    const db = await seed()
    const id = { deviceId: 'd1', userId: null }
    await reserveSearch(db, small, id, NOW)
    await reserveSearch(db, small, id, NOW)
    const tomorrow = Date.UTC(2026, 9, 6, 0, 0, 1)
    expect((await reserveSearch(db, small, id, tomorrow)).used).toBe(1)
  })

  it('counts on the user too and blocks when either reaches the limit', async () => {
    const db = await seed()
    const asUser = { deviceId: 'd2', userId: 'u1' }
    await reserveSearch(db, small, asUser, NOW)
    await reserveSearch(db, small, asUser, NOW)
    expect(await getUsage(db, 'user', 'u1', '2026-10-05')).toBe(2)
    // outro dispositivo do mesmo usuário já esbarra no limite do usuário
    await db.run('INSERT INTO devices (id, user_id, created_at) VALUES (?, ?, ?)', ['d3', 'u1', 1])
    await expect(reserveSearch(db, small, { deviceId: 'd3', userId: 'u1' }, NOW)).rejects.toBeInstanceOf(QuotaExceededError)
    // e a reserva parcial no d3 foi desfeita
    expect(await getUsage(db, 'device', 'd3', '2026-10-05')).toBe(0)
  })

  it('uses the pro limit when the user has an active unlimited_search entitlement', async () => {
    const db = await seed()
    await grantEntitlement(db, { id: 'e1', ownerKind: 'user', ownerId: 'u1', kind: UNLIMITED_SEARCH, expiresAt: NOW / 1000 + 3600 })
    const id = { deviceId: 'd2', userId: 'u1' }
    for (let i = 1; i <= 4; i++) expect((await reserveSearch(db, small, id, NOW)).limit).toBe(4)
    await expect(reserveSearch(db, small, id, NOW)).rejects.toBeInstanceOf(QuotaExceededError)
  })

  it('ignores expired entitlements', async () => {
    const db = await seed()
    await grantEntitlement(db, { id: 'e1', ownerKind: 'device', ownerId: 'd1', kind: UNLIMITED_SEARCH, expiresAt: NOW / 1000 - 1 })
    expect((await reserveSearch(db, small, { deviceId: 'd1', userId: null }, NOW)).limit).toBe(2)
  })
})

describe('refundSearch / quotaSnapshot', () => {
  it('refund gives the search back on every owner and never goes negative', async () => {
    const db = await seed()
    const id = { deviceId: 'd2', userId: 'u1' }
    await reserveSearch(db, small, id, NOW)
    await refundSearch(db, id, NOW)
    await refundSearch(db, id, NOW)
    expect(await getUsage(db, 'device', 'd2', '2026-10-05')).toBe(0)
    expect(await getUsage(db, 'user', 'u1', '2026-10-05')).toBe(0)
  })

  it('snapshot reports the highest usage among the owners', async () => {
    const db = await seed()
    await reserveSearch(db, small, { deviceId: 'd1', userId: null }, NOW)
    await db.run("INSERT INTO usage (owner_kind, owner_id, day, count) VALUES ('user', 'u1', '2026-10-05', 2)")
    const snap = await quotaSnapshot(db, small, { deviceId: 'd1', userId: 'u1' }, NOW)
    expect(snap).toEqual({ used: 2, limit: 2, resetsAt: '2026-10-06T00:00:00Z' })
  })
})
```

- [ ] **Step 5: Rodar e ver falhar**

Run: `npx vitest run test/quota.test.ts 2>&1 | grep -E "Error" | head -3`
Expected: FAIL — módulos `../src/db/entitlements` etc. não encontrados.

- [ ] **Step 6: Criar `backend/src/auth/identity.ts`**

```ts
export type Identity = { deviceId: string; userId: string | null }
```

- [ ] **Step 7: Criar `backend/src/db/usage.ts`**

```ts
import type { Db } from '../lib/db'

export type OwnerKind = 'user' | 'device'

/** Reserva uma busca. `false` se o contador do dia já está no limite. */
export async function reserveUsage(db: Db, kind: OwnerKind, id: string, day: string, limit: number): Promise<boolean> {
  const { changes } = await db.run(
    `INSERT INTO usage (owner_kind, owner_id, day, count) VALUES (?, ?, ?, 1)
     ON CONFLICT (owner_kind, owner_id, day) DO UPDATE SET count = count + 1 WHERE count < ?`,
    [kind, id, day, limit],
  )
  return changes === 1
}

export async function refundUsage(db: Db, kind: OwnerKind, id: string, day: string): Promise<void> {
  await db.run('UPDATE usage SET count = MAX(count - 1, 0) WHERE owner_kind = ? AND owner_id = ? AND day = ?', [kind, id, day])
}

export async function getUsage(db: Db, kind: OwnerKind, id: string, day: string): Promise<number> {
  const row = await db.first<{ count: number }>('SELECT count FROM usage WHERE owner_kind = ? AND owner_id = ? AND day = ?', [kind, id, day])
  return row?.count ?? 0
}

/** Garante que o contador do dia seja pelo menos `count` (usado ao mesclar dispositivo e usuário). */
export async function raiseUsageTo(db: Db, kind: OwnerKind, id: string, day: string, count: number): Promise<void> {
  await db.run(
    `INSERT INTO usage (owner_kind, owner_id, day, count) VALUES (?, ?, ?, ?)
     ON CONFLICT (owner_kind, owner_id, day) DO UPDATE SET count = MAX(count, excluded.count)`,
    [kind, id, day, count],
  )
}
```

- [ ] **Step 8: Criar `backend/src/db/entitlements.ts`**

```ts
import type { Db } from '../lib/db'
import type { OwnerKind } from './usage'

export const UNLIMITED_SEARCH = 'unlimited_search'

export type Owner = { kind: OwnerKind; id: string }

export async function grantEntitlement(
  db: Db,
  e: { id: string; ownerKind: OwnerKind; ownerId: string; kind: string; expiresAt: number; originalTransactionId?: string },
): Promise<void> {
  await db.run(
    'INSERT INTO entitlements (id, owner_kind, owner_id, kind, expires_at, original_transaction_id) VALUES (?, ?, ?, ?, ?, ?)',
    [e.id, e.ownerKind, e.ownerId, e.kind, e.expiresAt, e.originalTransactionId ?? null],
  )
}

export async function listActiveEntitlements(db: Db, owners: Owner[], nowSec: number): Promise<string[]> {
  const kinds = new Set<string>()
  for (const owner of owners) {
    const rows = await db.all<{ kind: string }>(
      'SELECT DISTINCT kind FROM entitlements WHERE owner_kind = ? AND owner_id = ? AND expires_at > ?',
      [owner.kind, owner.id, nowSec],
    )
    rows.forEach((r) => kinds.add(r.kind))
  }
  return [...kinds].sort()
}

export async function hasActiveEntitlement(db: Db, owners: Owner[], kind: string, nowSec: number): Promise<boolean> {
  return (await listActiveEntitlements(db, owners, nowSec)).includes(kind)
}

export async function moveDeviceEntitlementsToUser(db: Db, deviceId: string, userId: string): Promise<void> {
  await db.run("UPDATE entitlements SET owner_kind = 'user', owner_id = ? WHERE owner_kind = 'device' AND owner_id = ?", [userId, deviceId])
}
```

- [ ] **Step 9: Criar `backend/src/quota.ts`**

```ts
import type { Identity } from './auth/identity'
import type { AppConfig } from './config'
import { hasActiveEntitlement, UNLIMITED_SEARCH, type Owner } from './db/entitlements'
import { getUsage, refundUsage, reserveUsage } from './db/usage'
import type { Db } from './lib/db'

export type Quota = { used: number; limit: number; resetsAt: string }

export class QuotaExceededError extends Error {
  override name = 'QuotaExceededError'
  constructor(readonly quota: Quota) {
    super('Daily search limit reached')
  }
}

export function dayKey(nowMs: number): string {
  return new Date(nowMs).toISOString().slice(0, 10)
}

export function resetsAt(nowMs: number): string {
  const d = new Date(nowMs)
  const next = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1)
  return new Date(next).toISOString().replace(/\.\d{3}Z$/, 'Z')
}

export function ownersOf(identity: Identity): Owner[] {
  const owners: Owner[] = [{ kind: 'device', id: identity.deviceId }]
  if (identity.userId) owners.push({ kind: 'user', id: identity.userId })
  return owners
}

async function limitFor(db: Db, config: AppConfig, identity: Identity, nowMs: number): Promise<number> {
  const pro = await hasActiveEntitlement(db, ownersOf(identity), UNLIMITED_SEARCH, Math.floor(nowMs / 1000))
  return pro ? config.limits.pro : config.limits.free
}

export async function quotaSnapshot(db: Db, config: AppConfig, identity: Identity, nowMs: number): Promise<Quota> {
  const day = dayKey(nowMs)
  const counts = await Promise.all(ownersOf(identity).map((o) => getUsage(db, o.kind, o.id, day)))
  return {
    used: Math.max(...counts),
    limit: await limitFor(db, config, identity, nowMs),
    resetsAt: resetsAt(nowMs),
  }
}

/** Reserva uma busca em todos os donos (dispositivo e, se logado, usuário). */
export async function reserveSearch(db: Db, config: AppConfig, identity: Identity, nowMs: number): Promise<Quota> {
  const limit = await limitFor(db, config, identity, nowMs)
  const day = dayKey(nowMs)
  const reserved: Owner[] = []
  for (const owner of ownersOf(identity)) {
    if (!(await reserveUsage(db, owner.kind, owner.id, day, limit))) {
      for (const done of reserved) await refundUsage(db, done.kind, done.id, day)
      throw new QuotaExceededError(await quotaSnapshot(db, config, identity, nowMs))
    }
    reserved.push(owner)
  }
  return quotaSnapshot(db, config, identity, nowMs)
}

export async function refundSearch(db: Db, identity: Identity, nowMs: number): Promise<void> {
  const day = dayKey(nowMs)
  for (const owner of ownersOf(identity)) await refundUsage(db, owner.kind, owner.id, day)
}
```

- [ ] **Step 10: Rodar e ver passar**

Run: `npx vitest run test/config.test.ts test/quota.test.ts 2>&1 | tail -4`
Expected: todos PASS.

- [ ] **Step 11: Commit**

```bash
git add backend
git commit -m "feat(backend): add daily search quota backed by D1 usage and entitlements"
```

---

### Task BE-3: Utilitários de cripto, tokens de sessão e desafios

**Files:**
- Create: `backend/src/lib/crypto.ts`, `backend/src/db/devices.ts`, `backend/src/db/users.ts`, `backend/src/auth/tokens.ts`, `backend/src/auth/challenge.ts`
- Modify: `backend/src/lib/errors.ts`
- Test: `backend/test/crypto.test.ts`, `backend/test/tokens.test.ts`, `backend/test/challenge.test.ts`

**Interfaces:**
- Consumes: `Db` (BE-1), `Identity` (BE-2)
- Produces:
  - `utf8(text)`, `sha256(data): Promise<Uint8Array>`, `sha256Hex(text)`, `toHex(bytes)`, `toBase64(bytes)`, `fromBase64(text)`, `toBase64Url(bytes)`, `randomBase64Url(byteLength = 32)`, `concat(...parts)`, `equalBytes(a, b)`
  - `ApiError(code, message, status)` ampliado; `ErrorCode` com todos os códigos da seção Global Constraints
  - `DeviceRow`, `createDevice(db, { id, keyId, publicKey, nowSec })`, `getDevice(db, id)`, `updateCounter(db, id, counter)`, `linkDeviceToUser(db, deviceId, userId | null)`
  - `UserRow`, `upsertUserByAppleSub(db, { sub, appleRefreshToken, nowSec, newId }): Promise<UserRow>`, `getUser(db, id)`
  - `class TokenService { constructor(secret: string, db: Db, nowMs: () => number); issueAccess(deviceId): Promise<{ accessToken: string; expiresAt: number }>; verifyAccess(token): Promise<{ deviceId: string }>; issueRefresh(deviceId): Promise<string>; deviceForRefresh(token): Promise<string | null>; consumeRefresh(token): Promise<boolean> }`
  - `createChallenge(db, nowMs): Promise<string>`; `consumeChallenge(db, challenge, nowMs): Promise<boolean>`

- [ ] **Step 1: Escrever os testes de cripto — `backend/test/crypto.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import { concat, equalBytes, fromBase64, randomBase64Url, sha256, sha256Hex, toBase64, toBase64Url, toHex, utf8 } from '../src/lib/crypto'

describe('crypto helpers', () => {
  it('sha256 matches the known vector for "abc"', async () => {
    expect(await sha256Hex('abc')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
    expect(toHex(await sha256(utf8('abc')))).toBe(await sha256Hex('abc'))
  })

  it('base64 round-trips and url variant has no padding or +/', () => {
    const bytes = new Uint8Array([251, 255, 254, 0, 1])
    expect(fromBase64(toBase64(bytes))).toEqual(bytes)
    expect(toBase64Url(bytes)).not.toMatch(/[+/=]/)
  })

  it('randomBase64Url is unique and has the requested entropy', () => {
    const a = randomBase64Url(32)
    expect(a).not.toBe(randomBase64Url(32))
    expect(fromBase64(a.replace(/-/g, '+').replace(/_/g, '/')).length).toBe(32)
  })

  it('concat and equalBytes', () => {
    expect(concat(new Uint8Array([1]), new Uint8Array([2, 3]))).toEqual(new Uint8Array([1, 2, 3]))
    expect(equalBytes(new Uint8Array([1, 2]), new Uint8Array([1, 2]))).toBe(true)
    expect(equalBytes(new Uint8Array([1, 2]), new Uint8Array([1, 3]))).toBe(false)
    expect(equalBytes(new Uint8Array([1]), new Uint8Array([1, 2]))).toBe(false)
  })
})
```

- [ ] **Step 2: Criar `backend/src/lib/crypto.ts`**

```ts
const encoder = new TextEncoder()

export function utf8(text: string): Uint8Array {
  return encoder.encode(text)
}

export async function sha256(data: Uint8Array | string): Promise<Uint8Array> {
  const bytes = typeof data === 'string' ? utf8(data) : data
  return new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))
}

export function toHex(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('')
}

export async function sha256Hex(text: string): Promise<string> {
  return toHex(await sha256(text))
}

export function toBase64(bytes: Uint8Array): string {
  let binary = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary)
}

export function fromBase64(text: string): Uint8Array {
  const binary = atob(text)
  const out = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i)
  return out
}

export function toBase64Url(bytes: Uint8Array): string {
  return toBase64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

export function randomBase64Url(byteLength = 32): string {
  return toBase64Url(crypto.getRandomValues(new Uint8Array(byteLength)))
}

export function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0))
  let offset = 0
  for (const part of parts) {
    out.set(part, offset)
    offset += part.length
  }
  return out
}

export function equalBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0)
  return diff === 0
}
```

- [ ] **Step 3: Ampliar `backend/src/lib/errors.ts`** — substituir `ErrorCode`, `ApiError` e manter `errorBody`:

```ts
export type ErrorCode =
  | 'unauthorized'
  | 'invalid_input'
  | 'invalid_challenge'
  | 'forbidden'
  | 'attestation_failed'
  | 'quota_exceeded'
  | 'apple_auth_failed'
  | 'apple_unavailable'
  | 'ai_unavailable'
  | 'internal'

export type ErrorStatus = 400 | 401 | 402 | 403 | 500 | 502 | 503

export class ApiError extends Error {
  override name = 'ApiError'
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly status: ErrorStatus,
  ) {
    super(message)
  }
}
```
(`ProviderError`, `AiUnavailableError` e `errorBody` permanecem como estão.)

- [ ] **Step 4: Criar `backend/src/db/devices.ts`**

```ts
import type { Db } from '../lib/db'

export type DeviceRow = {
  id: string
  key_id: string | null
  public_key: string | null
  counter: number
  user_id: string | null
  created_at: number
}

export async function createDevice(
  db: Db,
  d: { id: string; keyId: string | null; publicKey: string | null; nowSec: number },
): Promise<void> {
  await db.run('INSERT INTO devices (id, key_id, public_key, counter, user_id, created_at) VALUES (?, ?, ?, 0, NULL, ?)', [
    d.id,
    d.keyId,
    d.publicKey,
    d.nowSec,
  ])
}

export function getDevice(db: Db, id: string): Promise<DeviceRow | null> {
  return db.first<DeviceRow>('SELECT * FROM devices WHERE id = ?', [id])
}

export async function updateCounter(db: Db, id: string, counter: number): Promise<void> {
  await db.run('UPDATE devices SET counter = ? WHERE id = ?', [counter, id])
}

export async function linkDeviceToUser(db: Db, deviceId: string, userId: string | null): Promise<void> {
  await db.run('UPDATE devices SET user_id = ? WHERE id = ?', [userId, deviceId])
}
```

- [ ] **Step 5: Criar `backend/src/db/users.ts`**

```ts
import type { Db } from '../lib/db'

export type UserRow = {
  id: string
  apple_sub: string
  apple_refresh_token: string | null
  created_at: number
}

export function getUser(db: Db, id: string): Promise<UserRow | null> {
  return db.first<UserRow>('SELECT * FROM users WHERE id = ?', [id])
}

/** Encontra o usuário pelo `sub` do Apple (atualizando o token de revogação) ou cria um novo. */
export async function upsertUserByAppleSub(
  db: Db,
  p: { sub: string; appleRefreshToken: string; nowSec: number; newId: string },
): Promise<UserRow> {
  const existing = await db.first<UserRow>('SELECT * FROM users WHERE apple_sub = ?', [p.sub])
  if (existing) {
    await db.run('UPDATE users SET apple_refresh_token = ? WHERE id = ?', [p.appleRefreshToken, existing.id])
    return { ...existing, apple_refresh_token: p.appleRefreshToken }
  }
  await db.run('INSERT INTO users (id, apple_sub, apple_refresh_token, created_at) VALUES (?, ?, ?, ?)', [
    p.newId,
    p.sub,
    p.appleRefreshToken,
    p.nowSec,
  ])
  return { id: p.newId, apple_sub: p.sub, apple_refresh_token: p.appleRefreshToken, created_at: p.nowSec }
}
```

- [ ] **Step 6: Escrever os testes de tokens — `backend/test/tokens.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import { createDevice } from '../src/db/devices'
import { TokenService } from '../src/auth/tokens'
import { ApiError } from '../src/lib/errors'
import { createTestDb } from './helpers/sqliteDb'

const SECRET = 'a-test-secret-with-more-than-32-characters'
const T0 = Date.UTC(2026, 9, 5, 12, 0, 0)

async function setup() {
  const db = createTestDb()
  await createDevice(db, { id: 'd1', keyId: null, publicKey: null, nowSec: 1 })
  let now = T0
  const tokens = new TokenService(SECRET, db, () => now)
  return { db, tokens, advance: (ms: number) => (now += ms) }
}

describe('access tokens', () => {
  it('issue and verify round-trip with a 15 minute lifetime', async () => {
    const { tokens } = await setup()
    const { accessToken, expiresAt } = await tokens.issueAccess('d1')
    expect(expiresAt).toBe(Math.floor(T0 / 1000) + 15 * 60)
    expect(await tokens.verifyAccess(accessToken)).toEqual({ deviceId: 'd1' })
  })

  it('rejects expired tokens', async () => {
    const { tokens, advance } = await setup()
    const { accessToken } = await tokens.issueAccess('d1')
    advance(15 * 60 * 1000 + 1000)
    await expect(tokens.verifyAccess(accessToken)).rejects.toMatchObject({ code: 'unauthorized', status: 401 })
  })

  it('rejects tampered tokens and tokens signed with another secret', async () => {
    const { db, tokens } = await setup()
    const { accessToken } = await tokens.issueAccess('d1')
    await expect(tokens.verifyAccess(accessToken.slice(0, -2) + 'xx')).rejects.toBeInstanceOf(ApiError)
    const other = new TokenService('another-secret-with-more-than-32-chars!!', db, () => T0)
    await expect(other.verifyAccess(accessToken)).rejects.toBeInstanceOf(ApiError)
    await expect(tokens.verifyAccess('not-a-jwt')).rejects.toBeInstanceOf(ApiError)
  })
})

describe('refresh tokens', () => {
  it('are stored hashed, resolve to the device and are single use', async () => {
    const { db, tokens } = await setup()
    const refresh = await tokens.issueRefresh('d1')
    const stored = await db.all<{ token_hash: string }>('SELECT token_hash FROM refresh_tokens')
    expect(stored).toHaveLength(1)
    expect(stored[0]?.token_hash).not.toContain(refresh)

    expect(await tokens.deviceForRefresh(refresh)).toBe('d1')
    expect(await tokens.consumeRefresh(refresh)).toBe(true)
    expect(await tokens.consumeRefresh(refresh)).toBe(false)
    expect(await tokens.deviceForRefresh(refresh)).toBeNull()
  })

  it('expire after 60 days', async () => {
    const { tokens, advance } = await setup()
    const refresh = await tokens.issueRefresh('d1')
    advance(60 * 24 * 3600 * 1000 + 1000)
    expect(await tokens.deviceForRefresh(refresh)).toBeNull()
    expect(await tokens.consumeRefresh(refresh)).toBe(false)
  })

  it('unknown tokens resolve to nothing', async () => {
    const { tokens } = await setup()
    expect(await tokens.deviceForRefresh('nope')).toBeNull()
  })
})
```

- [ ] **Step 7: Escrever os testes de desafios — `backend/test/challenge.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import { consumeChallenge, createChallenge } from '../src/auth/challenge'
import { createTestDb } from './helpers/sqliteDb'

const T0 = Date.UTC(2026, 9, 5, 12, 0, 0)

describe('challenges', () => {
  it('are unique and consumable exactly once', async () => {
    const db = createTestDb()
    const a = await createChallenge(db, T0)
    expect(a).not.toBe(await createChallenge(db, T0))
    expect(await consumeChallenge(db, a, T0 + 1000)).toBe(true)
    expect(await consumeChallenge(db, a, T0 + 1000)).toBe(false)
  })

  it('expire after 5 minutes', async () => {
    const db = createTestDb()
    const c = await createChallenge(db, T0)
    expect(await consumeChallenge(db, c, T0 + 5 * 60 * 1000 + 1)).toBe(false)
  })

  it('unknown challenges are rejected and old ones are purged on creation', async () => {
    const db = createTestDb()
    expect(await consumeChallenge(db, 'nope', T0)).toBe(false)
    await createChallenge(db, T0)
    await createChallenge(db, T0 + 10 * 60 * 1000)
    expect(await db.all('SELECT id FROM challenges')).toHaveLength(1)
  })
})
```

- [ ] **Step 8: Rodar e ver falhar**

Run: `npx vitest run test/crypto.test.ts test/tokens.test.ts test/challenge.test.ts 2>&1 | grep -E "Error" | head -3`
Expected: FAIL — módulos não encontrados (os testes de cripto passam após o Step 2; tokens/challenge falham).

- [ ] **Step 9: Criar `backend/src/auth/tokens.ts`**

```ts
import { jwtVerify, SignJWT } from 'jose'
import type { Db } from '../lib/db'
import { randomBase64Url, sha256Hex, utf8 } from '../lib/crypto'
import { ApiError } from '../lib/errors'

const ISSUER = 'filmfinder-api'
const ACCESS_TTL_SEC = 15 * 60
const REFRESH_TTL_SEC = 60 * 24 * 3600

export class TokenService {
  private readonly key: Uint8Array

  constructor(
    secret: string,
    private readonly db: Db,
    private readonly nowMs: () => number,
  ) {
    this.key = utf8(secret)
  }

  async issueAccess(deviceId: string): Promise<{ accessToken: string; expiresAt: number }> {
    const iat = Math.floor(this.nowMs() / 1000)
    const expiresAt = iat + ACCESS_TTL_SEC
    const accessToken = await new SignJWT({})
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer(ISSUER)
      .setSubject(deviceId)
      .setIssuedAt(iat)
      .setExpirationTime(expiresAt)
      .sign(this.key)
    return { accessToken, expiresAt }
  }

  async verifyAccess(token: string): Promise<{ deviceId: string }> {
    try {
      const { payload } = await jwtVerify(token, this.key, {
        issuer: ISSUER,
        algorithms: ['HS256'],
        currentDate: new Date(this.nowMs()),
      })
      if (!payload.sub) throw new Error('missing subject')
      return { deviceId: payload.sub }
    } catch {
      throw new ApiError('unauthorized', 'Invalid or expired access token', 401)
    }
  }

  async issueRefresh(deviceId: string): Promise<string> {
    const token = randomBase64Url(32)
    const expiresAt = Math.floor(this.nowMs() / 1000) + REFRESH_TTL_SEC
    await this.db.run('INSERT INTO refresh_tokens (token_hash, device_id, expires_at) VALUES (?, ?, ?)', [
      await sha256Hex(token),
      deviceId,
      expiresAt,
    ])
    return token
  }

  /** Consulta sem consumir: a quem pertence um refresh token válido. */
  async deviceForRefresh(token: string): Promise<string | null> {
    const row = await this.db.first<{ device_id: string }>(
      'SELECT device_id FROM refresh_tokens WHERE token_hash = ? AND expires_at > ?',
      [await sha256Hex(token), Math.floor(this.nowMs() / 1000)],
    )
    return row?.device_id ?? null
  }

  /** Consome (uso único). `false` se já foi usado, expirou ou não existe. */
  async consumeRefresh(token: string): Promise<boolean> {
    const { changes } = await this.db.run('DELETE FROM refresh_tokens WHERE token_hash = ? AND expires_at > ?', [
      await sha256Hex(token),
      Math.floor(this.nowMs() / 1000),
    ])
    return changes === 1
  }
}
```

- [ ] **Step 10: Criar `backend/src/auth/challenge.ts`**

```ts
import type { Db } from '../lib/db'
import { randomBase64Url } from '../lib/crypto'

const CHALLENGE_TTL_SEC = 300

export async function createChallenge(db: Db, nowMs: number): Promise<string> {
  const nowSec = Math.floor(nowMs / 1000)
  await db.run('DELETE FROM challenges WHERE expires_at <= ?', [nowSec])
  const challenge = randomBase64Url(32)
  await db.run('INSERT INTO challenges (id, expires_at) VALUES (?, ?)', [challenge, nowSec + CHALLENGE_TTL_SEC])
  return challenge
}

/** Uso único e atômico: `true` só para a primeira chamada com um desafio válido. */
export async function consumeChallenge(db: Db, challenge: string, nowMs: number): Promise<boolean> {
  const { changes } = await db.run('DELETE FROM challenges WHERE id = ? AND expires_at > ?', [
    challenge,
    Math.floor(nowMs / 1000),
  ])
  return changes === 1
}
```

- [ ] **Step 11: Rodar e ver passar**

Run: `npx vitest run test/crypto.test.ts test/tokens.test.ts test/challenge.test.ts 2>&1 | tail -4`
Expected: todos PASS.

- [ ] **Step 12: Commit**

```bash
git add backend
git commit -m "feat(backend): add crypto helpers, session tokens, device/user repos and challenges"
```

---

### Task BE-4: Verificação de App Attest (atestação e asserção)

**Files:**
- Create: `backend/src/auth/appleRootCa.ts`, `backend/src/auth/appAttest.ts`
- Create: `backend/test/helpers/fakeApple.ts`
- Test: `backend/test/appAttest.test.ts`

**Interfaces:**
- Consumes: `sha256`, `concat`, `equalBytes`, `fromBase64`, `toBase64`, `utf8` (BE-3)
- Produces:
  - `APPLE_APP_ATTEST_ROOT_CA_PEM: string`
  - `type AttestEnv = 'development' | 'production'`; `class AttestationError extends Error { reason: string }`
  - `verifyAttestation(input: { attestation: string; keyId: string; challenge: string; appId: string; allowedEnvs: AttestEnv[]; rootCaPem: string; nowMs: number }): Promise<{ publicKeySpki: string }>` (base64 do SPKI)
  - `verifyAssertion(input: { assertion: string; clientData: string; publicKeySpki: string; storedCounter: number; appId: string }): Promise<{ counter: number }>`
  - `type AttestVerifier = { verifyAttestation: typeof verifyAttestation; verifyAssertion: typeof verifyAssertion }`
  - Teste: `createFakeApple(appId): Promise<{ rootPem; makeAttestation(challenge, opts?); makeAssertion(credKeys, clientData, counter, opts?) }>`

> **Importante:** estes testes provam que o verificador implementa os passos do formato documentado pela Apple, usando uma cadeia de certificados gerada nos testes. Só um iPhone real prova que o formato da Apple bate byte a byte (OID da extensão, estrutura do nonce, `aaguid`); essa validação está no checklist da Task BE-9.

- [ ] **Step 1: Criar `backend/src/auth/appleRootCa.ts`** (raiz pública da Apple, de https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem)

```ts
/** Apple App Attestation Root CA (ECDSA P-384, válida até 2045). Raiz pública da Apple. */
export const APPLE_APP_ATTEST_ROOT_CA_PEM = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDowMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`
```

- [ ] **Step 2: Criar o helper de testes `backend/test/helpers/fakeApple.ts`**

```ts
import 'reflect-metadata'
import * as x509 from '@peculiar/x509'
import { encode } from 'cbor-x'
import type { AttestEnv } from '../../src/auth/appAttest'
import { concat, sha256, toBase64, utf8 } from '../../src/lib/crypto'

const NONCE_OID = '1.2.840.113635.100.8.2'
const signingAlgorithm = { name: 'ECDSA', hash: 'SHA-256' } as const
const keyAlgorithm = { name: 'ECDSA', namedCurve: 'P-256' } as const
const NOT_BEFORE = new Date('2026-01-01T00:00:00Z')
const NOT_AFTER = new Date('2027-01-01T00:00:00Z')

export function aaguidFor(env: AttestEnv): Uint8Array {
  return env === 'development' ? utf8('appattestdevelop') : utf8('appattest\0\0\0\0\0\0\0')
}

async function generateKeys(): Promise<CryptoKeyPair> {
  return (await crypto.subtle.generateKey(keyAlgorithm, true, ['sign', 'verify'])) as CryptoKeyPair
}

function derInteger(bytes: Uint8Array): Uint8Array {
  let start = 0
  while (start < bytes.length - 1 && bytes[start] === 0) start++
  let value = bytes.subarray(start)
  if ((value[0] ?? 0) & 0x80) value = concat(new Uint8Array([0]), value)
  return concat(new Uint8Array([0x02, value.length]), value)
}

/** WebCrypto assina em formato bruto (r||s); a Apple devolve ECDSA em DER. */
export function rawToDer(raw: Uint8Array): Uint8Array {
  const body = concat(derInteger(raw.subarray(0, 32)), derInteger(raw.subarray(32)))
  return concat(new Uint8Array([0x30, body.length]), body)
}

async function authDataHeader(appId: string, counter: number): Promise<Uint8Array> {
  const header = new Uint8Array(37)
  header.set(await sha256(appId), 0)
  header[32] = 0x40
  new DataView(header.buffer).setUint32(33, counter, false)
  return header
}

export type AttestOptions = {
  env?: AttestEnv
  counter?: number
  appId?: string
  fmt?: string
  /** Substitui o nonce gravado no certificado (para testar rejeição). */
  nonce?: Uint8Array
}

export async function createFakeApple(appId: string) {
  const rootKeys = await generateKeys()
  const intermediateKeys = await generateKeys()

  const root = await x509.X509CertificateGenerator.createSelfSigned({
    serialNumber: '01',
    name: 'CN=Fake Apple Root',
    notBefore: NOT_BEFORE,
    notAfter: NOT_AFTER,
    signingAlgorithm,
    keys: rootKeys,
  })
  const intermediate = await x509.X509CertificateGenerator.create({
    serialNumber: '02',
    subject: 'CN=Fake Apple Intermediate',
    issuer: root.subject,
    notBefore: NOT_BEFORE,
    notAfter: NOT_AFTER,
    signingAlgorithm,
    publicKey: intermediateKeys.publicKey,
    signingKey: rootKeys.privateKey,
  })

  async function makeAttestation(challenge: string, options: AttestOptions = {}) {
    const credKeys = await generateKeys()
    const rawPublicKey = new Uint8Array((await crypto.subtle.exportKey('raw', credKeys.publicKey)) as ArrayBuffer)
    const keyIdBytes = await sha256(rawPublicKey)

    const header = await authDataHeader(options.appId ?? appId, options.counter ?? 0)
    const credentialIdLength = new Uint8Array(2)
    new DataView(credentialIdLength.buffer).setUint16(0, keyIdBytes.length, false)
    const authData = concat(header, aaguidFor(options.env ?? 'development'), credentialIdLength, keyIdBytes, new Uint8Array([0xa0]))

    const nonce = options.nonce ?? (await sha256(concat(authData, await sha256(challenge))))
    const nonceExtension = new x509.Extension(NONCE_OID, false, concat(new Uint8Array([0x30, 0x24, 0xa1, 0x22, 0x04, 0x20]), nonce))
    const credCert = await x509.X509CertificateGenerator.create({
      serialNumber: '03',
      subject: 'CN=Fake Credential',
      issuer: intermediate.subject,
      notBefore: NOT_BEFORE,
      notAfter: NOT_AFTER,
      signingAlgorithm,
      publicKey: credKeys.publicKey,
      signingKey: intermediateKeys.privateKey,
      extensions: [nonceExtension],
    })

    const attestation = encode({
      fmt: options.fmt ?? 'apple-appattest',
      attStmt: {
        x5c: [new Uint8Array(credCert.rawData), new Uint8Array(intermediate.rawData)],
        receipt: new Uint8Array(0),
      },
      authData,
    })
    return { keyId: toBase64(keyIdBytes), attestation: toBase64(new Uint8Array(attestation)), credKeys }
  }

  async function makeAssertion(credKeys: CryptoKeyPair, clientData: string, counter: number, options: { appId?: string } = {}) {
    const authenticatorData = await authDataHeader(options.appId ?? appId, counter)
    const nonce = await sha256(concat(authenticatorData, await sha256(clientData)))
    const raw = new Uint8Array(await crypto.subtle.sign(signingAlgorithm, credKeys.privateKey, nonce))
    return toBase64(new Uint8Array(encode({ signature: rawToDer(raw), authenticatorData })))
  }

  return { rootPem: root.toString('pem'), makeAttestation, makeAssertion }
}
```

- [ ] **Step 3: Escrever os testes que falham — `backend/test/appAttest.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import { verifyAssertion, verifyAttestation, type AttestEnv } from '../src/auth/appAttest'
import { APPLE_APP_ATTEST_ROOT_CA_PEM } from '../src/auth/appleRootCa'
import { fromBase64, toBase64 } from '../src/lib/crypto'
import { createFakeApple } from './helpers/fakeApple'

const APP_ID = 'ABCDE12345.com.andre.filmfinder'
const NOW = Date.UTC(2026, 5, 1)

async function setup(env: AttestEnv[] = ['development']) {
  const apple = await createFakeApple(APP_ID)
  const input = (att: { keyId: string; attestation: string }, overrides: Record<string, unknown> = {}) => ({
    attestation: att.attestation,
    keyId: att.keyId,
    challenge: 'challenge-1',
    appId: APP_ID,
    allowedEnvs: env,
    rootCaPem: apple.rootPem,
    nowMs: NOW,
    ...overrides,
  })
  return { apple, input }
}

describe('Apple root CA constant', () => {
  it('is a well-formed PEM', () => {
    expect(APPLE_APP_ATTEST_ROOT_CA_PEM.startsWith('-----BEGIN CERTIFICATE-----')).toBe(true)
    expect(APPLE_APP_ATTEST_ROOT_CA_PEM.endsWith('-----END CERTIFICATE-----')).toBe(true)
  })
})

describe('verifyAttestation', () => {
  it('accepts a valid attestation and returns the credential public key (SPKI, base64)', async () => {
    const { apple, input } = await setup()
    const att = await apple.makeAttestation('challenge-1')
    const result = await verifyAttestation(input(att))
    const spki = new Uint8Array((await crypto.subtle.exportKey('spki', att.credKeys.publicKey)) as ArrayBuffer)
    expect(result.publicKeySpki).toBe(toBase64(spki))
  })

  it('accepts production attestations when production is allowed', async () => {
    const { apple, input } = await setup(['development', 'production'])
    const att = await apple.makeAttestation('challenge-1', { env: 'production' })
    await expect(verifyAttestation(input(att))).resolves.toBeDefined()
  })

  const rejections: [string, (apple: Awaited<ReturnType<typeof createFakeApple>>) => Promise<{ att: { keyId: string; attestation: string }; overrides?: Record<string, unknown> }>, string][] = [
    ['a different challenge', async (a) => ({ att: await a.makeAttestation('challenge-1'), overrides: { challenge: 'challenge-2' } }), 'nonce does not match challenge'],
    ['a different app id', async (a) => ({ att: await a.makeAttestation('challenge-1', { appId: 'OTHER.com.example' }) }), 'rpIdHash does not match appId'],
    ['a production attestation when only development is allowed', async (a) => ({ att: await a.makeAttestation('challenge-1', { env: 'production' }) }), 'aaguid does not match an allowed environment'],
    ['a non-zero counter', async (a) => ({ att: await a.makeAttestation('challenge-1', { counter: 1 }) }), 'counter must be 0'],
    ['a forged nonce in the certificate', async (a) => ({ att: await a.makeAttestation('challenge-1', { nonce: new Uint8Array(32) }) }), 'nonce does not match challenge'],
    ['a different key id', async (a) => ({ att: { ...(await a.makeAttestation('challenge-1')), keyId: toBase64(new Uint8Array(32)) } }), 'keyId does not match credCert public key'],
    ['an unexpected format', async (a) => ({ att: await a.makeAttestation('challenge-1', { fmt: 'packed' }) }), 'unexpected attestation format'],
    ['malformed data', async () => ({ att: { keyId: 'AAAA', attestation: 'AAAA' } }), 'attestation is not valid CBOR'],
    ['an expired certificate chain', async (a) => ({ att: await a.makeAttestation('challenge-1'), overrides: { nowMs: Date.UTC(2030, 0, 1) } }), 'certificate chain is not trusted'],
  ]
  it.each(rejections)('rejects %s', async (_name, build, reason) => {
    const { apple, input } = await setup()
    const { att, overrides } = await build(apple)
    await expect(verifyAttestation(input(att, overrides))).rejects.toMatchObject({ name: 'AttestationError', reason })
  })

  it('rejects a chain that does not lead to the trusted root', async () => {
    const { apple, input } = await setup()
    const other = await createFakeApple(APP_ID)
    const att = await apple.makeAttestation('challenge-1')
    await expect(verifyAttestation(input(att, { rootCaPem: other.rootPem }))).rejects.toMatchObject({
      reason: 'certificate chain is not trusted',
    })
  })
})

describe('verifyAssertion', () => {
  async function registered() {
    const { apple, input } = await setup()
    const att = await apple.makeAttestation('challenge-1')
    const { publicKeySpki } = await verifyAttestation(input(att))
    return { apple, att, publicKeySpki }
  }
  const base = (publicKeySpki: string, assertion: string, over: Record<string, unknown> = {}) => ({
    assertion,
    clientData: 'challenge-2:refresh-token',
    publicKeySpki,
    storedCounter: 0,
    appId: APP_ID,
    ...over,
  })

  it('accepts a valid assertion and returns the new counter', async () => {
    const { apple, att, publicKeySpki } = await registered()
    const assertion = await apple.makeAssertion(att.credKeys, 'challenge-2:refresh-token', 1)
    expect(await verifyAssertion(base(publicKeySpki, assertion))).toEqual({ counter: 1 })
  })

  it('rejects a counter that did not increase (replay)', async () => {
    const { apple, att, publicKeySpki } = await registered()
    const assertion = await apple.makeAssertion(att.credKeys, 'challenge-2:refresh-token', 5)
    await expect(verifyAssertion(base(publicKeySpki, assertion, { storedCounter: 5 }))).rejects.toMatchObject({
      reason: 'counter did not increase',
    })
  })

  it('rejects an assertion over different client data', async () => {
    const { apple, att, publicKeySpki } = await registered()
    const assertion = await apple.makeAssertion(att.credKeys, 'other-data', 1)
    await expect(verifyAssertion(base(publicKeySpki, assertion))).rejects.toMatchObject({
      reason: 'assertion signature is invalid',
    })
  })

  it('rejects an assertion signed by another key', async () => {
    const { apple, publicKeySpki } = await registered()
    const stranger = await apple.makeAttestation('x')
    const assertion = await apple.makeAssertion(stranger.credKeys, 'challenge-2:refresh-token', 1)
    await expect(verifyAssertion(base(publicKeySpki, assertion))).rejects.toMatchObject({
      reason: 'assertion signature is invalid',
    })
  })

  it('rejects another app id, tampered signatures and malformed data', async () => {
    const { apple, att, publicKeySpki } = await registered()
    const wrongApp = await apple.makeAssertion(att.credKeys, 'challenge-2:refresh-token', 1, { appId: 'OTHER.com.example' })
    await expect(verifyAssertion(base(publicKeySpki, wrongApp))).rejects.toMatchObject({ reason: 'rpIdHash does not match appId' })

    const good = fromBase64(await apple.makeAssertion(att.credKeys, 'challenge-2:refresh-token', 1))
    good[good.length - 3] = (good[good.length - 3] ?? 0) ^ 0xff
    await expect(verifyAssertion(base(publicKeySpki, toBase64(good)))).rejects.toMatchObject({ name: 'AttestationError' })

    await expect(verifyAssertion(base(publicKeySpki, 'AAAA'))).rejects.toMatchObject({ reason: 'assertion is not valid CBOR' })
  })
})
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `npx vitest run test/appAttest.test.ts 2>&1 | grep -E "Error" | head -3`
Expected: FAIL — `Cannot find module '../src/auth/appAttest'`.

- [ ] **Step 5: Criar `backend/src/auth/appAttest.ts`**

```ts
import 'reflect-metadata'
import * as x509 from '@peculiar/x509'
import { decode } from 'cbor-x'
import { concat, equalBytes, fromBase64, sha256, toBase64, utf8 } from '../lib/crypto'

export type AttestEnv = 'development' | 'production'

export class AttestationError extends Error {
  override name = 'AttestationError'
  constructor(readonly reason: string) {
    super(`Attestation rejected: ${reason}`)
  }
}

const NONCE_OID = '1.2.840.113635.100.8.2'
// A extensão é DER `SEQUENCE { [1] EXPLICIT OCTET STRING nonce }` com nonce de 32 bytes.
const NONCE_EXTENSION_PREFIX = [0x30, 0x24, 0xa1, 0x22, 0x04, 0x20]
const AAGUID: Record<AttestEnv, Uint8Array> = {
  development: utf8('appattestdevelop'),
  production: utf8('appattest\0\0\0\0\0\0\0'),
}
const AUTH_DATA_HEADER_BYTES = 37

type Cbor = Record<string, unknown>

function decodeCbor(base64: string, reason: string): Cbor {
  try {
    const value = decode(fromBase64(base64))
    if (typeof value !== 'object' || value === null) throw new Error('not a map')
    return value as Cbor
  } catch {
    throw new AttestationError(reason)
  }
}

function bytes(value: unknown, what: string): Uint8Array {
  if (!(value instanceof Uint8Array)) throw new AttestationError(`${what} is not a byte string`)
  return value
}

function counterOf(authData: Uint8Array): number {
  return new DataView(authData.buffer, authData.byteOffset, authData.byteLength).getUint32(33, false)
}

async function chainIsTrusted(credCert: x509.X509Certificate, intermediate: x509.X509Certificate, root: x509.X509Certificate, date: Date) {
  try {
    const leafOk = await credCert.verify({ publicKey: intermediate.publicKey, date })
    const intermediateOk = await intermediate.verify({ publicKey: root.publicKey, date })
    return leafOk && intermediateOk
  } catch {
    return false
  }
}

export async function verifyAttestation(input: {
  attestation: string
  keyId: string
  challenge: string
  appId: string
  allowedEnvs: AttestEnv[]
  rootCaPem: string
  nowMs: number
}): Promise<{ publicKeySpki: string }> {
  const object = decodeCbor(input.attestation, 'attestation is not valid CBOR')
  if (object.fmt !== 'apple-appattest') throw new AttestationError('unexpected attestation format')

  const x5c = (object.attStmt as Cbor | undefined)?.x5c
  if (!Array.isArray(x5c) || x5c.length < 2) throw new AttestationError('x5c must contain credCert and intermediate')
  const authData = bytes(object.authData, 'authData')

  let credCert: x509.X509Certificate
  let intermediate: x509.X509Certificate
  let root: x509.X509Certificate
  try {
    credCert = new x509.X509Certificate(bytes(x5c[0], 'x5c[0]'))
    intermediate = new x509.X509Certificate(bytes(x5c[1], 'x5c[1]'))
    root = new x509.X509Certificate(input.rootCaPem)
  } catch {
    throw new AttestationError('certificates could not be parsed')
  }
  if (!(await chainIsTrusted(credCert, intermediate, root, new Date(input.nowMs)))) {
    throw new AttestationError('certificate chain is not trusted')
  }

  // 1) nonce = SHA256(authData || SHA256(challenge)) tem de estar na extensão do credCert.
  const extension = credCert.getExtension(NONCE_OID)
  if (!extension) throw new AttestationError('nonce extension missing')
  const extensionBytes = new Uint8Array(extension.value)
  if (extensionBytes.length !== 38 || NONCE_EXTENSION_PREFIX.some((b, i) => extensionBytes[i] !== b)) {
    throw new AttestationError('nonce extension malformed')
  }
  const expectedNonce = await sha256(concat(authData, await sha256(input.challenge)))
  if (!equalBytes(extensionBytes.subarray(6), expectedNonce)) throw new AttestationError('nonce does not match challenge')

  // 2) keyId = SHA256 do ponto público (X9.62) do credCert.
  const rawPublicKey = new Uint8Array((await crypto.subtle.exportKey('raw', await credCert.publicKey.export())) as ArrayBuffer)
  const keyIdBytes = fromBase64(input.keyId)
  if (!equalBytes(await sha256(rawPublicKey), keyIdBytes)) {
    throw new AttestationError('keyId does not match credCert public key')
  }

  // 3) authData: rpIdHash, contador 0, aaguid do ambiente e credentialId = keyId.
  if (authData.length < 55) throw new AttestationError('authData is too short')
  if (!equalBytes(authData.subarray(0, 32), await sha256(input.appId))) throw new AttestationError('rpIdHash does not match appId')
  if (counterOf(authData) !== 0) throw new AttestationError('counter must be 0')
  const aaguid = authData.subarray(37, 53)
  if (!input.allowedEnvs.some((env) => equalBytes(aaguid, AAGUID[env]))) {
    throw new AttestationError('aaguid does not match an allowed environment')
  }
  const credentialIdLength = new DataView(authData.buffer, authData.byteOffset, authData.byteLength).getUint16(53, false)
  if (!equalBytes(authData.subarray(55, 55 + credentialIdLength), keyIdBytes)) {
    throw new AttestationError('credentialId does not match keyId')
  }

  return { publicKeySpki: toBase64(new Uint8Array(credCert.publicKey.rawData)) }
}

/** Converte ECDSA em DER (formato da Apple) para r||s de 64 bytes (formato do WebCrypto). */
export function derToRaw(der: Uint8Array): Uint8Array {
  const malformed = () => new AttestationError('assertion signature is invalid')
  let offset = 2
  if (der[0] !== 0x30) throw malformed()
  if (((der[1] ?? 0) & 0x80) !== 0) offset = 2 + ((der[1] ?? 0) & 0x7f)

  const readInteger = (): Uint8Array => {
    if (der[offset] !== 0x02) throw malformed()
    const length = der[offset + 1] ?? 0
    let value = der.subarray(offset + 2, offset + 2 + length)
    offset += 2 + length
    while (value.length > 32 && value[0] === 0) value = value.subarray(1)
    if (value.length > 32) throw malformed()
    const padded = new Uint8Array(32)
    padded.set(value, 32 - value.length)
    return padded
  }
  const r = readInteger()
  const s = readInteger()
  return concat(r, s)
}

export async function verifyAssertion(input: {
  assertion: string
  clientData: string
  publicKeySpki: string
  storedCounter: number
  appId: string
}): Promise<{ counter: number }> {
  const object = decodeCbor(input.assertion, 'assertion is not valid CBOR')
  const signature = bytes(object.signature, 'signature')
  const authenticatorData = bytes(object.authenticatorData, 'authenticatorData')
  if (authenticatorData.length < AUTH_DATA_HEADER_BYTES) throw new AttestationError('authenticatorData is too short')

  if (!equalBytes(authenticatorData.subarray(0, 32), await sha256(input.appId))) {
    throw new AttestationError('rpIdHash does not match appId')
  }
  const counter = counterOf(authenticatorData)
  if (counter <= input.storedCounter) throw new AttestationError('counter did not increase')

  const nonce = await sha256(concat(authenticatorData, await sha256(input.clientData)))
  const publicKey = await crypto.subtle.importKey(
    'spki',
    fromBase64(input.publicKeySpki),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['verify'],
  )
  const valid = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, publicKey, derToRaw(signature), nonce)
  if (!valid) throw new AttestationError('assertion signature is invalid')
  return { counter }
}

export type AttestVerifier = {
  verifyAttestation: typeof verifyAttestation
  verifyAssertion: typeof verifyAssertion
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `npx vitest run test/appAttest.test.ts 2>&1 | tail -6; npx tsc --noEmit 2>&1 | grep -v DEV_API_KEY | head -5`
Expected: todos PASS. Se algum teste de rejeição falhar por mensagem diferente, ajuste a ordem das verificações no verificador (a ordem do código acima é a esperada) e não os textos dos testes. Se o `tsc` apontar o tipo de `verify({ publicKey: ... })`, passe `intermediate.publicKey`/`root.publicKey` como está no código; se o tipo `PublicKey` não for aceito, use `await x.publicKey.export()`.

- [ ] **Step 7: Verificar que o bundle do Worker carrega as novas dependências**

Run: `npx wrangler deploy --dry-run --env dev --outdir .wrangler/dry 2>&1 | grep -iE "error|Total Upload"`
Expected: `Total Upload: ...` sem erros (o `appAttest.ts` ainda não é importado pelo app; este check só garante que as dependências resolvem — a verificação com o app completo está na Task BE-6).

- [ ] **Step 8: Commit**

```bash
git add backend
git commit -m "feat(backend): verify App Attest attestations and assertions"
```

### Task BE-5: Cliente do Sign in with Apple (validar token, trocar código, revogar)

**Files:**
- Create: `backend/src/auth/apple.ts`
- Test: `backend/test/apple.test.ts`

**Interfaces:**
- Consumes: `FetchLike` (de `backend/src/tmdb/client.ts`)
- Produces:
  - `class AppleAuthError extends Error`
  - `interface AppleClient { verifyIdentityToken(idToken: string, expectedNonce: string): Promise<{ sub: string }>; exchangeCode(code: string): Promise<{ refreshToken: string }>; revoke(refreshToken: string): Promise<void> }`
  - `type AppleConfig = { teamId: string; keyId: string; privateKeyPem: string; bundleId: string }`
  - `createAppleClient(config: AppleConfig, deps?: { fetchFn?: FetchLike; jwks?: JWTVerifyGetKey; nowMs?: () => number }): AppleClient`

- [ ] **Step 1: Escrever os testes que falham — `backend/test/apple.test.ts`**

```ts
import { createLocalJWKSet, decodeJwt, decodeProtectedHeader, exportJWK, exportPKCS8, generateKeyPair, SignJWT } from 'jose'
import { describe, expect, it } from 'vitest'
import { AppleAuthError, createAppleClient } from '../src/auth/apple'

const BUNDLE = 'com.andre.filmfinder'
const NOW = Date.UTC(2026, 9, 5, 12, 0, 0)
const nowSec = Math.floor(NOW / 1000)

async function setup() {
  const appleKeys = await generateKeyPair('RS256', { extractable: true })
  const jwks = createLocalJWKSet({ keys: [{ ...(await exportJWK(appleKeys.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' }] })
  const teamKey = await generateKeyPair('ES256', { extractable: true })
  const privateKeyPem = await exportPKCS8(teamKey.privateKey)

  const calls: { url: string; form: URLSearchParams }[] = []
  const state = { status: 200, body: { refresh_token: 'apple-refresh-1' } as unknown }
  const fetchFn = async (url: string, init?: RequestInit) => {
    calls.push({ url, form: new URLSearchParams(String(init?.body)) })
    return new Response(JSON.stringify(state.body), { status: state.status })
  }
  const client = createAppleClient(
    { teamId: 'TEAM123456', keyId: 'KEY1234567', privateKeyPem, bundleId: BUNDLE },
    { fetchFn, jwks, nowMs: () => NOW },
  )

  const token = (over: { iss?: string; aud?: string; sub?: string; nonce?: string; exp?: number; key?: CryptoKey } = {}) =>
    new SignJWT({ nonce: over.nonce ?? 'nonce-1' })
      .setProtectedHeader({ alg: 'RS256', kid: 'k1' })
      .setIssuer(over.iss ?? 'https://appleid.apple.com')
      .setAudience(over.aud ?? BUNDLE)
      .setSubject(over.sub ?? '000123.abcdef')
      .setIssuedAt(nowSec)
      .setExpirationTime(over.exp ?? nowSec + 600)
      .sign(over.key ?? appleKeys.privateKey)

  return { client, calls, state, token }
}

describe('verifyIdentityToken', () => {
  it('accepts a valid token and returns the subject', async () => {
    const { client, token } = await setup()
    expect(await client.verifyIdentityToken(await token(), 'nonce-1')).toEqual({ sub: '000123.abcdef' })
  })

  it.each([
    ['wrong nonce', { nonce: 'other' }],
    ['wrong audience', { aud: 'com.other.app' }],
    ['wrong issuer', { iss: 'https://evil.example' }],
    ['expired token', { exp: nowSec - 10 }],
  ])('rejects %s', async (_name, over) => {
    const { client, token } = await setup()
    await expect(client.verifyIdentityToken(await token(over), 'nonce-1')).rejects.toBeInstanceOf(AppleAuthError)
  })

  it('rejects a token signed by an unknown key and garbage', async () => {
    const { client, token } = await setup()
    const stranger = await generateKeyPair('RS256', { extractable: true })
    await expect(client.verifyIdentityToken(await token({ key: stranger.privateKey }), 'nonce-1')).rejects.toBeInstanceOf(AppleAuthError)
    await expect(client.verifyIdentityToken('garbage', 'nonce-1')).rejects.toBeInstanceOf(AppleAuthError)
  })
})

describe('exchangeCode', () => {
  it('posts the code with a valid ES256 client secret and returns the refresh token', async () => {
    const { client, calls } = await setup()
    expect(await client.exchangeCode('code-1')).toEqual({ refreshToken: 'apple-refresh-1' })

    const call = calls[0]!
    expect(call.url).toBe('https://appleid.apple.com/auth/token')
    expect(call.form.get('grant_type')).toBe('authorization_code')
    expect(call.form.get('code')).toBe('code-1')
    expect(call.form.get('client_id')).toBe(BUNDLE)

    const secret = call.form.get('client_secret')!
    expect(decodeProtectedHeader(secret)).toMatchObject({ alg: 'ES256', kid: 'KEY1234567' })
    expect(decodeJwt(secret)).toMatchObject({ iss: 'TEAM123456', sub: BUNDLE, aud: 'https://appleid.apple.com' })
    expect((decodeJwt(secret).exp ?? 0) - nowSec).toBeLessThanOrEqual(15_777_000) // Apple aceita até ~6 meses
  })

  it('fails when Apple rejects the code or returns no refresh token', async () => {
    const { client, state } = await setup()
    state.status = 400
    await expect(client.exchangeCode('bad')).rejects.toBeInstanceOf(AppleAuthError)
    state.status = 200
    state.body = {}
    await expect(client.exchangeCode('bad')).rejects.toBeInstanceOf(AppleAuthError)
  })
})

describe('revoke', () => {
  it('posts the refresh token with a type hint', async () => {
    const { client, calls } = await setup()
    await client.revoke('apple-refresh-1')
    const call = calls[0]!
    expect(call.url).toBe('https://appleid.apple.com/auth/revoke')
    expect(call.form.get('token')).toBe('apple-refresh-1')
    expect(call.form.get('token_type_hint')).toBe('refresh_token')
    expect(call.form.get('client_id')).toBe(BUNDLE)
  })

  it('throws when Apple responds with an error', async () => {
    const { client, state } = await setup()
    state.status = 500
    await expect(client.revoke('t')).rejects.toBeInstanceOf(AppleAuthError)
  })
})
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run test/apple.test.ts 2>&1 | grep -E "Error" | head -3`
Expected: FAIL — `Cannot find module '../src/auth/apple'`.

- [ ] **Step 3: Criar `backend/src/auth/apple.ts`**

```ts
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT, type JWTVerifyGetKey } from 'jose'
import type { FetchLike } from '../tmdb/client'

export class AppleAuthError extends Error {
  override name = 'AppleAuthError'
}

export type AppleConfig = {
  teamId: string
  keyId: string
  /** Conteúdo do arquivo .p8 (PKCS#8, ES256) da chave de Sign in with Apple. */
  privateKeyPem: string
  bundleId: string
}

export interface AppleClient {
  verifyIdentityToken(idToken: string, expectedNonce: string): Promise<{ sub: string }>
  exchangeCode(code: string): Promise<{ refreshToken: string }>
  revoke(refreshToken: string): Promise<void>
}

const APPLE = 'https://appleid.apple.com'

export function createAppleClient(
  config: AppleConfig,
  deps: { fetchFn?: FetchLike; jwks?: JWTVerifyGetKey; nowMs?: () => number } = {},
): AppleClient {
  const fetchFn: FetchLike = deps.fetchFn ?? ((url, init) => fetch(url, init))
  const jwks = deps.jwks ?? createRemoteJWKSet(new URL(`${APPLE}/auth/keys`))
  const nowMs = deps.nowMs ?? Date.now

  async function clientSecret(): Promise<string> {
    const key = await importPKCS8(config.privateKeyPem, 'ES256')
    const iat = Math.floor(nowMs() / 1000)
    return new SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: config.keyId })
      .setIssuer(config.teamId)
      .setIssuedAt(iat)
      .setExpirationTime(iat + 600)
      .setAudience(APPLE)
      .setSubject(config.bundleId)
      .sign(key)
  }

  async function postForm(path: string, params: Record<string, string>): Promise<Response> {
    return fetchFn(`${APPLE}${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: config.bundleId, client_secret: await clientSecret(), ...params }).toString(),
    })
  }

  return {
    async verifyIdentityToken(idToken, expectedNonce) {
      try {
        const { payload } = await jwtVerify(idToken, jwks, {
          issuer: APPLE,
          audience: config.bundleId,
          currentDate: new Date(nowMs()),
        })
        if (payload.nonce !== expectedNonce || !payload.sub) throw new Error('nonce or subject mismatch')
        return { sub: payload.sub }
      } catch {
        throw new AppleAuthError('Invalid identity token')
      }
    },

    async exchangeCode(code) {
      const response = await postForm('/auth/token', { code, grant_type: 'authorization_code' })
      if (!response.ok) throw new AppleAuthError(`Apple token endpoint responded ${response.status}`)
      const body = (await response.json()) as { refresh_token?: string }
      if (!body.refresh_token) throw new AppleAuthError('Apple did not return a refresh token')
      return { refreshToken: body.refresh_token }
    },

    async revoke(refreshToken) {
      const response = await postForm('/auth/revoke', { token: refreshToken, token_type_hint: 'refresh_token' })
      if (!response.ok) throw new AppleAuthError(`Apple revoke endpoint responded ${response.status}`)
    },
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `npx vitest run test/apple.test.ts 2>&1 | tail -4; npx tsc --noEmit 2>&1 | grep -v DEV_API_KEY | head -5`
Expected: todos PASS; sem erros de tipo além dos de `DEV_API_KEY` (resolvidos na Task BE-6).

- [ ] **Step 5: Commit**

```bash
git add backend
git commit -m "feat(backend): add Sign in with Apple client (verify, exchange, revoke)"
```

---

### Task BE-6: Integração da autenticação e da cota na rota de recomendações

Esta tarefa reestrutura o app (`app.ts`, `deps.ts`), remove o `x-dev-key` e faz `/v1/recommendations` exigir Bearer, reservar cota e devolvê-la. Termina com **toda** a suíte do backend verde.

**Files:**
- Create: `backend/src/context.ts`, `backend/src/settings.ts`, `backend/src/auth/middleware.ts`, `backend/test/helpers/appHarness.ts`, `backend/test/settings.test.ts`
- Modify (substituir): `backend/src/app.ts`, `backend/src/deps.ts`, `backend/src/routes/recommendations.ts`, `backend/test/recommendations.test.ts`, `backend/test/deps.test.ts`

**Interfaces:**
- Consumes: tudo das Tasks BE-1 a BE-5
- Produces:
  - `type AppEnv = { Bindings: Env; Variables: { deps: Deps; identity: Identity } }` (em `src/context.ts`)
  - `type Settings = { appId; bundleId; allowUnattested; allowProviderOverride; attestEnvs: AttestEnv[]; rootCaPem }`, `loadSettings(env: Env): Settings`
  - `Deps` ampliado com `db: Db`, `tokens: TokenService`, `apple: AppleClient`, `attest: AttestVerifier`, `now: () => number`, `settings: Settings`
  - `requireAuth` (middleware Hono): lê `Authorization: Bearer`, valida o JWT, carrega o dispositivo do banco e define `c.get('identity')`
  - `POST /v1/recommendations` (autenticada): reserva cota antes de chamar a IA, devolve se falhar/vier vazio, responde `{ titles, quota }`; 402 `quota_exceeded`
  - Teste: `createHarness(options?)` → `{ app, deps, db, tokens, fakeApple, request(path, init?), newDevice(opts?), setNow(ms), advance(ms), state, revoked, providers }` e `json(res)`

- [ ] **Step 1: Criar `backend/src/context.ts`**

```ts
import type { Identity } from './auth/identity'
import type { Deps } from './deps'
import type { Env } from './env'

export type AppEnv = {
  Bindings: Env
  Variables: { deps: Deps; identity: Identity }
}
```

- [ ] **Step 2: Escrever o teste de settings — `backend/test/settings.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import type { Env } from '../src/env'
import { loadSettings } from '../src/settings'

const env = (over: Partial<Record<keyof Env, string>> = {}) =>
  ({
    APPLE_TEAM_ID: 'TEAM123456',
    APPLE_BUNDLE_ID: 'com.andre.filmfinder',
    ALLOW_UNATTESTED: 'false',
    ALLOW_PROVIDER_OVERRIDE: 'false',
    APPATTEST_ENVS: 'production',
    ...over,
  }) as unknown as Env

describe('loadSettings', () => {
  it('builds the app id and parses flags', () => {
    const s = loadSettings(env())
    expect(s).toMatchObject({
      appId: 'TEAM123456.com.andre.filmfinder',
      bundleId: 'com.andre.filmfinder',
      allowUnattested: false,
      allowProviderOverride: false,
      attestEnvs: ['production'],
    })
    expect(s.rootCaPem).toContain('BEGIN CERTIFICATE')
  })

  it('only enables the dev switches when exactly "true"', () => {
    const s = loadSettings(env({ ALLOW_UNATTESTED: 'true', ALLOW_PROVIDER_OVERRIDE: 'TRUE' }))
    expect(s.allowUnattested).toBe(true)
    expect(s.allowProviderOverride).toBe(false)
  })

  it('parses environments and falls back to production for junk', () => {
    expect(loadSettings(env({ APPATTEST_ENVS: 'development, production' })).attestEnvs).toEqual(['development', 'production'])
    expect(loadSettings(env({ APPATTEST_ENVS: 'bogus' })).attestEnvs).toEqual(['production'])
    expect(loadSettings(env({ APPATTEST_ENVS: '' })).attestEnvs).toEqual(['production'])
  })
})
```

- [ ] **Step 3: Criar `backend/src/settings.ts`**

```ts
import type { AttestEnv } from './auth/appAttest'
import { APPLE_APP_ATTEST_ROOT_CA_PEM } from './auth/appleRootCa'
import type { Env } from './env'

export type Settings = {
  appId: string
  bundleId: string
  allowUnattested: boolean
  allowProviderOverride: boolean
  attestEnvs: AttestEnv[]
  rootCaPem: string
}

export function loadSettings(env: Env): Settings {
  const attestEnvs = (env.APPATTEST_ENVS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter((s): s is AttestEnv => s === 'development' || s === 'production')
  return {
    appId: `${env.APPLE_TEAM_ID}.${env.APPLE_BUNDLE_ID}`,
    bundleId: env.APPLE_BUNDLE_ID,
    allowUnattested: env.ALLOW_UNATTESTED === 'true',
    allowProviderOverride: env.ALLOW_PROVIDER_OVERRIDE === 'true',
    attestEnvs: attestEnvs.length > 0 ? attestEnvs : ['production'],
    rootCaPem: APPLE_APP_ATTEST_ROOT_CA_PEM,
  }
}
```

- [ ] **Step 4: Substituir `backend/src/deps.ts`**

```ts
import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import { createAnthropicProvider } from './ai/anthropic'
import { createGeminiProvider } from './ai/gemini'
import { createOpenAIProvider } from './ai/openai'
import type { AiEvent } from './ai/orchestrator'
import type { RecommendationProvider } from './ai/types'
import { createAppleClient, type AppleClient } from './auth/apple'
import { verifyAssertion, verifyAttestation, type AttestVerifier } from './auth/appAttest'
import { TokenService } from './auth/tokens'
import type { ProviderName } from './config'
import type { Env } from './env'
import { d1Db, type Db } from './lib/db'
import type { KVLike } from './lib/kv'
import { loadSettings, type Settings } from './settings'
import { TmdbClient } from './tmdb/client'

export type Deps = {
  config: KVLike
  cache: KVLike
  tmdb: Pick<TmdbClient, 'search' | 'details'>
  provider(name: ProviderName, model: string): RecommendationProvider
  log(e: AiEvent): void
  db: Db
  tokens: TokenService
  apple: AppleClient
  attest: AttestVerifier
  now: () => number
  settings: Settings
}

const GATEWAY_SLUG: Record<ProviderName, string> = {
  anthropic: 'anthropic',
  openai: 'openai',
  gemini: 'google-ai-studio',
}

export function gatewayBaseUrl(env: Env, provider: ProviderName): string {
  return `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/${env.AI_GATEWAY_ID}/${GATEWAY_SLUG[provider]}`
}

export function gatewayHeaders(env: Env): Record<string, string> {
  return env.CF_AIG_TOKEN ? { 'cf-aig-authorization': `Bearer ${env.CF_AIG_TOKEN}` } : {}
}

export function createDeps(env: Env): Deps {
  const db = d1Db(env.DB)
  const now = () => Date.now()
  return {
    config: env.CONFIG,
    cache: env.CACHE,
    tmdb: new TmdbClient(env.TMDB_TOKEN),
    provider(name, model) {
      if (name === 'anthropic') {
        const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, baseURL: gatewayBaseUrl(env, 'anthropic'), defaultHeaders: gatewayHeaders(env), maxRetries: 0 })
        return createAnthropicProvider(client, model)
      }
      if (name === 'gemini') {
        return createGeminiProvider({ apiKey: env.GEMINI_API_KEY ?? '', baseUrl: gatewayBaseUrl(env, 'gemini'), model, extraHeaders: gatewayHeaders(env) })
      }
      const client = new OpenAI({ apiKey: env.OPENAI_API_KEY ?? '', baseURL: gatewayBaseUrl(env, 'openai'), defaultHeaders: gatewayHeaders(env), maxRetries: 0 })
      return createOpenAIProvider(client, model)
    },
    log(e) {
      console.log(JSON.stringify({ event: 'ai_call', ...e }))
      env.AI_EVENTS?.writeDataPoint({
        indexes: [e.provider],
        blobs: [e.provider, e.ok ? 'ok' : 'fail', e.error ?? '', String(e.promptVersion)],
        doubles: [e.latencyMs, e.picks, e.fallback ? 1 : 0],
      })
    },
    db,
    tokens: new TokenService(env.JWT_SECRET, db, now),
    apple: createAppleClient({
      teamId: env.APPLE_TEAM_ID,
      keyId: env.APPLE_KEY_ID,
      privateKeyPem: env.APPLE_PRIVATE_KEY,
      bundleId: env.APPLE_BUNDLE_ID,
    }),
    attest: { verifyAttestation, verifyAssertion },
    now,
    settings: loadSettings(env),
  }
}
```

- [ ] **Step 5: Atualizar `backend/test/deps.test.ts`** — o `env` do teste precisa dos novos campos e o teste de `createDeps` passa a conferir os novos serviços. Substituir o início do arquivo (a constante `env`) e acrescentar um teste:

```ts
const env = {
  CACHE: new MemoryKV(),
  CONFIG: new MemoryKV(),
  DB: {},
  AI_EVENTS: { writeDataPoint },
  ANTHROPIC_API_KEY: 'a',
  OPENAI_API_KEY: 'o',
  GEMINI_API_KEY: 'g',
  TMDB_TOKEN: 't',
  CF_ACCOUNT_ID: 'acct',
  AI_GATEWAY_ID: 'gw',
  JWT_SECRET: 'a-test-secret-with-more-than-32-characters',
  APPLE_TEAM_ID: 'TEAM123456',
  APPLE_KEY_ID: 'KEY1234567',
  APPLE_BUNDLE_ID: 'com.andre.filmfinder',
  APPLE_PRIVATE_KEY: 'pem',
  ALLOW_UNATTESTED: 'true',
  ALLOW_PROVIDER_OVERRIDE: 'false',
  APPATTEST_ENVS: 'development',
} as unknown as Env
```
e, dentro de `describe('createDeps', ...)`:
```ts
  it('wires identity services and settings', () => {
    const deps = createDeps(env)
    expect(deps.settings.appId).toBe('TEAM123456.com.andre.filmfinder')
    expect(deps.settings.allowUnattested).toBe(true)
    expect(typeof deps.tokens.issueAccess).toBe('function')
    expect(typeof deps.attest.verifyAttestation).toBe('function')
    expect(typeof deps.now()).toBe('number')
  })
```
(Os demais testes do arquivo — `gatewayBaseUrl`, `gatewayHeaders`, `provider`, `log` — permanecem iguais.)

- [ ] **Step 6: Criar `backend/src/auth/middleware.ts`**

```ts
import { createMiddleware } from 'hono/factory'
import type { AppEnv } from '../context'
import { getDevice } from '../db/devices'
import { ApiError } from '../lib/errors'

/** Exige `Authorization: Bearer <accessToken>`; o usuário vem do banco (logout/exclusão valem na hora). */
export const requireAuth = createMiddleware<AppEnv>(async (c, next) => {
  const { tokens, db } = c.get('deps')
  const header = c.req.header('authorization') ?? ''
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : ''
  if (!token) throw new ApiError('unauthorized', 'Missing credentials', 401)

  const { deviceId } = await tokens.verifyAccess(token)
  const device = await getDevice(db, deviceId)
  if (!device) throw new ApiError('unauthorized', 'Unknown device', 401)

  c.set('identity', { deviceId, userId: device.user_id })
  await next()
})
```

- [ ] **Step 7: Substituir `backend/src/app.ts`**

```ts
import { Hono } from 'hono'
import { requireAuth } from './auth/middleware'
import type { AppEnv } from './context'
import type { Deps } from './deps'
import type { Env } from './env'
import { ApiError, errorBody } from './lib/errors'
import { postRecommendations } from './routes/recommendations'

export function createApp(makeDeps: (env: Env) => Deps) {
  const app = new Hono<AppEnv>()

  app.use('*', async (c, next) => {
    c.set('deps', makeDeps(c.env))
    await next()
  })

  app.get('/health', (c) => c.json({ ok: true }))

  // Rotas públicas de autenticação entram aqui (Task BE-7).

  const authed = new Hono<AppEnv>()
  authed.use('*', requireAuth)
  authed.post('/recommendations', postRecommendations)
  // Rotas de conta entram aqui (Task BE-8).
  app.route('/v1', authed)

  app.onError((err, c) => {
    if (err instanceof ApiError) return c.json(errorBody(err.code, err.message), err.status)
    console.error(err)
    return c.json(errorBody('internal', 'Unexpected error'), 500)
  })

  return app
}
```

- [ ] **Step 8: Substituir `backend/src/routes/recommendations.ts`**

```ts
import type { Context } from 'hono'
import { recommendWithFallback } from '../ai/orchestrator'
import { loadConfig, type AppConfig, type ProviderName } from '../config'
import type { AppEnv } from '../context'
import { AiUnavailableError, ApiError } from '../lib/errors'
import { QuotaExceededError, quotaSnapshot, refundSearch, reserveSearch } from '../quota'
import { RecommendationRequest, type AiPick } from '../schemas'
import { loadExcludeLabels, resolvePicks } from '../tmdb/resolver'

const AI_TIMEOUT_MS = 15000
const MIN_PICKS = 3
const PICKS_REQUESTED = 12

function providerOrder(config: AppConfig, forced: string | undefined): ProviderName[] {
  if (forced === 'anthropic' || forced === 'openai' || forced === 'gemini') return [forced]
  return [config.primary, config.secondary]
}

export async function postRecommendations(c: Context<AppEnv>) {
  const deps = c.get('deps')
  const identity = c.get('identity')

  const parsed = RecommendationRequest.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) {
    throw new ApiError('invalid_input', parsed.error.issues[0]?.message ?? 'Invalid request', 400)
  }
  const req = parsed.data
  const config = await loadConfig(deps.config)

  try {
    await reserveSearch(deps.db, config, identity, deps.now())
  } catch (err) {
    if (err instanceof QuotaExceededError) throw new ApiError('quota_exceeded', 'Daily search limit reached', 402)
    throw err
  }

  // A busca só consome cota se devolver pelo menos 1 título.
  let refunded = false
  const giveBack = async () => {
    if (refunded) return
    refunded = true
    await refundSearch(deps.db, identity, deps.now())
  }

  try {
    const excludeLabels = await loadExcludeLabels(deps.cache, req.mediaType, req.excludeTmdbIds)
    const forced = deps.settings.allowProviderOverride ? c.req.header('x-ai-provider') : undefined
    const providers = providerOrder(config, forced).map((name) => deps.provider(name, config.models[name]))

    let picks: AiPick[]
    try {
      ;({ picks } = await recommendWithFallback(
        providers,
        { query: req.query, mediaType: req.mediaType, locale: req.locale, excludeLabels, count: PICKS_REQUESTED },
        { timeoutMs: AI_TIMEOUT_MS, minPicks: MIN_PICKS, log: deps.log },
      ))
    } catch (err) {
      if (err instanceof AiUnavailableError) {
        throw new ApiError('ai_unavailable', 'Recommendation service is temporarily unavailable', 503)
      }
      throw err
    }

    const titles = await resolvePicks(picks, req, { tmdb: deps.tmdb, cache: deps.cache })
    if (titles.length === 0) await giveBack()
    return c.json({ titles, quota: await quotaSnapshot(deps.db, config, identity, deps.now()) })
  } catch (err) {
    await giveBack()
    throw err
  }
}
```

- [ ] **Step 9: Criar o harness de testes `backend/test/helpers/appHarness.ts`**

```ts
import { verifyAssertion, verifyAttestation } from '../../src/auth/appAttest'
import { AppleAuthError, type AppleClient } from '../../src/auth/apple'
import { TokenService } from '../../src/auth/tokens'
import { createApp } from '../../src/app'
import type { RecommendationProvider } from '../../src/ai/types'
import type { ProviderName } from '../../src/config'
import { createDevice, linkDeviceToUser } from '../../src/db/devices'
import type { Deps } from '../../src/deps'
import type { Env } from '../../src/env'
import type { AiPick } from '../../src/schemas'
import type { Settings } from '../../src/settings'
import { interstellar } from '../fixtures/tmdb'
import { createFakeApple } from './fakeApple'
import { MemoryKV } from './memoryKV'
import { createTestDb } from './sqliteDb'
import { vi } from 'vitest'

export const APP_ID = 'TEAM123456.com.andre.filmfinder'
export const T0 = Date.UTC(2026, 9, 5, 12, 0, 0)

const DEFAULT_PICKS: AiPick[] = ['A', 'B', 'C'].map((t, i) => ({ title: t, originalTitle: t, year: 2014, reason: `r${i}` }))

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const json = async (res: Response) => (await res.json()) as any

export async function createHarness(options: { settings?: Partial<Settings>; failRevoke?: boolean } = {}) {
  const db = createTestDb()
  let nowMs = T0
  const now = () => nowMs
  const fakeApple = await createFakeApple(APP_ID)
  const tokens = new TokenService('harness-secret-with-more-than-32-characters', db, now)

  const state = { failRevoke: options.failRevoke ?? false }
  const revoked: string[] = []
  // Token de identidade de teste: `fake:<sub>:<nonce>`.
  const apple: AppleClient = {
    async verifyIdentityToken(token, expectedNonce) {
      const [prefix, sub, nonce] = token.split(':')
      if (prefix !== 'fake' || !sub || nonce !== expectedNonce) throw new AppleAuthError('bad identity token')
      return { sub }
    },
    async exchangeCode(code) {
      return { refreshToken: `apple-refresh-${code}` }
    },
    async revoke(refreshToken) {
      if (state.failRevoke) throw new AppleAuthError('revoke failed')
      revoked.push(refreshToken)
    },
  }

  const settings: Settings = {
    appId: APP_ID,
    bundleId: 'com.andre.filmfinder',
    allowUnattested: true,
    allowProviderOverride: false,
    attestEnvs: ['development'],
    rootCaPem: fakeApple.rootPem,
    ...options.settings,
  }

  const providers: Partial<Record<ProviderName, RecommendationProvider>> = {}
  const providerCalls: ProviderName[] = []
  const deps: Deps = {
    config: new MemoryKV(),
    cache: new MemoryKV(),
    tmdb: {
      search: vi.fn(async (_m: string, q: string) => ({ A: 1, B: 2, C: 3 } as Record<string, number>)[q] ?? null),
      details: vi.fn(async (_m: string, id: number) => ({ ...interstellar, id })),
    },
    provider: (name) => {
      providerCalls.push(name)
      return providers[name] ?? { name, recommend: async () => DEFAULT_PICKS }
    },
    log: vi.fn(),
    db,
    tokens,
    apple,
    attest: { verifyAttestation, verifyAssertion },
    now,
    settings,
  }
  const app = createApp(() => deps)

  async function request(
    path: string,
    init: { method?: string; body?: unknown; token?: string; headers?: Record<string, string> } = {},
  ) {
    const headers: Record<string, string> = { ...init.headers }
    if (init.body !== undefined) headers['content-type'] = 'application/json'
    if (init.token) headers.authorization = `Bearer ${init.token}`
    return app.request(
      path,
      {
        method: init.method ?? (init.body !== undefined ? 'POST' : 'GET'),
        headers,
        body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
      },
      {} as Env,
    )
  }

  /** Cria um dispositivo direto no banco e emite tokens (atalho para testes de rotas autenticadas). */
  async function newDevice(opts: { keyId?: string; publicKey?: string; userId?: string } = {}) {
    const deviceId = crypto.randomUUID()
    await createDevice(db, { id: deviceId, keyId: opts.keyId ?? null, publicKey: opts.publicKey ?? null, nowSec: Math.floor(nowMs / 1000) })
    if (opts.userId) await linkDeviceToUser(db, deviceId, opts.userId)
    const { accessToken } = await tokens.issueAccess(deviceId)
    const refreshToken = await tokens.issueRefresh(deviceId)
    return { deviceId, accessToken, refreshToken }
  }

  return {
    app,
    deps,
    db,
    tokens,
    fakeApple,
    request,
    newDevice,
    state,
    revoked,
    providers,
    providerCalls,
    setNow: (ms: number) => (nowMs = ms),
    advance: (ms: number) => (nowMs += ms),
  }
}
```

- [ ] **Step 10: Substituir `backend/test/recommendations.test.ts`**

```ts
import { describe, expect, it, vi } from 'vitest'
import type { RecommendationProvider } from '../src/ai/types'
import type { ProviderName } from '../src/config'
import { grantEntitlement, UNLIMITED_SEARCH } from '../src/db/entitlements'
import { getUsage } from '../src/db/usage'
import { ProviderError } from '../src/lib/errors'
import { createHarness, json, T0 } from './helpers/appHarness'

const valid = { query: 'ficção científica emocionante', mediaType: 'movie', locale: 'pt-BR', region: 'BR' }
const failing = (name: ProviderName): RecommendationProvider => ({
  name,
  recommend: async () => {
    throw new ProviderError('x')
  },
})
const ids = (body: { titles: { tmdbId: number }[] }) => body.titles.map((t) => t.tmdbId)

describe('POST /v1/recommendations', () => {
  it('requires a bearer token', async () => {
    const h = await createHarness()
    const res = await h.request('/v1/recommendations', { body: valid })
    expect(res.status).toBe(401)
    expect(await json(res)).toEqual({ error: { code: 'unauthorized', message: expect.any(String) } })
  })

  it('rejects tokens for devices that no longer exist', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await h.db.run('DELETE FROM devices WHERE id = ?', [d.deviceId])
    expect((await h.request('/v1/recommendations', { body: valid, token: d.accessToken })).status).toBe(401)
  })

  it('rejects invalid input without consuming quota', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: { query: '', mediaType: 'movie' }, token: d.accessToken })
    expect(res.status).toBe(400)
    expect((await json(res)).error.code).toBe('invalid_input')
    expect(await getUsage(h.db, 'device', d.deviceId, '2026-10-05')).toBe(0)
  })

  it('returns resolved titles and the quota', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(ids(body)).toEqual([1, 2, 3])
    expect(body.titles[0].providers.region).toBe('BR')
    expect(body.quota).toEqual({ used: 1, limit: 5, resetsAt: '2026-10-06T00:00:00Z' })
  })

  it('filters excluded ids', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: { ...valid, excludeTmdbIds: [2] }, token: d.accessToken })
    expect(ids(await json(res))).toEqual([1, 3])
  })

  it('uses gemini then anthropic by default and honours ai.primary/secondary', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(h.providerCalls).toEqual(['gemini', 'anthropic'])
  })

  it('ignores x-ai-provider unless the override switch is on', async () => {
    const off = await createHarness()
    const d1 = await off.newDevice()
    await off.request('/v1/recommendations', { body: valid, token: d1.accessToken, headers: { 'x-ai-provider': 'openai' } })
    expect(off.providerCalls).toEqual(['gemini', 'anthropic'])

    const on = await createHarness({ settings: { allowProviderOverride: true } })
    const d2 = await on.newDevice()
    await on.request('/v1/recommendations', { body: valid, token: d2.accessToken, headers: { 'x-ai-provider': 'openai' } })
    expect(on.providerCalls).toEqual(['openai'])
  })

  it('returns 503 and gives the search back when every provider fails', async () => {
    const h = await createHarness()
    h.providers.gemini = failing('gemini')
    h.providers.anthropic = failing('anthropic')
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(res.status).toBe(503)
    expect((await json(res)).error.code).toBe('ai_unavailable')
    expect(await getUsage(h.db, 'device', d.deviceId, '2026-10-05')).toBe(0)
  })

  it('returns 200 with empty titles and does not consume quota when nothing resolves', async () => {
    const h = await createHarness()
    h.deps.tmdb.search = vi.fn(async () => null)
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.titles).toEqual([])
    expect(body.quota.used).toBe(0)
  })

  it('blocks the 6th free search with 402 quota_exceeded', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    for (let i = 1; i <= 5; i++) {
      expect((await json(await h.request('/v1/recommendations', { body: valid, token: d.accessToken }))).quota.used).toBe(i)
    }
    const res = await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(res.status).toBe(402)
    expect((await json(res)).error.code).toBe('quota_exceeded')
  })

  it('resets the next UTC day', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    for (let i = 0; i < 5; i++) await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    h.setNow(Date.UTC(2026, 9, 6, 0, 0, 5))
    const token = (await h.tokens.issueAccess(d.deviceId)).accessToken
    expect((await h.request('/v1/recommendations', { body: valid, token })).status).toBe(200)
  })

  it('applies the pro limit for devices/users with unlimited_search', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await grantEntitlement(h.db, { id: 'e1', ownerKind: 'device', ownerId: d.deviceId, kind: UNLIMITED_SEARCH, expiresAt: T0 / 1000 + 3600 })
    for (let i = 0; i < 6; i++) {
      expect((await h.request('/v1/recommendations', { body: valid, token: d.accessToken })).status).toBe(200)
    }
  })
})
```

- [ ] **Step 11: Rodar e ver falhar, depois passar**

Run (antes de aplicar os Steps 3–10 isso falha por módulos ausentes; depois deles): `npx vitest run 2>&1 | tail -8; npx tsc --noEmit 2>&1 | head -10`
Expected: **toda a suíte PASS** e `tsc` sem erros. Se o `tsc` acusar `Env` em arquivos antigos (`test/health.test.ts`), ele já usa `createApp(() => ({}) as never)` e não deve falhar; qualquer outra referência a `DEV_API_KEY` ou ao `Deps` antigo deve ser removida/atualizada.

- [ ] **Step 12: Verificar o bundle com o app completo**

Run: `npx wrangler deploy --dry-run --env dev --outdir .wrangler/dry 2>&1 | grep -iE "error|Total Upload"`
Expected: `Total Upload: ...` sem erros (agora o `appAttest.ts` e o `@peculiar/x509` entram no bundle).

- [ ] **Step 13: Commit**

```bash
git add backend
git commit -m "feat(backend): require bearer auth and enforce daily search quota on recommendations"
```

---

### Task BE-7: Rotas públicas — desafio, registro de dispositivo e renovação de token

**Files:**
- Create: `backend/src/routes/publicAuth.ts`, `backend/src/auth/session.ts`
- Modify: `backend/src/app.ts` (montar as rotas)
- Test: `backend/test/publicAuth.test.ts`

**Interfaces:**
- Consumes: `createChallenge`, `consumeChallenge` (BE-3); `verifyAttestation`, `verifyAssertion`, `AttestationError` (BE-4); `createDevice`, `getDevice`, `updateCounter` (BE-3); `Deps`, `AppEnv` (BE-6); harness (BE-6)
- Produces:
  - `issueSession(deps, deviceId): Promise<{ accessToken: string; expiresAt: number; refreshToken: string }>`
  - `POST /v1/auth/challenge` → `{ challenge }`
  - `POST /v1/devices` com `{ unattested: true }` (só se `ALLOW_UNATTESTED`) **ou** `{ keyId, attestation, challenge }` → `{ accessToken, expiresAt, refreshToken }`
  - `POST /v1/auth/refresh` com `{ refreshToken, challenge?, assertion? }` → `{ accessToken, expiresAt, refreshToken }` (o refresh antigo é consumido; dispositivos atestados exigem `challenge` + `assertion` sobre `"{challenge}:{refreshToken}"`)

- [ ] **Step 1: Escrever os testes que falham — `backend/test/publicAuth.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import { getDevice } from '../src/db/devices'
import { createHarness, json } from './helpers/appHarness'

async function challenge(h: Awaited<ReturnType<typeof createHarness>>): Promise<string> {
  return (await json(await h.request('/v1/auth/challenge', { method: 'POST' }))).challenge
}

describe('POST /v1/auth/challenge', () => {
  it('returns a fresh challenge each time', async () => {
    const h = await createHarness()
    const a = await challenge(h)
    expect(a.length).toBeGreaterThan(20)
    expect(a).not.toBe(await challenge(h))
  })
})

describe('POST /v1/devices', () => {
  it('registers an unattested device when the dev switch is on', async () => {
    const h = await createHarness()
    const res = await h.request('/v1/devices', { body: { unattested: true } })
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.accessToken).toBeTruthy()
    expect(body.refreshToken).toBeTruthy()
    expect(body.expiresAt).toBe(Math.floor(Date.UTC(2026, 9, 5, 12, 15) / 1000))
    const { deviceId } = await h.tokens.verifyAccess(body.accessToken)
    expect(await getDevice(h.db, deviceId)).toMatchObject({ key_id: null, user_id: null, counter: 0 })
  })

  it('forbids unattested devices when the dev switch is off', async () => {
    const h = await createHarness({ settings: { allowUnattested: false } })
    const res = await h.request('/v1/devices', { body: { unattested: true } })
    expect(res.status).toBe(403)
    expect((await json(res)).error.code).toBe('forbidden')
  })

  it('registers an attested device and stores its public key', async () => {
    const h = await createHarness()
    const c = await challenge(h)
    const att = await h.fakeApple.makeAttestation(c)
    const res = await h.request('/v1/devices', { body: { keyId: att.keyId, attestation: att.attestation, challenge: c } })
    expect(res.status).toBe(200)
    const { deviceId } = await h.tokens.verifyAccess((await json(res)).accessToken)
    const device = await getDevice(h.db, deviceId)
    expect(device?.key_id).toBe(att.keyId)
    expect(device?.public_key).toBeTruthy()
    expect(device?.counter).toBe(0)
  })

  it('rejects an unknown or reused challenge', async () => {
    const h = await createHarness()
    const att = await h.fakeApple.makeAttestation('whatever')
    const unknown = await h.request('/v1/devices', { body: { keyId: att.keyId, attestation: att.attestation, challenge: 'whatever' } })
    expect(unknown.status).toBe(400)
    expect((await json(unknown)).error.code).toBe('invalid_challenge')

    const c = await challenge(h)
    const good = await h.fakeApple.makeAttestation(c)
    const body = { keyId: good.keyId, attestation: good.attestation, challenge: c }
    expect((await h.request('/v1/devices', { body })).status).toBe(200)
    expect((await h.request('/v1/devices', { body })).status).toBe(400) // replay
  })

  it('rejects an invalid attestation with 403 attestation_failed', async () => {
    const h = await createHarness()
    const c = await challenge(h)
    const att = await h.fakeApple.makeAttestation('another-challenge')
    const res = await h.request('/v1/devices', { body: { keyId: att.keyId, attestation: att.attestation, challenge: c } })
    expect(res.status).toBe(403)
    expect((await json(res)).error.code).toBe('attestation_failed')
  })

  it('rejects malformed bodies', async () => {
    const h = await createHarness()
    expect((await h.request('/v1/devices', { body: { nope: true } })).status).toBe(400)
    expect((await h.request('/v1/devices', { body: { unattested: false } })).status).toBe(400)
  })
})

describe('POST /v1/auth/refresh', () => {
  async function attested(h: Awaited<ReturnType<typeof createHarness>>) {
    const c = await challenge(h)
    const att = await h.fakeApple.makeAttestation(c)
    const registered = await json(await h.request('/v1/devices', { body: { keyId: att.keyId, attestation: att.attestation, challenge: c } }))
    return { att, refreshToken: registered.refreshToken as string }
  }

  it('rotates tokens for an attested device with a valid assertion and persists the counter', async () => {
    const h = await createHarness()
    const { att, refreshToken } = await attested(h)
    const c = await challenge(h)
    const assertion = await h.fakeApple.makeAssertion(att.credKeys, `${c}:${refreshToken}`, 1)

    const res = await h.request('/v1/auth/refresh', { body: { refreshToken, challenge: c, assertion } })
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.refreshToken).not.toBe(refreshToken)
    const { deviceId } = await h.tokens.verifyAccess(body.accessToken)
    expect((await getDevice(h.db, deviceId))?.counter).toBe(1)

    // o refresh antigo não vale mais
    const c2 = await challenge(h)
    const again = await h.fakeApple.makeAssertion(att.credKeys, `${c2}:${refreshToken}`, 2)
    expect((await h.request('/v1/auth/refresh', { body: { refreshToken, challenge: c2, assertion: again } })).status).toBe(401)
  })

  it('rejects a replayed assertion (counter did not increase)', async () => {
    const h = await createHarness()
    const { att, refreshToken } = await attested(h)
    const c = await challenge(h)
    const assertion = await h.fakeApple.makeAssertion(att.credKeys, `${c}:${refreshToken}`, 1)
    const first = await json(await h.request('/v1/auth/refresh', { body: { refreshToken, challenge: c, assertion } }))

    const c2 = await challenge(h)
    const replay = await h.fakeApple.makeAssertion(att.credKeys, `${c2}:${first.refreshToken}`, 1)
    const res = await h.request('/v1/auth/refresh', { body: { refreshToken: first.refreshToken, challenge: c2, assertion: replay } })
    expect(res.status).toBe(403)
    expect((await json(res)).error.code).toBe('attestation_failed')
  })

  it('requires challenge and assertion for attested devices', async () => {
    const h = await createHarness()
    const { refreshToken } = await attested(h)
    const res = await h.request('/v1/auth/refresh', { body: { refreshToken } })
    expect(res.status).toBe(400)
  })

  it('rejects an assertion with a reused challenge', async () => {
    const h = await createHarness()
    const { att, refreshToken } = await attested(h)
    const c = await challenge(h)
    const assertion = await h.fakeApple.makeAssertion(att.credKeys, `${c}:${refreshToken}`, 1)
    await h.request('/v1/auth/refresh', { body: { refreshToken, challenge: c, assertion } })
    // mesma challenge de novo (com um refresh válido) deve falhar como invalid_challenge
    const second = await h.newDevice({ keyId: 'k', publicKey: 'p' })
    const res = await h.request('/v1/auth/refresh', { body: { refreshToken: second.refreshToken, challenge: c, assertion } })
    expect(res.status).toBe(400)
    expect((await json(res)).error.code).toBe('invalid_challenge')
  })

  it('renews an unattested device with just the refresh token', async () => {
    const h = await createHarness()
    const registered = await json(await h.request('/v1/devices', { body: { unattested: true } }))
    const res = await h.request('/v1/auth/refresh', { body: { refreshToken: registered.refreshToken } })
    expect(res.status).toBe(200)
    expect((await json(res)).refreshToken).not.toBe(registered.refreshToken)
  })

  it('rejects unknown and expired refresh tokens', async () => {
    const h = await createHarness()
    expect((await h.request('/v1/auth/refresh', { body: { refreshToken: 'nope' } })).status).toBe(401)
    const registered = await json(await h.request('/v1/devices', { body: { unattested: true } }))
    h.advance(61 * 24 * 3600 * 1000)
    expect((await h.request('/v1/auth/refresh', { body: { refreshToken: registered.refreshToken } })).status).toBe(401)
  })
})
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run test/publicAuth.test.ts 2>&1 | grep -E "FAIL|404|Tests " | head -4`
Expected: FAIL (rotas inexistentes → 404).

- [ ] **Step 3: Criar `backend/src/auth/session.ts`**

```ts
import type { Deps } from '../deps'

export type Session = { accessToken: string; expiresAt: number; refreshToken: string }

export async function issueSession(deps: Pick<Deps, 'tokens'>, deviceId: string): Promise<Session> {
  const { accessToken, expiresAt } = await deps.tokens.issueAccess(deviceId)
  const refreshToken = await deps.tokens.issueRefresh(deviceId)
  return { accessToken, expiresAt, refreshToken }
}
```

- [ ] **Step 4: Criar `backend/src/routes/publicAuth.ts`**

```ts
import { Hono } from 'hono'
import { z } from 'zod'
import { AttestationError } from '../auth/appAttest'
import { consumeChallenge, createChallenge } from '../auth/challenge'
import { issueSession } from '../auth/session'
import type { AppEnv } from '../context'
import { createDevice, getDevice, updateCounter } from '../db/devices'
import { ApiError } from '../lib/errors'

export const publicAuthRoutes = new Hono<AppEnv>()

publicAuthRoutes.post('/auth/challenge', async (c) => {
  const { db, now } = c.get('deps')
  return c.json({ challenge: await createChallenge(db, now()) })
})

const RegisterBody = z.union([
  z.object({ unattested: z.literal(true) }),
  z.object({ keyId: z.string().min(1), attestation: z.string().min(1), challenge: z.string().min(1) }),
])

publicAuthRoutes.post('/devices', async (c) => {
  const deps = c.get('deps')
  const parsed = RegisterBody.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) throw new ApiError('invalid_input', 'Invalid registration body', 400)
  const body = parsed.data

  const deviceId = crypto.randomUUID()
  const nowSec = Math.floor(deps.now() / 1000)

  if ('unattested' in body) {
    if (!deps.settings.allowUnattested) throw new ApiError('forbidden', 'Unattested devices are not allowed', 403)
    await createDevice(deps.db, { id: deviceId, keyId: null, publicKey: null, nowSec })
  } else {
    if (!(await consumeChallenge(deps.db, body.challenge, deps.now()))) {
      throw new ApiError('invalid_challenge', 'Unknown or expired challenge', 400)
    }
    let publicKeySpki: string
    try {
      ;({ publicKeySpki } = await deps.attest.verifyAttestation({
        attestation: body.attestation,
        keyId: body.keyId,
        challenge: body.challenge,
        appId: deps.settings.appId,
        allowedEnvs: deps.settings.attestEnvs,
        rootCaPem: deps.settings.rootCaPem,
        nowMs: deps.now(),
      }))
    } catch (err) {
      if (err instanceof AttestationError) throw new ApiError('attestation_failed', err.reason, 403)
      throw err
    }
    try {
      await createDevice(deps.db, { id: deviceId, keyId: body.keyId, publicKey: publicKeySpki, nowSec })
    } catch {
      throw new ApiError('attestation_failed', 'Key already registered', 403)
    }
  }

  return c.json(await issueSession(deps, deviceId))
})

const RefreshBody = z.object({
  refreshToken: z.string().min(1),
  challenge: z.string().min(1).optional(),
  assertion: z.string().min(1).optional(),
})

publicAuthRoutes.post('/auth/refresh', async (c) => {
  const deps = c.get('deps')
  const parsed = RefreshBody.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) throw new ApiError('invalid_input', 'Invalid refresh body', 400)
  const { refreshToken, challenge, assertion } = parsed.data

  const deviceId = await deps.tokens.deviceForRefresh(refreshToken)
  const device = deviceId ? await getDevice(deps.db, deviceId) : null
  if (!device) throw new ApiError('unauthorized', 'Invalid refresh token', 401)

  if (device.key_id && device.public_key) {
    if (!challenge || !assertion) throw new ApiError('invalid_input', 'An App Attest assertion is required', 400)
    if (!(await consumeChallenge(deps.db, challenge, deps.now()))) {
      throw new ApiError('invalid_challenge', 'Unknown or expired challenge', 400)
    }
    try {
      const { counter } = await deps.attest.verifyAssertion({
        assertion,
        clientData: `${challenge}:${refreshToken}`,
        publicKeySpki: device.public_key,
        storedCounter: device.counter,
        appId: deps.settings.appId,
      })
      await updateCounter(deps.db, device.id, counter)
    } catch (err) {
      if (err instanceof AttestationError) throw new ApiError('attestation_failed', err.reason, 403)
      throw err
    }
  }

  if (!(await deps.tokens.consumeRefresh(refreshToken))) throw new ApiError('unauthorized', 'Invalid refresh token', 401)
  return c.json(await issueSession(deps, device.id))
})
```

- [ ] **Step 5: Montar as rotas em `backend/src/app.ts`** — importar e substituir o comentário `// Rotas públicas de autenticação entram aqui (Task BE-7).`

```ts
import { publicAuthRoutes } from './routes/publicAuth'
```
```ts
  // Rotas públicas (sem token): desafio, registro de dispositivo e renovação.
  app.route('/v1', publicAuthRoutes)
```

- [ ] **Step 6: Rodar e ver passar**

Run: `npx vitest run 2>&1 | tail -6; npx tsc --noEmit 2>&1 | head -5`
Expected: toda a suíte PASS; `tsc` sem erros.

- [ ] **Step 7: Commit**

```bash
git add backend
git commit -m "feat(backend): add challenge, device registration and token refresh routes"
```

---

### Task BE-8: Rotas de conta — Sign in with Apple, logout, `/v1/me` e exclusão de conta

**Files:**
- Create: `backend/src/account.ts`, `backend/src/routes/account.ts`
- Modify: `backend/src/app.ts` (montar)
- Test: `backend/test/account.test.ts`

**Interfaces:**
- Consumes: `AppleClient` (BE-5), `consumeChallenge` (BE-3), repos de `users`/`devices`/`usage`/`entitlements` (BE-2/3), `quotaSnapshot` (BE-2), `sha256Hex` (BE-3), harness (BE-6)
- Produces:
  - `attachUserToDevice(db, deviceId, userId, nowMs): Promise<void>` (mescla uso do dia pelo maior valor, move entitlements do dispositivo para o usuário, vincula)
  - `deleteUserData(db, userId): Promise<void>`
  - `POST /v1/auth/apple` `{ identityToken, authorizationCode, challenge }` → `{ user: { id }, entitlements, quota }`
  - `POST /v1/auth/logout` → `{ ok: true }`
  - `GET /v1/me` → `{ user: { id } | null, entitlements: string[], quota }`
  - `DELETE /v1/me` → `{ ok: true }` (400 sem login; 502 `apple_unavailable` se a revogação falhar, sem apagar nada)

- [ ] **Step 1: Escrever os testes que falham — `backend/test/account.test.ts`**

```ts
import { describe, expect, it } from 'vitest'
import { grantEntitlement, UNLIMITED_SEARCH } from '../src/db/entitlements'
import { getUser } from '../src/db/users'
import { getUsage } from '../src/db/usage'
import { sha256Hex } from '../src/lib/crypto'
import { createHarness, json, T0 } from './helpers/appHarness'

type Harness = Awaited<ReturnType<typeof createHarness>>

async function login(h: Harness, token: string, sub: string, code = 'code-1') {
  const { challenge } = await json(await h.request('/v1/auth/challenge', { method: 'POST' }))
  const identityToken = `fake:${sub}:${await sha256Hex(challenge)}`
  return h.request('/v1/auth/apple', { body: { identityToken, authorizationCode: code, challenge }, token })
}

describe('POST /v1/auth/apple', () => {
  it('creates the user, links the device and keeps the Apple refresh token for revocation', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await login(h, d.accessToken, 'apple-sub-1')
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.user.id).toBeTruthy()
    expect((await getUser(h.db, body.user.id))?.apple_refresh_token).toBe('apple-refresh-code-1')
    const me = await json(await h.request('/v1/me', { token: d.accessToken }))
    expect(me.user.id).toBe(body.user.id)
  })

  it('reuses the same user when the same Apple account signs in on another device', async () => {
    const h = await createHarness()
    const a = await h.newDevice()
    const b = await h.newDevice()
    const first = await json(await login(h, a.accessToken, 'apple-sub-1'))
    const second = await json(await login(h, b.accessToken, 'apple-sub-1', 'code-2'))
    expect(second.user.id).toBe(first.user.id)
  })

  it('merges the day usage using the highest counter', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await h.db.run("INSERT INTO usage (owner_kind, owner_id, day, count) VALUES ('device', ?, '2026-10-05', 4)", [d.deviceId])
    const { user } = await json(await login(h, d.accessToken, 'apple-sub-1'))
    expect(await getUsage(h.db, 'user', user.id, '2026-10-05')).toBe(4)
    expect((await json(await h.request('/v1/me', { token: d.accessToken }))).quota.used).toBe(4)
  })

  it('moves device entitlements to the user so every device of the user has them', async () => {
    const h = await createHarness()
    const a = await h.newDevice()
    const b = await h.newDevice()
    await grantEntitlement(h.db, { id: 'e1', ownerKind: 'device', ownerId: a.deviceId, kind: UNLIMITED_SEARCH, expiresAt: T0 / 1000 + 3600 })
    await login(h, a.accessToken, 'apple-sub-1')
    await login(h, b.accessToken, 'apple-sub-1', 'code-2')
    const me = await json(await h.request('/v1/me', { token: b.accessToken }))
    expect(me.entitlements).toEqual([UNLIMITED_SEARCH])
    expect(me.quota.limit).toBe(100)
  })

  it('rejects an unknown challenge, a replayed challenge and a token with the wrong nonce', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const bogus = await h.request('/v1/auth/apple', { body: { identityToken: 'fake:s:n', authorizationCode: 'c', challenge: 'unknown' }, token: d.accessToken })
    expect(bogus.status).toBe(400)
    expect((await json(bogus)).error.code).toBe('invalid_challenge')

    const { challenge } = await json(await h.request('/v1/auth/challenge', { method: 'POST' }))
    const wrongNonce = await h.request('/v1/auth/apple', { body: { identityToken: 'fake:s:wrong', authorizationCode: 'c', challenge }, token: d.accessToken })
    expect(wrongNonce.status).toBe(401)
    expect((await json(wrongNonce)).error.code).toBe('apple_auth_failed')
    // o desafio foi consumido mesmo na falha: não pode ser reaproveitado
    const replay = await h.request('/v1/auth/apple', { body: { identityToken: `fake:s:${await sha256Hex(challenge)}`, authorizationCode: 'c', challenge }, token: d.accessToken })
    expect(replay.status).toBe(400)
  })

  it('requires authentication', async () => {
    const h = await createHarness()
    expect((await h.request('/v1/auth/apple', { body: { identityToken: 'x', authorizationCode: 'x', challenge: 'x' } })).status).toBe(401)
  })
})

describe('POST /v1/auth/logout', () => {
  it('unlinks the device; the Pro entitlement stays with the user', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await grantEntitlement(h.db, { id: 'e1', ownerKind: 'device', ownerId: d.deviceId, kind: UNLIMITED_SEARCH, expiresAt: T0 / 1000 + 3600 })
    await login(h, d.accessToken, 'apple-sub-1')

    expect((await h.request('/v1/auth/logout', { method: 'POST', token: d.accessToken })).status).toBe(200)
    const me = await json(await h.request('/v1/me', { token: d.accessToken }))
    expect(me.user).toBeNull()
    expect(me.entitlements).toEqual([])
    expect(me.quota.limit).toBe(5)
  })
})

describe('GET /v1/me', () => {
  it('returns the anonymous profile with the free quota', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    expect(await json(await h.request('/v1/me', { token: d.accessToken }))).toEqual({
      user: null,
      entitlements: [],
      quota: { used: 0, limit: 5, resetsAt: '2026-10-06T00:00:00Z' },
    })
  })
})

describe('DELETE /v1/me', () => {
  it('revokes the Apple token and removes the user and its data', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const { user } = await json(await login(h, d.accessToken, 'apple-sub-1'))
    await grantEntitlement(h.db, { id: 'e1', ownerKind: 'user', ownerId: user.id, kind: UNLIMITED_SEARCH, expiresAt: T0 / 1000 + 3600 })

    const res = await h.request('/v1/me', { method: 'DELETE', token: d.accessToken })
    expect(res.status).toBe(200)
    expect(h.revoked).toEqual(['apple-refresh-code-1'])
    expect(await getUser(h.db, user.id)).toBeNull()
    expect(await h.db.all('SELECT * FROM entitlements WHERE owner_id = ?', [user.id])).toHaveLength(0)
    const me = await json(await h.request('/v1/me', { token: d.accessToken }))
    expect(me.user).toBeNull()
  })

  it('does nothing and answers 502 when Apple cannot revoke, so the person can retry', async () => {
    const h = await createHarness({ failRevoke: true })
    const d = await h.newDevice()
    const { user } = await json(await login(h, d.accessToken, 'apple-sub-1'))
    const res = await h.request('/v1/me', { method: 'DELETE', token: d.accessToken })
    expect(res.status).toBe(502)
    expect((await json(res)).error.code).toBe('apple_unavailable')
    expect(await getUser(h.db, user.id)).not.toBeNull()
  })

  it('rejects anonymous devices', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await h.request('/v1/me', { method: 'DELETE', token: d.accessToken })
    expect(res.status).toBe(400)
  })
})
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npx vitest run test/account.test.ts 2>&1 | grep -E "FAIL|Tests " | head -3`
Expected: FAIL (rotas inexistentes).

- [ ] **Step 3: Criar `backend/src/account.ts`**

```ts
import { moveDeviceEntitlementsToUser } from './db/entitlements'
import { linkDeviceToUser } from './db/devices'
import { getUsage, raiseUsageTo } from './db/usage'
import type { Db } from './lib/db'
import { dayKey } from './quota'

/** Vincula o dispositivo ao usuário, mesclando a cota do dia (maior valor) e as entitlements. */
export async function attachUserToDevice(db: Db, deviceId: string, userId: string, nowMs: number): Promise<void> {
  const day = dayKey(nowMs)
  const deviceCount = await getUsage(db, 'device', deviceId, day)
  const userCount = await getUsage(db, 'user', userId, day)
  await raiseUsageTo(db, 'user', userId, day, deviceCount)
  await raiseUsageTo(db, 'device', deviceId, day, userCount)
  await moveDeviceEntitlementsToUser(db, deviceId, userId)
  await linkDeviceToUser(db, deviceId, userId)
}

/** Remove o usuário e tudo que pertence só a ele; o uso dos dispositivos permanece (anti-abuso). */
export async function deleteUserData(db: Db, userId: string): Promise<void> {
  await db.batch([
    { sql: "DELETE FROM entitlements WHERE owner_kind = 'user' AND owner_id = ?", params: [userId] },
    { sql: "DELETE FROM usage WHERE owner_kind = 'user' AND owner_id = ?", params: [userId] },
    { sql: 'UPDATE devices SET user_id = NULL WHERE user_id = ?', params: [userId] },
    { sql: 'DELETE FROM users WHERE id = ?', params: [userId] },
  ])
}
```

- [ ] **Step 4: Criar `backend/src/routes/account.ts`**

```ts
import { Hono } from 'hono'
import { z } from 'zod'
import { attachUserToDevice, deleteUserData } from '../account'
import { AppleAuthError } from '../auth/apple'
import { consumeChallenge } from '../auth/challenge'
import type { AppEnv } from '../context'
import { linkDeviceToUser } from '../db/devices'
import { listActiveEntitlements } from '../db/entitlements'
import { getUser, upsertUserByAppleSub } from '../db/users'
import { loadConfig } from '../config'
import { sha256Hex } from '../lib/crypto'
import { ApiError } from '../lib/errors'
import { ownersOf, quotaSnapshot } from '../quota'

export const accountRoutes = new Hono<AppEnv>()

async function profile(c: import('hono').Context<AppEnv>) {
  const deps = c.get('deps')
  const identity = c.get('identity')
  const config = await loadConfig(deps.config)
  return {
    user: identity.userId ? { id: identity.userId } : null,
    entitlements: await listActiveEntitlements(deps.db, ownersOf(identity), Math.floor(deps.now() / 1000)),
    quota: await quotaSnapshot(deps.db, config, identity, deps.now()),
  }
}

const AppleBody = z.object({
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1),
  challenge: z.string().min(1),
})

accountRoutes.post('/auth/apple', async (c) => {
  const deps = c.get('deps')
  const identity = c.get('identity')
  const parsed = AppleBody.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) throw new ApiError('invalid_input', 'Invalid sign-in body', 400)
  const { identityToken, authorizationCode, challenge } = parsed.data

  // O desafio é consumido antes de validar: uma tentativa falha não pode ser repetida.
  if (!(await consumeChallenge(deps.db, challenge, deps.now()))) {
    throw new ApiError('invalid_challenge', 'Unknown or expired challenge', 400)
  }

  let sub: string
  let appleRefreshToken: string
  try {
    ;({ sub } = await deps.apple.verifyIdentityToken(identityToken, await sha256Hex(challenge)))
    ;({ refreshToken: appleRefreshToken } = await deps.apple.exchangeCode(authorizationCode))
  } catch (err) {
    if (err instanceof AppleAuthError) throw new ApiError('apple_auth_failed', 'Apple sign-in failed', 401)
    throw err
  }

  const user = await upsertUserByAppleSub(deps.db, {
    sub,
    appleRefreshToken,
    nowSec: Math.floor(deps.now() / 1000),
    newId: crypto.randomUUID(),
  })
  await attachUserToDevice(deps.db, identity.deviceId, user.id, deps.now())

  c.set('identity', { deviceId: identity.deviceId, userId: user.id })
  return c.json(await profile(c))
})

accountRoutes.post('/auth/logout', async (c) => {
  const { db } = c.get('deps')
  await linkDeviceToUser(db, c.get('identity').deviceId, null)
  return c.json({ ok: true })
})

accountRoutes.get('/me', async (c) => c.json(await profile(c)))

accountRoutes.delete('/me', async (c) => {
  const deps = c.get('deps')
  const { userId } = c.get('identity')
  if (!userId) throw new ApiError('invalid_input', 'Not signed in', 400)

  const user = await getUser(deps.db, userId)
  if (user?.apple_refresh_token) {
    try {
      await deps.apple.revoke(user.apple_refresh_token)
    } catch (err) {
      if (err instanceof AppleAuthError) {
        throw new ApiError('apple_unavailable', 'Could not revoke the Apple credential; try again', 502)
      }
      throw err
    }
  }
  await deleteUserData(deps.db, userId)
  return c.json({ ok: true })
})
```

- [ ] **Step 5: Montar as rotas em `backend/src/app.ts`** — importar e substituir o comentário `// Rotas de conta entram aqui (Task BE-8).`

```ts
import { accountRoutes } from './routes/account'
```
```ts
  authed.route('/', accountRoutes)
```

- [ ] **Step 6: Rodar e ver passar**

Run: `npx vitest run 2>&1 | tail -6; npx tsc --noEmit 2>&1 | head -5`
Expected: toda a suíte PASS; `tsc` sem erros. Se o `tsc` reclamar do tipo `import('hono').Context<AppEnv>` em `profile`, importe `type Context` no topo (`import { Hono, type Context } from 'hono'`) e use `Context<AppEnv>`.

- [ ] **Step 7: Commit**

```bash
git add backend
git commit -m "feat(backend): add Sign in with Apple, logout, profile and account deletion routes"
```

---

### Task BE-9: Publicar em `dev` (D1, segredos, smoke) e checklist do aparelho

Esta tarefa usa contas reais; as etapas marcadas **[USUÁRIO]** dependem do portal da Apple e do `wrangler login`.

**Files:**
- Modify: `backend/wrangler.jsonc`, `backend/scripts/smoke.ts`, `backend/README.md`, `backend/.dev.vars.example`

**Interfaces:**
- Produces: Worker `filmfinder-api-dev` com D1 `filmfinder-dev`, segredos `JWT_SECRET` e `APPLE_PRIVATE_KEY`, variáveis `APPLE_TEAM_ID`/`APPLE_KEY_ID` preenchidas e `x-dev-key` desligado.

- [ ] **Step 1: [USUÁRIO] Reunir dados da Apple**

No portal de desenvolvedor (developer.apple.com → Certificates, Identifiers & Profiles):
1. **Team ID:** em Membership details (10 caracteres).
2. **Identifiers → App IDs → `com.andre.filmfinder`:** se não existir, criar com esse bundle id; marcar a capability **Sign in with Apple** (configurar como *primary App ID*).
3. **Keys → +:** nome `FilmFinder SIWA`, marcar **Sign in with Apple** → *Configure* → escolher o App ID acima → Continue → Register → **Download** do arquivo `AuthKey_XXXXXXXXXX.p8` (só baixa uma vez) e anotar o **Key ID** (10 caracteres).
Informar ao Claude: o Team ID, o Key ID e o **caminho local** do `.p8` (não colar o conteúdo no chat).

- [ ] **Step 2: Criar o D1 de `dev`**

Run (em `backend/`): `npx wrangler d1 create filmfinder-dev 2>&1 | grep -iE "database_id|Successfully|ERROR"`
Expected: imprime `database_id = "<uuid>"`. Gravar o uuid em `backend/wrangler.jsonc`, em `env.dev.d1_databases[0].database_id` (substituindo `"local"`).

- [ ] **Step 3: Preencher as variáveis de `dev` em `backend/wrangler.jsonc`** (`env.dev.vars.APPLE_TEAM_ID` e `APPLE_KEY_ID` com os valores do Step 1; o bundle id já está preenchido).

- [ ] **Step 4: Aplicar as migrações no D1 remoto de `dev`**

Run: `npx wrangler d1 migrations apply DB --env dev --remote 2>&1 | grep -iE "applied|success|ERROR|✘" | head -5`
Expected: migração `0001_init.sql` aplicada.

- [ ] **Step 5: Segredos de `dev`** (sem imprimir valores; ajuste `P8` para o caminho informado)

```bash
P8="/caminho/informado/AuthKey_XXXXXXXXXX.p8"
bash -c 'openssl rand -base64 48 | tr -d "\n" | npx wrangler secret put JWT_SECRET --env dev 2>&1 | grep -E "Success|ERROR"'
bash -c "npx wrangler secret put APPLE_PRIVATE_KEY --env dev < \"$P8\" 2>&1 | grep -E 'Success|ERROR'"
```
Expected: `Success! Uploaded secret JWT_SECRET` e `... APPLE_PRIVATE_KEY`. Depois remover o segredo antigo: `npx wrangler secret delete DEV_API_KEY --env dev`.

- [ ] **Step 6: Atualizar o smoke — substituir `backend/scripts/smoke.ts`** (agora cada pedido usa um dispositivo novo registrado sem atestação, para não esbarrar na cota diária)

```ts
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'

type Prompt = { query: string; mediaType: 'movie' | 'tv'; locale: string; region: string }
type Row = { provider: string; query: string; status: number; latencyMs: number; titles: number; top3: string[]; withStreaming: number }

const baseUrl = process.env.SMOKE_URL ?? 'http://localhost:8787'
const prompts = JSON.parse(readFileSync(new URL('./smoke-prompts.json', import.meta.url), 'utf8')) as Prompt[]
const providers = (process.env.SMOKE_PROVIDERS ?? 'gemini,anthropic').split(',')
const rows: Row[] = []

/** Registra um dispositivo novo (só funciona no `dev`, com ALLOW_UNATTESTED=true). */
async function newAccessToken(): Promise<string> {
  const res = await fetch(`${baseUrl}/v1/devices`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ unattested: true }),
  })
  if (!res.ok) throw new Error(`device registration failed: ${res.status}`)
  return ((await res.json()) as { accessToken: string }).accessToken
}

for (const provider of providers) {
  for (const p of prompts) {
    const token = await newAccessToken()
    const started = Date.now()
    const res = await fetch(`${baseUrl}/v1/recommendations`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}`, 'x-ai-provider': provider },
      body: JSON.stringify(p),
    })
    const body = (await res.json()) as { titles?: { title: string; year: number | null; providers: { flatrate: unknown[] } }[] }
    const titles = body.titles ?? []
    rows.push({
      provider,
      query: p.query,
      status: res.status,
      latencyMs: Date.now() - started,
      titles: titles.length,
      top3: titles.slice(0, 3).map((t) => `${t.title} (${t.year ?? '?'})`),
      withStreaming: titles.filter((t) => t.providers.flatrate.length > 0).length,
    })
    console.log(provider.padEnd(9), String(res.status), `${Date.now() - started}ms`.padStart(7), `${titles.length} títulos`, '|', p.query)
  }
}

for (const provider of providers) {
  const mine = rows.filter((r) => r.provider === provider)
  const ok = mine.filter((r) => r.status === 200)
  const avg = (xs: number[]) => Math.round(xs.reduce((a, b) => a + b, 0) / Math.max(xs.length, 1))
  const sorted = ok.map((r) => r.latencyMs).sort((a, b) => a - b)
  console.log(
    `\n${provider}: ok ${ok.length}/${mine.length}, títulos médios ${avg(ok.map((r) => r.titles))}, ` +
      `latência média ${avg(sorted)}ms, p90 ${sorted[Math.floor(sorted.length * 0.9)] ?? 0}ms`,
  )
}

mkdirSync(new URL('./out/', import.meta.url), { recursive: true })
const out = new URL(`./out/smoke-${Date.now()}.json`, import.meta.url)
writeFileSync(out, JSON.stringify(rows, null, 2))
console.log(`\nRelatório: ${out.pathname}`)
```

- [ ] **Step 7: Atualizar `.dev.vars.example`** (o `.dev.vars` local só serve para `wrangler dev`; o smoke contra `dev` não precisa de nenhuma chave)

```
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GEMINI_API_KEY=
TMDB_TOKEN=
CF_ACCOUNT_ID=
CF_AIG_TOKEN=
JWT_SECRET=
APPLE_PRIVATE_KEY=
```

- [ ] **Step 8: Rodar a suíte e publicar**

Run: `npx vitest run 2>&1 | tail -3; npx tsc --noEmit 2>&1 | head -3; npm run deploy:dev 2>&1 | grep -E "ERROR|Deployed|Current Version"`
Expected: testes PASS, `tsc` limpo, `Deployed filmfinder-api-dev`.

- [ ] **Step 9: Verificar o ciclo de identidade ponta a ponta contra `dev`**

Run:
```bash
U=https://filmfinder-api-dev.andrefw483.workers.dev
R=$(curl -s -X POST $U/v1/devices -H 'content-type: application/json' -d '{"unattested":true}'); echo "$R" | python3 -c "import sys,json; d=json.load(sys.stdin); print('registro ok:', sorted(d))"
T=$(echo "$R" | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")
curl -s $U/v1/me -H "authorization: Bearer $T"; echo
curl -s -o /dev/null -w "sem token: HTTP %{http_code}\n" $U/v1/me
curl -s -X POST $U/v1/recommendations -H "authorization: Bearer $T" -H 'content-type: application/json' -d '{"query":"comédia leve","mediaType":"movie","locale":"pt-BR","region":"BR"}' | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['titles']),'titulos | quota', d['quota'])"
curl -s -o /dev/null -w "x-dev-key antigo: HTTP %{http_code}\n" -X POST $U/v1/recommendations -H 'x-dev-key: qualquer' -H 'content-type: application/json' -d '{"query":"x","mediaType":"movie"}'
```
Expected: `registro ok: ['accessToken', 'expiresAt', 'refreshToken']`; `/v1/me` com `quota.used` 0 e `limit` 5; `sem token: HTTP 401`; 12 títulos e `quota.used` 1; `x-dev-key antigo: HTTP 401`.

- [ ] **Step 10: Smoke completo contra `dev`**

Run: `SMOKE_URL=https://filmfinder-api-dev.andrefw483.workers.dev npm run smoke 2>&1 | tail -6`
Expected: `gemini: ok 19/20 ou 20/20` e `anthropic: ok 20/20` (latências parecidas com as da Fatia 1).

- [ ] **Step 11: Documentar no `backend/README.md`** — substituir a seção "Endpoints (Fatia 1)" por:

```markdown
## Endpoints

Públicos: `GET /health`, `POST /v1/auth/challenge`, `POST /v1/devices`, `POST /v1/auth/refresh`.
Autenticados (`Authorization: Bearer <accessToken>`): `POST /v1/recommendations`, `GET /v1/me`, `DELETE /v1/me`,
`POST /v1/auth/apple`, `POST /v1/auth/logout`.

Sessão: `POST /v1/devices` devolve `{ accessToken, expiresAt, refreshToken }` (acesso de 15 min; refresh de 60 dias, rotativo).
No ambiente `dev` (`ALLOW_UNATTESTED=true`) aceita `{ "unattested": true }`; em produção exige App Attest
(`{ keyId, attestation, challenge }`). `x-ai-provider` só vale com `ALLOW_PROVIDER_OVERRIDE=true`.

Cota: 5 buscas/dia grátis, 100/dia com a entitlement `unlimited_search` (KV `limits.free.daily`, `limits.pro.daily`).
Erros: `{ "error": { "code", "message" } }`; cota esgotada = HTTP 402 `quota_exceeded`.
```

- [ ] **Step 12: Commit**

```bash
git add backend
git commit -m "feat(backend): publish identity and quota to dev (D1, secrets, smoke against bearer auth)"
```

- [ ] **Step 13: Checklist para validar App Attest e Sign in with Apple em iPhone real** (executado pelo usuário na Task iOS-14; registrar aqui o que for ajustado)

1. Registro atestado: abrir o app no iPhone e fazer uma busca; no Worker, `wrangler tail --env dev` deve mostrar o `POST /v1/devices` com 200 (e **não** `attestation_failed`). Se aparecer `attestation_failed`, o campo `message` traz o motivo exato (`nonce does not match challenge`, `rpIdHash does not match appId`, `aaguid does not match an allowed environment`, ...): ajustar `APPLE_TEAM_ID`/`APPATTEST_ENVS` ou o verificador conforme o motivo.
2. Renovação: esperar 15 min (ou forçar expiração) e buscar de novo; deve haver `POST /v1/auth/refresh` com 200.
3. Sign in with Apple: logar em Ajustes; `POST /v1/auth/apple` com 200 e `GET /v1/me` com `user.id`.
4. Excluir conta em Ajustes: `DELETE /v1/me` com 200 e o app volta ao estado anônimo.
5. Produção (Fatia 5): `APPATTEST_ENVS=production` e `ALLOW_UNATTESTED=false`.

---

# PARTE B — App iOS

### Task iOS-1: Ferramentas, configuração do projeto, capabilities e linha de base

**Files:**
- Modify: `project.yml`, `.gitignore`, `FilmFinder/Info.plist`
- Create: `Config/Debug.xcconfig`, `Config/Release.xcconfig`, `Config/Local.xcconfig` (gitignored), `FilmFinder/FilmFinder.entitlements`
- Create: `FilmFinder/Secrets.swift` (temporário, gitignored; removido na Task iOS-14)
- Create: `FilmFinderTests/SmokeTests.swift`

**Interfaces:**
- Produces: esquema `FilmFinder` com alvo de testes `FilmFinderTests` (Swift Testing); chaves de Info.plist `APIBaseURL`, `PrivacyPolicyURL`, `TermsURL`; entitlements de Sign in with Apple e App Attest; `FilmFinder.xcodeproj` gerável por `xcodegen generate`.

- [ ] **Step 1: Instalar o XcodeGen**

Run: `brew install xcodegen && xcodegen --version`
Expected: imprime uma versão (ex.: `Version: 2.46.0`).

- [ ] **Step 2: Substituir `project.yml`**

```yaml
name: FilmFinder
options:
  bundleIdPrefix: com.andre
  deploymentTarget:
    iOS: '18.0'

configFiles:
  Debug: Config/Debug.xcconfig
  Release: Config/Release.xcconfig

settings:
  base:
    IPHONEOS_DEPLOYMENT_TARGET: '18.0'
    SWIFT_VERSION: '5.0'

packages:
  Lottie:
    url: 'https://github.com/airbnb/lottie-ios.git'
    from: '4.2.0'

targets:
  FilmFinder:
    type: application
    platform: iOS
    settings:
      base:
        INFO_PLIST_FILE: 'FilmFinder/Info.plist'
        PRODUCT_BUNDLE_IDENTIFIER: 'com.andre.filmfinder'
        CODE_SIGN_ENTITLEMENTS: 'FilmFinder/FilmFinder.entitlements'
        CODE_SIGN_STYLE: Automatic
    sources:
      - path: 'FilmFinder'
    dependencies:
      - package: Lottie
  FilmFinderTests:
    type: bundle.unit-test
    platform: iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: 'com.andre.filmfinder.tests'
        GENERATE_INFOPLIST_FILE: YES
    sources:
      - path: 'FilmFinderTests'
    dependencies:
      - target: FilmFinder

schemes:
  FilmFinder:
    build:
      targets:
        FilmFinder: all
        FilmFinderTests: [test]
    test:
      targets:
        - FilmFinderTests
```

- [ ] **Step 3: Criar o arquivo de entitlements `FilmFinder/FilmFinder.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
	<key>com.apple.developer.devicecheck.appattest-environment</key>
	<string>$(APP_ATTEST_ENVIRONMENT)</string>
</dict>
</plist>
```

- [ ] **Step 4: Criar os `.xcconfig`**

`Config/Debug.xcconfig`:
```
// "/$()/" evita que o "//" da URL seja lido como comentário.
API_BASE_URL = https:/$()/filmfinder-api-dev.andrefw483.workers.dev
APP_ATTEST_ENVIRONMENT = development
PRIVACY_POLICY_URL =
TERMS_URL =
#include? "Local.xcconfig"
```

`Config/Release.xcconfig`:
```
// A Fatia 5 troca pela URL de produção.
API_BASE_URL = https:/$()/filmfinder-api-dev.andrefw483.workers.dev
APP_ATTEST_ENVIRONMENT = production
PRIVACY_POLICY_URL =
TERMS_URL =
#include? "Local.xcconfig"
```

- [ ] **Step 5: [USUÁRIO] Criar `Config/Local.xcconfig` com o seu Team ID** (o mesmo informado na Task BE-9; não é segredo, mas é pessoal e por isso fica fora do git)

Run (troque `ABCDE12345` pelo Team ID real de 10 caracteres):
```bash
printf 'DEVELOPMENT_TEAM = ABCDE12345\n' > Config/Local.xcconfig
```

- [ ] **Step 6: Ignorar o arquivo local — acrescentar ao `.gitignore`**

```
# App iOS
Config/Local.xcconfig
```
Verificar: `git check-ignore Config/Local.xcconfig FilmFinder/Secrets.swift` imprime os dois caminhos.

- [ ] **Step 7: Acrescentar as chaves ao `FilmFinder/Info.plist`** (dentro do `<dict>` raiz, antes do `</dict>` final)

```xml
	<key>APIBaseURL</key>
	<string>$(API_BASE_URL)</string>
	<key>PrivacyPolicyURL</key>
	<string>$(PRIVACY_POLICY_URL)</string>
	<key>TermsURL</key>
	<string>$(TERMS_URL)</string>
```

- [ ] **Step 8: Criar o `Secrets.swift` temporário** (o código legado ainda referencia `Secrets`; o arquivo é gitignored e some na Task iOS-14)

```swift
// Temporário: mantém o código legado compilando até a Task iOS-14. Está no .gitignore.
enum Secrets {
    static let CHATGPT_API_KEY = ""
    static let TMDB_API_KEY = ""
}
```

- [ ] **Step 9: Criar o teste de fumaça `FilmFinderTests/SmokeTests.swift`**

```swift
import Testing
@testable import FilmFinder

@Suite struct SmokeTests {
    @Test func runnerWorks() {
        #expect(1 + 1 == 2)
    }
}
```

- [ ] **Step 10: Gerar o projeto e compilar a linha de base**

Run:
```bash
xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | tail -30
```
Expected: sem `error:` (avisos do código legado são aceitáveis). Se aparecer erro **do código legado** causado só por iOS 18/Xcode novo, corrija o mínimo necessário nesse arquivo; não refatore nada ainda. Se o erro for de assinatura/entitlements (`requires a provisioning profile`) no build de **simulador**, confirme que `DEVELOPMENT_TEAM` está em `Config/Local.xcconfig` e que o destino é o simulador; para builds em aparelho a assinatura automática precisa do Team e das capabilities ativas no portal.

- [ ] **Step 11: Rodar o teste de fumaça**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/SmokeTests 2>&1 | tail -15`
Expected: `Test run with 1 test ... passed`.

- [ ] **Step 12: Confirmar os valores injetados e os entitlements no app compilado**

Run:
```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug-iphonesimulator/FilmFinder.app' -maxdepth 6 | head -1)
/usr/libexec/PlistBuddy -c 'Print :APIBaseURL' "$APP/Info.plist"
codesign -d --entitlements - "$APP" 2>&1 | grep -E "applesignin|appattest" | head -4
```
Expected: `https://filmfinder-api-dev.andrefw483.workers.dev` e linhas com `com.apple.developer.applesignin` e `com.apple.developer.devicecheck.appattest-environment`. (Em build de simulador os entitlements podem aparecer só no `.xcent`; se `codesign` não mostrar, conferir `find ~/Library/Developer/Xcode/DerivedData -name 'FilmFinder.app.xcent' | head -1 | xargs cat`.)

- [ ] **Step 13: Commit**

```bash
git add project.yml .gitignore Config/Debug.xcconfig Config/Release.xcconfig FilmFinder/Info.plist FilmFinder/FilmFinder.entitlements FilmFinderTests
git commit -m "build(ios): target iOS 18, add test target, entitlements and xcconfig-based API config"
```

### Task iOS-2: Domínio — `MediaType`, `Title`, imagens e idioma

**Files:**
- Create: `FilmFinder/Domain/MediaType.swift`, `Title.swift`, `Recommendation.swift`, `TMDBImage.swift`, `LocaleInfo.swift`
- Create: `FilmFinderTests/Support/TestSupport.swift`, `FilmFinderTests/Fixtures/recommendations.json`
- Test: `FilmFinderTests/TitleTests.swift`

**Interfaces:**
- Produces:
  - `enum MediaType: String, Codable, CaseIterable, Sendable { case movie, tv }`
  - `struct StreamingProvider { id: Int; name: String; logoPath: String }`
  - `struct Providers { region: String; link: URL?; flatrate, rent, buy, free: [StreamingProvider]; static func empty(region:) -> Providers; var isEmpty: Bool; func highlighted(limit: Int = 3) -> [StreamingProvider] }`
  - `struct Title: Codable, Hashable, Sendable, Identifiable` com `id` = `"movie-123"`, `static func stars(for rating: Double) -> Int`, `var stars: Int`
  - `struct RecommendationRequest: Encodable, Sendable { query: String; mediaType: MediaType; excludeTmdbIds: [Int]; locale: String; region: String }`
  - `struct Quota: Decodable, Equatable, Sendable { used: Int; limit: Int; resetsAt: Date; var remaining: Int }` e `extension JSONDecoder { static var api: JSONDecoder }` (datas ISO 8601)
  - `struct RecommendationsResponse: Decodable, Sendable { let titles: [Title]; let quota: Quota? }`
  - `enum TMDBImage { static func poster(_:), backdrop(_:), logo(_:) -> URL? }` (aceitam `String?`)
  - `struct LocaleInfo: Equatable, Sendable { locale: String; region: String; init(_ locale: Locale = .current) }`
  - Teste: `fixtureData(_ name: String) throws -> Data`, `Title.sample(id:type:title:providers:)`

- [ ] **Step 1: Criar a fixture `FilmFinderTests/Fixtures/recommendations.json`** (contrato do backend, escrito à mão)

```json
{
  "titles": [
    {
      "tmdbId": 157336,
      "mediaType": "movie",
      "title": "Interestelar",
      "originalTitle": "Interstellar",
      "year": 2014,
      "overview": "As reservas naturais da Terra estão chegando ao fim.",
      "posterPath": "/poster.jpg",
      "backdropPath": "/backdrop.jpg",
      "rating": 8.5,
      "runtimeMinutes": 169,
      "seasons": null,
      "genres": ["Aventura", "Ficção científica"],
      "reason": "Uma jornada espacial emocionante sobre o tempo.",
      "providers": {
        "region": "BR",
        "link": "https://www.themoviedb.org/movie/157336/watch?locale=BR",
        "flatrate": [
          { "id": 119, "name": "Amazon Prime Video", "logoPath": "/prime.jpg" },
          { "id": 384, "name": "Max", "logoPath": "/max.jpg" }
        ],
        "rent": [{ "id": 2, "name": "Apple TV", "logoPath": "/apple.jpg" }],
        "buy": [],
        "free": [{ "id": 73, "name": "Tubi", "logoPath": "/tubi.jpg" }]
      }
    },
    {
      "tmdbId": 70523,
      "mediaType": "tv",
      "title": "Dark",
      "originalTitle": "Dark",
      "year": 2017,
      "overview": "Uma criança desaparece.",
      "posterPath": null,
      "backdropPath": null,
      "rating": 8.4,
      "runtimeMinutes": null,
      "seasons": 3,
      "genres": ["Drama"],
      "reason": "Mistério denso com viagem no tempo.",
      "providers": { "region": "BR", "link": null, "flatrate": [], "rent": [], "buy": [], "free": [] }
    }
  ],
  "quota": { "used": 1, "limit": 5, "resetsAt": "2026-10-06T00:00:00Z" }
}
```

- [ ] **Step 2: Criar `FilmFinderTests/Support/TestSupport.swift`**

```swift
import Foundation
@testable import FilmFinder

private final class BundleToken {}

func fixtureData(_ name: String) throws -> Data {
    guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}

extension Title {
    static func sample(
        id: Int = 1,
        type: MediaType = .movie,
        title: String = "Sample",
        providers: Providers? = nil
    ) -> Title {
        Title(
            tmdbId: id, mediaType: type, title: title, originalTitle: title, year: 2020,
            overview: "Overview", posterPath: "/p.jpg", backdropPath: nil, rating: 7.5,
            runtimeMinutes: type == .movie ? 120 : nil, seasons: type == .tv ? 2 : nil,
            genres: ["Drama"], reason: "Because.", providers: providers ?? .empty(region: "BR")
        )
    }
}
```

- [ ] **Step 3: Escrever os testes que falham — `FilmFinderTests/TitleTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

@Suite struct TitleTests {
    @Test func decodesBackendContract() throws {
        let response = try JSONDecoder.api.decode(RecommendationsResponse.self, from: fixtureData("recommendations"))
        #expect(response.titles.count == 2)
        let quota = try #require(response.quota)
        #expect(quota.used == 1)
        #expect(quota.limit == 5)
        #expect(quota.remaining == 4)
        #expect(quota.resetsAt == Date(timeIntervalSince1970: 1_791_244_800))

        let movie = response.titles[0]
        #expect(movie.id == "movie-157336")
        #expect(movie.mediaType == .movie)
        #expect(movie.originalTitle == "Interstellar")
        #expect(movie.year == 2014)
        #expect(movie.runtimeMinutes == 169)
        #expect(movie.seasons == nil)
        #expect(movie.genres == ["Aventura", "Ficção científica"])
        #expect(movie.providers.region == "BR")
        #expect(movie.providers.link?.absoluteString == "https://www.themoviedb.org/movie/157336/watch?locale=BR")
        #expect(movie.providers.flatrate.map(\.name) == ["Amazon Prime Video", "Max"])
        #expect(movie.providers.free.map(\.name) == ["Tubi"])

        let show = response.titles[1]
        #expect(show.id == "tv-70523")
        #expect(show.posterPath == nil)
        #expect(show.seasons == 3)
        #expect(show.providers.link == nil)
        #expect(show.providers.isEmpty)
    }

    @Test func quotaIsOptionalAndRemainingNeverGoesNegative() throws {
        let response = try JSONDecoder.api.decode(RecommendationsResponse.self, from: Data(#"{"titles":[],"quota":null}"#.utf8))
        #expect(response.titles.isEmpty)
        #expect(response.quota == nil)
        #expect(Quota(used: 7, limit: 5, resetsAt: .now).remaining == 0)
    }

    @Test func titleSurvivesJSONRoundTrip() throws {
        let original = Title.sample(id: 9, type: .tv)
        let decoded = try JSONDecoder().decode(Title.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func starsAreRoundedAndClamped() {
        #expect(Title.stars(for: 0) == 0)
        #expect(Title.stars(for: 7.571) == 4)
        #expect(Title.stars(for: 9.0) == 5)
        #expect(Title.stars(for: 10) == 5)
        #expect(Title.stars(for: 11) == 5)
        #expect(Title.stars(for: -1) == 0)
    }

    @Test func highlightedPrefersSubscriptionThenFree() throws {
        let response = try JSONDecoder.api.decode(RecommendationsResponse.self, from: fixtureData("recommendations"))
        #expect(response.titles[0].providers.highlighted(limit: 1).map(\.name) == ["Amazon Prime Video"])
        #expect(response.titles[0].providers.highlighted().count == 2)

        var onlyFree = response.titles[0].providers
        onlyFree.flatrate = []
        #expect(onlyFree.highlighted().map(\.name) == ["Tubi"])
        #expect(response.titles[1].providers.highlighted().isEmpty)
    }

    @Test func requestEncodesBackendFieldNames() throws {
        let request = RecommendationRequest(
            query: "algo leve", mediaType: .tv, excludeTmdbIds: [1, 2], locale: "pt-BR", region: "BR"
        )
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(json["query"] as? String == "algo leve")
        #expect(json["mediaType"] as? String == "tv")
        #expect(json["excludeTmdbIds"] as? [Int] == [1, 2])
        #expect(json["locale"] as? String == "pt-BR")
        #expect(json["region"] as? String == "BR")
    }
}

@Suite struct TMDBImageTests {
    @Test func buildsSizedURLs() {
        #expect(TMDBImage.poster("/a.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w500/a.jpg")
        #expect(TMDBImage.backdrop("/b.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w780/b.jpg")
        #expect(TMDBImage.logo("/c.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w92/c.jpg")
    }

    @Test func rejectsMissingOrMalformedPaths() {
        #expect(TMDBImage.poster(nil) == nil)
        #expect(TMDBImage.poster("") == nil)
        #expect(TMDBImage.poster("a.jpg") == nil)
    }
}

@Suite struct LocaleInfoTests {
    @Test func usesLanguageAndRegion() {
        #expect(LocaleInfo(Locale(identifier: "pt_BR")) == LocaleInfo(locale: "pt-BR", region: "BR"))
        #expect(LocaleInfo(Locale(identifier: "en_GB")) == LocaleInfo(locale: "en-GB", region: "GB"))
    }

    @Test func fallsBackWhenRegionIsMissingOrNotTwoLetters() {
        #expect(LocaleInfo(Locale(identifier: "en")) == LocaleInfo(locale: "en-US", region: "US"))
        #expect(LocaleInfo(Locale(identifier: "es_419")) == LocaleInfo(locale: "en-US", region: "US"))
    }
}
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/TitleTests 2>&1 | grep -E "error:|Test run" | head -5`
Expected: FAIL de compilação — `cannot find 'RecommendationsResponse' in scope` (e similares).

- [ ] **Step 5: Criar `FilmFinder/Domain/MediaType.swift`**

```swift
import Foundation

enum MediaType: String, Codable, CaseIterable, Sendable {
    case movie
    case tv
}
```

- [ ] **Step 6: Criar `FilmFinder/Domain/Title.swift`**

```swift
import Foundation

struct StreamingProvider: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String
}

struct Providers: Codable, Hashable, Sendable {
    var region: String
    var link: URL?
    var flatrate: [StreamingProvider]
    var rent: [StreamingProvider]
    var buy: [StreamingProvider]
    var free: [StreamingProvider]

    static func empty(region: String) -> Providers {
        Providers(region: region, link: nil, flatrate: [], rent: [], buy: [], free: [])
    }

    var isEmpty: Bool {
        flatrate.isEmpty && rent.isEmpty && buy.isEmpty && free.isEmpty
    }

    /// Logos exibidos no card: assinatura primeiro; sem assinatura, os gratuitos.
    func highlighted(limit: Int = 3) -> [StreamingProvider] {
        Array((flatrate.isEmpty ? free : flatrate).prefix(limit))
    }
}

struct Title: Codable, Hashable, Sendable, Identifiable {
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let originalTitle: String
    let year: Int?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let rating: Double
    let runtimeMinutes: Int?
    let seasons: Int?
    let genres: [String]
    let reason: String
    let providers: Providers

    var id: String { "\(mediaType.rawValue)-\(tmdbId)" }

    /// Nota TMDB (0–10) convertida para 0–5 estrelas, como no app antigo.
    static func stars(for rating: Double) -> Int {
        min(5, max(0, Int(rating / 2 + 0.5)))
    }

    var stars: Int { Title.stars(for: rating) }
}
```

- [ ] **Step 6.1: Criar `FilmFinder/Domain/Recommendation.swift`**

```swift
import Foundation

struct RecommendationRequest: Encodable, Sendable {
    let query: String
    let mediaType: MediaType
    let excludeTmdbIds: [Int]
    let locale: String
    let region: String
}

struct Quota: Decodable, Equatable, Sendable {
    let used: Int
    let limit: Int
    let resetsAt: Date

    var remaining: Int { max(0, limit - used) }
}

struct RecommendationsResponse: Decodable, Sendable {
    let titles: [Title]
    let quota: Quota?
}

extension JSONDecoder {
    /// Decodificador da API: datas em ISO 8601 (`2026-10-06T00:00:00Z`).
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
```

- [ ] **Step 6.2: Criar `FilmFinder/Domain/TMDBImage.swift`**

```swift
import Foundation

enum TMDBImage {
    static func poster(_ path: String?) -> URL? { url(size: "w500", path) }
    static func backdrop(_ path: String?) -> URL? { url(size: "w780", path) }
    static func logo(_ path: String?) -> URL? { url(size: "w92", path) }

    private static func url(size: String, _ path: String?) -> URL? {
        guard let path, path.hasPrefix("/") else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
```

- [ ] **Step 6.3: Criar `FilmFinder/Domain/LocaleInfo.swift`**

```swift
import Foundation

/// Idioma e região enviados ao backend (`pt-BR` / `BR`). Cai em `en-US`/`US` quando o aparelho
/// não tem os dois no formato esperado pelo servidor.
struct LocaleInfo: Equatable, Sendable {
    let locale: String
    let region: String

    init(locale: String, region: String) {
        self.locale = locale
        self.region = region
    }

    init(_ source: Locale = .current) {
        if let language = source.language.languageCode?.identifier,
           let region = source.region?.identifier,
           language.count == 2, region.count == 2 {
            self.init(locale: "\(language)-\(region)", region: region)
        } else {
            self.init(locale: "en-US", region: "US")
        }
    }
}
```

- [ ] **Step 7: Rodar e ver passar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS (Smoke + Title + TMDBImage + LocaleInfo).

- [ ] **Step 8: Commit**

```bash
git add FilmFinder/Domain FilmFinderTests
git commit -m "feat(ios): add unified Title domain model, TMDB image URLs and locale info"
```

---

### Task iOS-3: Transporte HTTP, serviço de recomendações e token de acesso

**Files:**
- Create: `FilmFinder/Core/API/APIConfig.swift`, `APIError.swift`, `HTTPTransport.swift`, `AuthorizedAPI.swift`, `APIClient.swift`
- Create: `FilmFinderTests/Support/MockURLProtocol.swift`, `FilmFinderTests/Support/FakeTokens.swift`
- Test: `FilmFinderTests/APIClientTests.swift`

**Interfaces:**
- Consumes: `RecommendationRequest`, `RecommendationsResponse`, `Quota`, `JSONDecoder.api` (Task iOS-2)
- Produces:
  - `struct APIConfig: Sendable, Equatable { baseURL: URL; init(baseURL:); init(infoDictionary: [String: Any]?) throws; static func live() throws -> APIConfig }`
  - `enum APIError: Error, Equatable, Sendable { case unauthorized, quotaExceeded, serviceUnavailable, offline, invalidResponse; case forbidden(String), invalidInput(String), server(String); var invalidatesSession: Bool }`
  - `protocol RecommendationService: Sendable { func recommend(_ request: RecommendationRequest) async throws -> RecommendationsResponse }`
  - `protocol AccessTokenProvider: Sendable { func accessToken() async throws -> String; func refreshedAccessToken(after rejected: String) async throws -> String }`
  - `struct HTTPTransport: Sendable { init(baseURL: URL, session: URLSession = .shared); func send<R: Decodable>(_ method: String, _ path: String, bearer: String? = nil) async throws -> R; func send<B: Encodable, R: Decodable>(_ method: String, _ path: String, body: B, bearer: String? = nil) async throws -> R; func fetchChallenge() async throws -> String }`
  - `struct AuthorizedAPI: Sendable { init(transport:tokens:); func send<R>(_ method: String, _ path: String) async throws -> R; func send<B, R>(_ method: String, _ path: String, body: B) async throws -> R }` — pede o token, e se vier 401 pede **um** token renovado e tenta **uma** vez
  - `struct APIClient: RecommendationService { init(api: AuthorizedAPI); init(transport: HTTPTransport, tokens: any AccessTokenProvider) }`
  - `struct OKResponse: Decodable { let ok: Bool }`, `struct ChallengeResponse: Decodable { let challenge: String }`
  - Teste: `MockURLProtocol` (`handler`, `session()`), `httpResponse(_:status:)`, `URLRequest.bodyData()`, `FakeTokens`

- [ ] **Step 1: Criar `FilmFinderTests/Support/MockURLProtocol.swift`**

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

extension URLRequest {
    /// `URLProtocol` recebe o corpo como stream, não em `httpBody`.
    func bodyData() -> Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

func httpResponse(_ url: URL, status: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}
```

- [ ] **Step 2: Criar `FilmFinderTests/Support/FakeTokens.swift`**

```swift
import Foundation
@testable import FilmFinder

final class FakeTokens: AccessTokenProvider, @unchecked Sendable {
    var token: String
    var refreshed: String
    private(set) var refreshCalls: [String] = []

    init(token: String = "tok", refreshed: String = "tok2") {
        self.token = token
        self.refreshed = refreshed
    }

    func accessToken() async throws -> String { token }

    func refreshedAccessToken(after rejected: String) async throws -> String {
        refreshCalls.append(rejected)
        return refreshed
    }
}
```

- [ ] **Step 3: Escrever os testes que falham — `FilmFinderTests/APIClientTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

@Suite(.serialized) struct APIClientTests {
    private let base = URL(string: "https://api.example.com")!
    private let request = RecommendationRequest(
        query: "algo leve", mediaType: .movie, excludeTmdbIds: [1, 2], locale: "pt-BR", region: "BR"
    )

    private func client(_ tokens: FakeTokens = FakeTokens()) -> APIClient {
        APIClient(transport: HTTPTransport(baseURL: base, session: MockURLProtocol.session()), tokens: tokens)
    }

    private func errorBody(_ code: String, _ message: String) -> Data {
        Data(#"{"error":{"code":"\#(code)","message":"\#(message)"}}"#.utf8)
    }

    @Test func sendsExpectedRequestAndDecodesTitlesAndQuota() async throws {
        let body = try fixtureData("recommendations")
        nonisolated(unsafe) var captured: URLRequest?
        MockURLProtocol.handler = { req in
            captured = req
            return (httpResponse(req.url!, status: 200), body)
        }

        let response = try await client(FakeTokens(token: "abc")).recommend(request)

        #expect(response.titles.map(\.tmdbId) == [157336, 70523])
        #expect(response.quota?.remaining == 4)
        let sent = try #require(captured)
        #expect(sent.url?.absoluteString == "https://api.example.com/v1/recommendations")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "authorization") == "Bearer abc")
        #expect(sent.value(forHTTPHeaderField: "content-type") == "application/json")
        let sentBody = try #require(sent.bodyData())
        let json = try #require(JSONSerialization.jsonObject(with: sentBody) as? [String: Any])
        #expect(json["query"] as? String == "algo leve")
        #expect(json["mediaType"] as? String == "movie")
        #expect(json["excludeTmdbIds"] as? [Int] == [1, 2])
        #expect(json["locale"] as? String == "pt-BR")
        #expect(json["region"] as? String == "BR")
    }

    @Test func retriesOnceWithARefreshedTokenAfter401() async throws {
        let body = try fixtureData("recommendations")
        nonisolated(unsafe) var seen: [String] = []
        MockURLProtocol.handler = { req in
            let auth = req.value(forHTTPHeaderField: "authorization") ?? ""
            seen.append(auth)
            if auth == "Bearer new" { return (httpResponse(req.url!, status: 200), body) }
            return (httpResponse(req.url!, status: 401), self.errorBody("unauthorized", "expired"))
        }
        let tokens = FakeTokens(token: "old", refreshed: "new")

        _ = try await client(tokens).recommend(request)

        #expect(seen == ["Bearer old", "Bearer new"])
        #expect(tokens.refreshCalls == ["old"])
    }

    @Test func doesNotLoopWhenTheRefreshedTokenIsRejectedToo() async {
        nonisolated(unsafe) var attempts = 0
        MockURLProtocol.handler = { req in
            attempts += 1
            return (httpResponse(req.url!, status: 401), self.errorBody("unauthorized", "no"))
        }
        await #expect(throws: APIError.unauthorized) { try await client().recommend(request) }
        #expect(attempts == 2)
    }

    @Test func mapsHTTPStatusToAPIError() async {
        let cases: [(Int, Data, APIError)] = [
            (402, errorBody("quota_exceeded", "limit"), .quotaExceeded),
            (403, errorBody("forbidden", "not allowed"), .forbidden("not allowed")),
            (503, errorBody("ai_unavailable", "down"), .serviceUnavailable),
            (400, errorBody("invalid_input", "query too long"), .invalidInput("query too long")),
            (500, errorBody("internal", "boom"), .server("boom")),
            (502, Data("<html>bad gateway</html>".utf8), .server("HTTP 502")),
        ]
        for (status, body, expected) in cases {
            MockURLProtocol.handler = { req in (httpResponse(req.url!, status: status), body) }
            await #expect(throws: expected, "status \(status)") { try await client().recommend(request) }
        }
    }

    @Test func mapsConnectivityFailuresToOffline() async {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed] {
            MockURLProtocol.handler = { _ in throw URLError(code) }
            await #expect(throws: APIError.offline) { try await client().recommend(request) }
        }
    }

    @Test func mapsTimeoutToServiceUnavailable() async {
        MockURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: APIError.serviceUnavailable) { try await client().recommend(request) }
    }

    @Test func malformedSuccessBodyIsInvalidResponse() async {
        MockURLProtocol.handler = { req in (httpResponse(req.url!, status: 200), Data("{}".utf8)) }
        await #expect(throws: APIError.invalidResponse) { try await client().recommend(request) }
    }

    @Test func sessionInvalidatingErrorsAreFlagged() {
        #expect(APIError.unauthorized.invalidatesSession)
        #expect(APIError.forbidden("x").invalidatesSession)
        #expect(!APIError.offline.invalidatesSession)
        #expect(!APIError.quotaExceeded.invalidatesSession)
    }
}

@Suite struct APIConfigTests {
    @Test func readsInfoDictionary() throws {
        let config = try APIConfig(infoDictionary: ["APIBaseURL": "https://api.example.com"])
        #expect(config.baseURL.absoluteString == "https://api.example.com")
    }

    @Test func rejectsMissingOrInsecureValues() {
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: nil) }
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: ["APIBaseURL": "http://insecure.example.com"]) }
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: ["APIBaseURL": "not a url"]) }
    }
}
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/APIClientTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'APIClient' in scope`.

- [ ] **Step 5: Criar `FilmFinder/Core/API/APIConfig.swift`**

```swift
import Foundation

struct APIConfig: Sendable, Equatable {
    let baseURL: URL

    enum ConfigError: Error, Equatable {
        case missing(String)
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    init(infoDictionary: [String: Any]?) throws {
        guard let raw = infoDictionary?["APIBaseURL"] as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil
        else { throw ConfigError.missing("APIBaseURL") }
        self.init(baseURL: url)
    }

    static func live() throws -> APIConfig {
        try APIConfig(infoDictionary: Bundle.main.infoDictionary)
    }
}
```

- [ ] **Step 6: Criar `FilmFinder/Core/API/APIError.swift`**

```swift
import Foundation

enum APIError: Error, Equatable, Sendable {
    case unauthorized
    case quotaExceeded
    case serviceUnavailable
    case offline
    case invalidResponse
    case forbidden(String)
    case invalidInput(String)
    case server(String)

    /// Erros que indicam que as credenciais do dispositivo não valem mais.
    var invalidatesSession: Bool {
        switch self {
        case .unauthorized, .forbidden: true
        default: false
        }
    }
}

protocol RecommendationService: Sendable {
    func recommend(_ request: RecommendationRequest) async throws -> RecommendationsResponse
}

protocol AccessTokenProvider: Sendable {
    func accessToken() async throws -> String
    /// Chamado depois de um 401: devolve um token novo (ou o que outra chamada já renovou).
    func refreshedAccessToken(after rejected: String) async throws -> String
}

struct OKResponse: Decodable, Sendable {
    let ok: Bool
}

struct ChallengeResponse: Decodable, Sendable {
    let challenge: String
}
```

- [ ] **Step 7: Criar `FilmFinder/Core/API/HTTPTransport.swift`**

```swift
import Foundation

struct HTTPTransport: Sendable {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<Response: Decodable>(_ method: String, _ path: String, bearer: String? = nil) async throws -> Response {
        try await perform(method, path, body: nil, bearer: bearer)
    }

    func send<Body: Encodable, Response: Decodable>(
        _ method: String, _ path: String, body: Body, bearer: String? = nil
    ) async throws -> Response {
        try await perform(method, path, body: try JSONEncoder().encode(body), bearer: bearer)
    }

    func fetchChallenge() async throws -> String {
        let response: ChallengeResponse = try await send("POST", "v1/auth/challenge")
        return response.challenge
    }

    private func perform<Response: Decodable>(
        _ method: String, _ path: String, body: Data?, bearer: String?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 45
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "content-type")
        }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "authorization") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw Self.map(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw Self.map(status: http.statusCode, body: data) }
        do {
            return try JSONDecoder.api.decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable { let code: String; let message: String }
        let error: Body
    }

    private static func map(status: Int, body: Data) -> APIError {
        let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: body))?.error.message
        switch status {
        case 401: return .unauthorized
        case 402: return .quotaExceeded
        case 403: return .forbidden(message ?? "Forbidden")
        case 503: return .serviceUnavailable
        case 400: return .invalidInput(message ?? "Invalid request")
        default: return .server(message ?? "HTTP \(status)")
        }
    }

    private static func map(_ error: URLError) -> Error {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return APIError.offline
        case .timedOut:
            return APIError.serviceUnavailable
        case .cancelled:
            return CancellationError()
        default:
            return APIError.server(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 8: Criar `FilmFinder/Core/API/AuthorizedAPI.swift`**

```swift
import Foundation

/// Envia requisições autenticadas: usa o token atual e, se o servidor recusar (401),
/// pede um token renovado e tenta **uma** vez.
struct AuthorizedAPI: Sendable {
    let transport: HTTPTransport
    let tokens: any AccessTokenProvider

    func send<Response: Decodable>(_ method: String, _ path: String) async throws -> Response {
        try await authorized { token in try await transport.send(method, path, bearer: token) }
    }

    func send<Body: Encodable, Response: Decodable>(_ method: String, _ path: String, body: Body) async throws -> Response {
        try await authorized { token in try await transport.send(method, path, body: body, bearer: token) }
    }

    private func authorized<T>(_ call: (String) async throws -> T) async throws -> T {
        let token = try await tokens.accessToken()
        do {
            return try await call(token)
        } catch APIError.unauthorized {
            let fresh = try await tokens.refreshedAccessToken(after: token)
            return try await call(fresh)
        }
    }
}
```

- [ ] **Step 9: Criar `FilmFinder/Core/API/APIClient.swift`**

```swift
import Foundation

struct APIClient: RecommendationService {
    let api: AuthorizedAPI

    init(api: AuthorizedAPI) {
        self.api = api
    }

    init(transport: HTTPTransport, tokens: any AccessTokenProvider) {
        self.init(api: AuthorizedAPI(transport: transport, tokens: tokens))
    }

    func recommend(_ request: RecommendationRequest) async throws -> RecommendationsResponse {
        try await api.send("POST", "v1/recommendations", body: request)
    }
}
```

- [ ] **Step 10: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS.

- [ ] **Step 11: Verificação de contrato contra o Worker real** (uma chamada paga, ~US$0,001; usa o registro sem atestação do `dev`)

Run:
```bash
U=https://filmfinder-api-dev.andrefw483.workers.dev
T=$(curl -s -X POST $U/v1/devices -H 'content-type: application/json' -d '{"unattested":true}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")
curl -s -m 45 $U/v1/recommendations -H "authorization: Bearer $T" -H 'content-type: application/json' -d '{"query":"comédia leve","mediaType":"movie","locale":"pt-BR","region":"BR"}' > /tmp/real-response.json
python3 - <<'EOF'
import json
d = json.load(open('/tmp/real-response.json'))
t = d['titles'][0]
expected = {'tmdbId','mediaType','title','originalTitle','year','overview','posterPath','backdropPath','rating','runtimeMinutes','seasons','genres','reason','providers'}
print('campos extras/faltando:', set(t) ^ expected)
print('providers:', sorted(t['providers']))
print('quota:', d['quota'])
EOF
```
Expected: `campos extras/faltando: set()`, providers `['buy', 'flatrate', 'free', 'link', 'region', 'rent']` e `quota: {'used': 1, 'limit': 5, 'resetsAt': '...Z'}`. Se houver diferença, ajuste `Title`/`Providers`/`Quota` e a fixture antes de seguir.

- [ ] **Step 12: Commit**

```bash
git add FilmFinder/Core FilmFinderTests
git commit -m "feat(ios): add HTTP transport, authorized API with token retry and recommendations client"
```

### Task iOS-4: Identidade do dispositivo — Keychain, App Attest e `AuthService`

**Files:**
- Create: `FilmFinder/Core/Auth/SecretStore.swift`, `AppAttestProvider.swift`, `AuthService.swift`
- Create: `FilmFinderTests/Support/AuthSupport.swift`
- Test: `FilmFinderTests/AuthServiceTests.swift`

**Interfaces:**
- Consumes: `HTTPTransport`, `AccessTokenProvider`, `APIError` (Task iOS-3)
- Produces:
  - `protocol SecretStore: Sendable { func string(for key: String) -> String?; func set(_ value: String?, for key: String) }`; `final class KeychainSecretStore: SecretStore` (`init(service: String = "com.andre.filmfinder")`)
  - `protocol AppAttestProviding: Sendable { var isSupported: Bool { get }; func generateKey() async throws -> String; func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data; func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data }`; `struct DeviceAppAttest: AppAttestProviding` (DeviceCheck)
  - `actor AuthService: AccessTokenProvider { init(transport: HTTPTransport, secrets: any SecretStore, attest: any AppAttestProviding, now: @escaping @Sendable () -> Date = { Date() }) }` — registra o dispositivo sozinho no primeiro uso, guarda o token de acesso em memória, renova antes de expirar (com asserção App Attest quando o dispositivo foi atestado), junta renovações simultâneas e, se o servidor recusar o refresh, apaga as credenciais e registra de novo
  - Teste: `InMemorySecretStore`, `FakeAppAttest`

Fluxo (alinhado ao backend): registro `POST v1/devices` com `{ keyId, attestation, challenge }` (atestação sobre `SHA256(challenge)`) ou, sem App Attest (simulador), `{ unattested: true }` (só o Worker `dev` aceita); renovação `POST v1/auth/refresh` com `{ refreshToken, challenge, assertion }` onde a asserção é sobre `SHA256("{challenge}:{refreshToken}")`.

- [ ] **Step 1: Criar o apoio de testes `FilmFinderTests/Support/AuthSupport.swift`**

```swift
import Foundation
@testable import FilmFinder

final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]

    init(_ values: [String: String] = [:]) { self.values = values }

    func string(for key: String) -> String? {
        lock.withLock { values[key] }
    }

    func set(_ value: String?, for key: String) {
        lock.withLock { values[key] = value }
    }
}

final class FakeAppAttest: AppAttestProviding, @unchecked Sendable {
    var isSupported: Bool
    var assertionError: Error?
    private(set) var generatedKeys: [String] = []
    private(set) var attestCalls: [(keyId: String, hash: Data)] = []
    private(set) var assertionCalls: [(keyId: String, hash: Data)] = []

    init(isSupported: Bool) { self.isSupported = isSupported }

    func generateKey() async throws -> String {
        let id = "key-\(generatedKeys.count + 1)"
        generatedKeys.append(id)
        return id
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        attestCalls.append((keyId, clientDataHash))
        return Data("attestation-for-\(keyId)".utf8)
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        if let assertionError { throw assertionError }
        assertionCalls.append((keyId, clientDataHash))
        return Data("assertion-for-\(keyId)".utf8)
    }
}
```

- [ ] **Step 2: Escrever os testes que falham — `FilmFinderTests/AuthServiceTests.swift`**

```swift
import CryptoKit
import Foundation
import Testing
@testable import FilmFinder

private final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    func now() -> Date { date }
}

private func sha256(_ text: String) -> Data { Data(SHA256.hash(data: Data(text.utf8))) }

@Suite(.serialized) struct AuthServiceTests {
    private let base = URL(string: "https://api.example.com")!

    private func makeService(
        attest: FakeAppAttest,
        secrets: InMemorySecretStore = InMemorySecretStore(),
        clock: Clock = Clock()
    ) -> AuthService {
        AuthService(
            transport: HTTPTransport(baseURL: base, session: MockURLProtocol.session()),
            secrets: secrets,
            attest: attest,
            now: { clock.now() }
        )
    }

    private func sessionJSON(access: String, refresh: String, expiresIn: TimeInterval, clock: Clock) -> Data {
        let expiresAt = Int(clock.date.addingTimeInterval(expiresIn).timeIntervalSince1970)
        return Data(#"{"accessToken":"\#(access)","expiresAt":\#(expiresAt),"refreshToken":"\#(refresh)"}"#.utf8)
    }

    /// Instala um handler que roteia por caminho e registra o que chegou.
    private func route(_ routes: [String: (URLRequest) throws -> (Int, Data)]) -> RecordBox {
        let box = RecordBox()
        MockURLProtocol.handler = { req in
            let path = req.url!.path
            box.append(path, body: req.bodyData())
            guard let handler = routes[path] else { return (httpResponse(req.url!, status: 404), Data()) }
            let (status, data) = try handler(req)
            return (httpResponse(req.url!, status: status), data)
        }
        return box
    }

    @Test func registersWithoutAttestationWhenAppAttestIsUnsupported() async throws {
        let clock = Clock()
        let secrets = InMemorySecretStore()
        let box = route(["/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) }])
        let service = makeService(attest: FakeAppAttest(isSupported: false), secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "A1")
        #expect(try await service.accessToken() == "A1") // cache: sem nova requisição

        #expect(box.paths == ["/v1/devices"])
        #expect(box.json(0) as? [String: Bool] == ["unattested": true])
        #expect(secrets.string(for: AuthService.Keys.refreshToken) == "R1")
        #expect(secrets.string(for: AuthService.Keys.keyId) == nil)
    }

    @Test func registersWithAttestationOverTheChallenge() async throws {
        let clock = Clock()
        let attest = FakeAppAttest(isSupported: true)
        let secrets = InMemorySecretStore()
        let box = route([
            "/v1/auth/challenge": { _ in (200, Data(#"{"challenge":"c1"}"#.utf8)) },
            "/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) },
        ])
        let service = makeService(attest: attest, secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "A1")

        #expect(attest.attestCalls.map(\.keyId) == ["key-1"])
        #expect(attest.attestCalls.first?.hash == sha256("c1"))
        let body = try #require(box.json(1) as? [String: String])
        #expect(body["keyId"] == "key-1")
        #expect(body["challenge"] == "c1")
        #expect(body["attestation"] == Data("attestation-for-key-1".utf8).base64EncodedString())
        #expect(secrets.string(for: AuthService.Keys.keyId) == "key-1")
    }

    @Test func refreshesAnExpiredTokenWithAnAssertionAndRotatesTheRefreshToken() async throws {
        let clock = Clock()
        let attest = FakeAppAttest(isSupported: true)
        let secrets = InMemorySecretStore()
        nonisolated(unsafe) var challengeCount = 0
        let box = route([
            "/v1/auth/challenge": { _ in
                challengeCount += 1
                return (200, Data(#"{"challenge":"c\#(challengeCount)"}"#.utf8))
            },
            "/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) },
            "/v1/auth/refresh": { _ in (200, self.sessionJSON(access: "A2", refresh: "R2", expiresIn: 900, clock: clock)) },
        ])
        let service = makeService(attest: attest, secrets: secrets, clock: clock)
        _ = try await service.accessToken()

        clock.date = clock.date.addingTimeInterval(900) // expirou (restam < 60 s)
        #expect(try await service.accessToken() == "A2")

        #expect(box.paths == ["/v1/auth/challenge", "/v1/devices", "/v1/auth/challenge", "/v1/auth/refresh"])
        #expect(attest.assertionCalls.first?.hash == sha256("c2:R1"))
        let body = try #require(box.json(3) as? [String: String])
        #expect(body["refreshToken"] == "R1")
        #expect(body["challenge"] == "c2")
        #expect(body["assertion"] == Data("assertion-for-key-1".utf8).base64EncodedString())
        #expect(secrets.string(for: AuthService.Keys.refreshToken) == "R2")
    }

    @Test func refreshesAnUnattestedDeviceWithJustTheRefreshToken() async throws {
        let clock = Clock()
        let secrets = InMemorySecretStore([AuthService.Keys.refreshToken: "R1"])
        let box = route(["/v1/auth/refresh": { _ in (200, self.sessionJSON(access: "A2", refresh: "R2", expiresIn: 900, clock: clock)) }])
        let service = makeService(attest: FakeAppAttest(isSupported: false), secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "A2")

        #expect(box.paths == ["/v1/auth/refresh"])
        #expect(box.json(0) as? [String: String] == ["refreshToken": "R1"])
    }

    @Test func registersAgainWhenTheServerRejectsTheRefreshToken() async throws {
        let clock = Clock()
        let secrets = InMemorySecretStore([AuthService.Keys.refreshToken: "stale", AuthService.Keys.keyId: "old-key"])
        let attest = FakeAppAttest(isSupported: true)
        let box = route([
            "/v1/auth/challenge": { _ in (200, Data(#"{"challenge":"c"}"#.utf8)) },
            "/v1/auth/refresh": { _ in (401, Data(#"{"error":{"code":"unauthorized","message":"no"}}"#.utf8)) },
            "/v1/devices": { _ in (200, self.sessionJSON(access: "NEW", refresh: "R9", expiresIn: 900, clock: clock)) },
        ])
        let service = makeService(attest: attest, secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "NEW")

        #expect(box.paths.contains("/v1/devices"))
        #expect(secrets.string(for: AuthService.Keys.refreshToken) == "R9")
        #expect(secrets.string(for: AuthService.Keys.keyId) == "key-1")   // chave nova; a antiga foi descartada
    }

    @Test func registersAgainWhenTheAssertionCannotBeGenerated() async throws {
        let clock = Clock()
        let secrets = InMemorySecretStore([AuthService.Keys.refreshToken: "R1", AuthService.Keys.keyId: "lost-key"])
        let attest = FakeAppAttest(isSupported: true)
        attest.assertionError = URLError(.unknown) // ex.: chave perdida após reinstalar o app
        let box = route([
            "/v1/auth/challenge": { _ in (200, Data(#"{"challenge":"c"}"#.utf8)) },
            "/v1/devices": { _ in (200, self.sessionJSON(access: "NEW", refresh: "R2", expiresIn: 900, clock: clock)) },
        ])
        let service = makeService(attest: attest, secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "NEW")
        #expect(!box.paths.contains("/v1/auth/refresh"))
    }

    @Test func refreshedAccessTokenReturnsTheCachedOneWhenAnotherCallerAlreadyRenewed() async throws {
        let clock = Clock()
        let box = route(["/v1/devices": { _ in (200, self.sessionJSON(access: "B", refresh: "R1", expiresIn: 900, clock: clock)) }])
        let service = makeService(attest: FakeAppAttest(isSupported: false), clock: clock)
        _ = try await service.accessToken()

        #expect(try await service.refreshedAccessToken(after: "A-rejected") == "B")
        #expect(box.paths == ["/v1/devices"])
    }

    @Test func refreshedAccessTokenRenewsWhenTheCachedTokenIsTheRejectedOne() async throws {
        let clock = Clock()
        nonisolated(unsafe) var n = 0
        _ = route([
            "/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) },
            "/v1/auth/refresh": { _ in
                n += 1
                return (200, self.sessionJSON(access: "A2", refresh: "R2", expiresIn: 900, clock: clock))
            },
        ])
        let service = makeService(attest: FakeAppAttest(isSupported: false), clock: clock)
        let first = try await service.accessToken()

        #expect(try await service.refreshedAccessToken(after: first) == "A2")
        #expect(n == 1)
    }

    @Test func concurrentCallsShareASingleRegistration() async throws {
        let clock = Clock()
        let box = route(["/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) }])
        let service = makeService(attest: FakeAppAttest(isSupported: false), clock: clock)

        async let a = service.accessToken()
        async let b = service.accessToken()
        async let c = service.accessToken()
        let tokens = try await [a, b, c]

        #expect(tokens == ["A1", "A1", "A1"])
        #expect(box.paths.count == 1)
    }

    @Test func offlineDuringRefreshKeepsTheCredentials() async {
        let secrets = InMemorySecretStore([AuthService.Keys.refreshToken: "R1"])
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let service = makeService(attest: FakeAppAttest(isSupported: false), secrets: secrets)

        await #expect(throws: APIError.offline) { try await service.accessToken() }
        #expect(secrets.string(for: AuthService.Keys.refreshToken) == "R1")
    }
}

/// Coleta os caminhos e corpos recebidos pelo `MockURLProtocol` (acessado de threads de rede).
private final class RecordBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _paths: [String] = []
    private var _bodies: [Data?] = []

    var paths: [String] { lock.withLock { _paths } }

    func append(_ path: String, body: Data?) {
        lock.withLock {
            _paths.append(path)
            _bodies.append(body)
        }
    }

    func json(_ index: Int) -> Any? {
        let data = lock.withLock { index < _bodies.count ? _bodies[index] : nil }
        return data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
    }
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/AuthServiceTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'AuthService' in scope`.

- [ ] **Step 4: Criar `FilmFinder/Core/Auth/SecretStore.swift`**

```swift
import Foundation
import Security

protocol SecretStore: Sendable {
    func string(for key: String) -> String?
    func set(_ value: String?, for key: String)
}

/// Guarda segredos no Keychain (acessíveis após o primeiro desbloqueio, só neste aparelho).
final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    init(service: String = "com.andre.filmfinder") {
        self.service = service
    }

    func string(for key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String?, for key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
        guard let value else { return }
        var item = baseQuery(key)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Core/Auth/AppAttestProvider.swift`**

```swift
import DeviceCheck
import Foundation

protocol AppAttestProviding: Sendable {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data
}

/// App Attest do sistema. `isSupported` é `false` no simulador e em aparelhos sem suporte.
struct DeviceAppAttest: AppAttestProviding {
    private var service: DCAppAttestService { DCAppAttestService.shared }

    var isSupported: Bool { service.isSupported }

    func generateKey() async throws -> String {
        try await service.generateKey()
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await service.attestKey(keyId, clientDataHash: clientDataHash)
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
    }
}
```

- [ ] **Step 6: Criar `FilmFinder/Core/Auth/AuthService.swift`**

```swift
import CryptoKit
import Foundation

private struct SessionResponse: Decodable, Sendable {
    let accessToken: String
    let expiresAt: Int
    let refreshToken: String
}

private struct RegisterBody: Encodable, Sendable {
    let keyId: String
    let attestation: String
    let challenge: String
}

private struct UnattestedBody: Encodable, Sendable {
    let unattested = true
}

private struct RefreshBody: Encodable, Sendable {
    let refreshToken: String
    var challenge: String?
    var assertion: String?
}

private enum AuthError: Error {
    case attestationUnavailable
}

/// Mantém a identidade do dispositivo: registra sozinho no primeiro uso e renova o token de acesso.
actor AuthService: AccessTokenProvider {
    enum Keys {
        static let refreshToken = "refreshToken"
        static let keyId = "appAttestKeyId"
    }

    private static let renewalMargin: TimeInterval = 60

    private let transport: HTTPTransport
    private let secrets: any SecretStore
    private let attest: any AppAttestProviding
    private let now: @Sendable () -> Date

    private var cached: (token: String, expiresAt: Date)?
    private var inflight: Task<String, Error>?

    init(
        transport: HTTPTransport,
        secrets: any SecretStore,
        attest: any AppAttestProviding,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.secrets = secrets
        self.attest = attest
        self.now = now
    }

    func accessToken() async throws -> String {
        if let cached, isFresh(cached.expiresAt) { return cached.token }
        return try await renew()
    }

    func refreshedAccessToken(after rejected: String) async throws -> String {
        if let cached, cached.token != rejected, isFresh(cached.expiresAt) { return cached.token }
        cached = nil
        return try await renew()
    }

    // MARK: - Renovação

    private func isFresh(_ expiresAt: Date) -> Bool {
        expiresAt.timeIntervalSince(now()) > Self.renewalMargin
    }

    /// Renovações simultâneas viram uma só.
    private func renew() async throws -> String {
        if let inflight { return try await inflight.value }
        let task = Task { try await self.performRenewal() }
        inflight = task
        defer { inflight = nil }
        return try await task.value
    }

    private func performRenewal() async throws -> String {
        if secrets.string(for: Keys.refreshToken) != nil {
            do {
                return try await refresh()
            } catch let error as APIError where error.invalidatesSession {
                clearCredentials()
            } catch AuthError.attestationUnavailable {
                clearCredentials()
            }
        }
        return try await register()
    }

    private func register() async throws -> String {
        let response: SessionResponse
        if attest.isSupported {
            let challenge = try await transport.fetchChallenge()
            let keyId = try await attest.generateKey()
            let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
            let attestation = try await attest.attestKey(keyId, clientDataHash: clientDataHash)
            response = try await transport.send(
                "POST", "v1/devices",
                body: RegisterBody(keyId: keyId, attestation: attestation.base64EncodedString(), challenge: challenge)
            )
            secrets.set(keyId, for: Keys.keyId)
        } else {
            response = try await transport.send("POST", "v1/devices", body: UnattestedBody())
            secrets.set(nil, for: Keys.keyId)
        }
        return store(response)
    }

    private func refresh() async throws -> String {
        guard let refreshToken = secrets.string(for: Keys.refreshToken) else { throw APIError.unauthorized }
        var body = RefreshBody(refreshToken: refreshToken)
        if let keyId = secrets.string(for: Keys.keyId) {
            guard attest.isSupported else { throw AuthError.attestationUnavailable }
            let challenge = try await transport.fetchChallenge()
            let clientDataHash = Data(SHA256.hash(data: Data("\(challenge):\(refreshToken)".utf8)))
            do {
                let assertion = try await attest.generateAssertion(keyId, clientDataHash: clientDataHash)
                body.challenge = challenge
                body.assertion = assertion.base64EncodedString()
            } catch {
                throw AuthError.attestationUnavailable
            }
        }
        let response: SessionResponse = try await transport.send("POST", "v1/auth/refresh", body: body)
        return store(response)
    }

    private func store(_ response: SessionResponse) -> String {
        secrets.set(response.refreshToken, for: Keys.refreshToken)
        cached = (response.accessToken, Date(timeIntervalSince1970: TimeInterval(response.expiresAt)))
        return response.accessToken
    }

    private func clearCredentials() {
        secrets.set(nil, for: Keys.refreshToken)
        secrets.set(nil, for: Keys.keyId)
        cached = nil
    }
}
```

- [ ] **Step 7: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS. Atenção: `RefreshBody` com `challenge`/`assertion` opcionais **não** pode enviar `null`: o `JSONEncoder` omite chaves `nil` por padrão, o que é o desejado (o teste `refreshesAnUnattestedDevice...` confere que o corpo é só `{"refreshToken": ...}`).

- [ ] **Step 8: Commit**

```bash
git add FilmFinder/Core/Auth FilmFinderTests
git commit -m "feat(ios): add Keychain store, App Attest provider and self-registering AuthService"
```

### Task iOS-5: Biblioteca em SwiftData

**Files:**
- Create: `FilmFinder/Data/LibraryItem.swift`, `FilmFinder/Data/LibraryStore.swift`
- Create: `FilmFinderTests/Support/LibraryHarness.swift`
- Test: `FilmFinderTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: `Title`, `MediaType` (Task iOS-2)
- Produces:
  - `@Model final class LibraryItem { libraryKey: String; tmdbId: Int; mediaTypeRaw: String; snapshotData: Data; isFavorite, isWatched, inHistory: Bool; recommendedAt: Date; init(title: Title, recommendedAt: Date = Date()); var mediaType: MediaType; var snapshot: Title?; func updateSnapshot(_ title: Title) }`
  - `@MainActor final class LibraryStore { static let maxExcluded = 200; init(context: ModelContext); func item(for: Title) -> LibraryItem?; @discardableResult func upsert(_ title: Title) -> LibraryItem; func recordRecommended(_ titles: [Title]); func markShown(_ title: Title); func setFavorite(_ title: Title, _ value: Bool); func setWatched(_ title: Title, _ value: Bool); func removeFromHistory(_ title: Title); func clearHistory(); func excludedIDs(for mediaType: MediaType) -> [Int]; func save() }`
  - Teste: `@MainActor struct LibraryHarness { container; store; var items: [LibraryItem] }`

- [ ] **Step 1: Criar `FilmFinderTests/Support/LibraryHarness.swift`**

```swift
import Foundation
import SwiftData
@testable import FilmFinder

/// Container em memória; o `container` precisa ficar vivo enquanto o `store` é usado.
@MainActor
struct LibraryHarness {
    let container: ModelContainer
    let store: LibraryStore

    init() throws {
        container = try ModelContainer(
            for: LibraryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = LibraryStore(context: container.mainContext)
    }

    var items: [LibraryItem] {
        (try? container.mainContext.fetch(FetchDescriptor<LibraryItem>())) ?? []
    }

    func item(_ id: String) -> LibraryItem? {
        items.first { $0.libraryKey == id }
    }
}
```

- [ ] **Step 2: Escrever os testes que falham — `FilmFinderTests/LibraryStoreTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LibraryStoreTests {
    @Test func recordRecommendedUpsertsWithoutTouchingHistory() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 1), .sample(id: 2)])
        h.store.recordRecommended([.sample(id: 1)])

        #expect(h.items.count == 2)
        #expect(h.items.allSatisfy { !$0.inHistory && !$0.isFavorite && !$0.isWatched })
    }

    @Test func sameTmdbIdWithDifferentMediaTypeAreDistinctItems() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 5, type: .movie), .sample(id: 5, type: .tv)])
        #expect(h.items.count == 2)
    }

    @Test func markShownAddsToHistoryOnce() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.markShown(title)
        let first = try #require(h.item(title.id)).recommendedAt
        h.store.markShown(title)

        let item = try #require(h.item(title.id))
        #expect(item.inHistory)
        #expect(item.recommendedAt == first)
        #expect(h.items.count == 1)
    }

    @Test func favoriteAndWatchedAreIndependentFlags() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        h.store.setWatched(title, true)
        h.store.setFavorite(title, false)

        let item = try #require(h.item(title.id))
        #expect(!item.isFavorite)
        #expect(item.isWatched)
    }

    @Test func removeFromHistoryKeepsTheItemExcluded() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.markShown(title)
        h.store.removeFromHistory(title)

        #expect(try #require(h.item(title.id)).inHistory == false)
        #expect(h.store.excludedIDs(for: .movie) == [1])
    }

    @Test func clearHistoryOnlyClearsTheHistoryFlag() throws {
        let h = try LibraryHarness()
        h.store.markShown(.sample(id: 1))
        h.store.markShown(.sample(id: 2))
        h.store.setFavorite(.sample(id: 2), true)
        h.store.clearHistory()

        #expect(h.items.allSatisfy { !$0.inHistory })
        #expect(h.items.count == 2)
        #expect(try #require(h.item("movie-2")).isFavorite)
    }

    @Test func upsertRefreshesTheSnapshotButKeepsFlags() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1, title: "Old"), true)
        h.store.recordRecommended([.sample(id: 1, title: "New")])

        let item = try #require(h.item("movie-1"))
        #expect(item.isFavorite)
        #expect(item.snapshot?.title == "New")
    }

    @Test func excludedIDsAreFilteredByMediaType() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 1, type: .movie), .sample(id: 2, type: .tv)])
        #expect(h.store.excludedIDs(for: .movie) == [1])
        #expect(h.store.excludedIDs(for: .tv) == [2])
    }

    @Test func excludedIDsAreCappedWithFavoritesAndWatchedFirst() throws {
        let h = try LibraryHarness()
        for i in 0..<205 {
            let item = h.store.upsert(.sample(id: 100 + i))
            item.recommendedAt = Date(timeIntervalSince1970: 1_000_000 + Double(i))
        }
        let pinned = h.store.upsert(.sample(id: 1))
        pinned.isFavorite = true
        pinned.recommendedAt = Date(timeIntervalSince1970: 1)
        h.store.save()

        let ids = h.store.excludedIDs(for: .movie)
        #expect(ids.count == LibraryStore.maxExcluded)
        #expect(ids.first == 1)
        #expect(ids[1] == 304)            // mais recente depois dos fixados
        #expect(!ids.contains(100))       // os mais antigos caem fora do teto
    }
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/LibraryStoreTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'LibraryStore' in scope`.

- [ ] **Step 4: Criar `FilmFinder/Data/LibraryItem.swift`**

```swift
import Foundation
import SwiftData

@Model
final class LibraryItem {
    var libraryKey: String = ""
    var tmdbId: Int = 0
    var mediaTypeRaw: String = MediaType.movie.rawValue
    var snapshotData: Data = Data()
    var isFavorite: Bool = false
    var isWatched: Bool = false
    var inHistory: Bool = false
    var recommendedAt: Date = Date()

    init(title: Title, recommendedAt: Date = Date()) {
        libraryKey = title.id
        tmdbId = title.tmdbId
        mediaTypeRaw = title.mediaType.rawValue
        snapshotData = (try? JSONEncoder().encode(title)) ?? Data()
        self.recommendedAt = recommendedAt
    }

    var mediaType: MediaType { MediaType(rawValue: mediaTypeRaw) ?? .movie }

    var snapshot: Title? { try? JSONDecoder().decode(Title.self, from: snapshotData) }

    func updateSnapshot(_ title: Title) {
        snapshotData = (try? JSONEncoder().encode(title)) ?? snapshotData
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Data/LibraryStore.swift`**

```swift
import Foundation
import SwiftData

@MainActor
final class LibraryStore {
    /// Teto de ids enviados ao backend (`excludeTmdbIds`).
    static let maxExcluded = 200

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func item(for title: Title) -> LibraryItem? {
        fetch(key: title.id)
    }

    @discardableResult
    func upsert(_ title: Title) -> LibraryItem {
        if let existing = fetch(key: title.id) {
            existing.updateSnapshot(title)
            return existing
        }
        let created = LibraryItem(title: title)
        context.insert(created)
        return created
    }

    /// Grava os títulos como "já recomendados" (para exclusão futura); não entram no Histórico.
    func recordRecommended(_ titles: [Title]) {
        titles.forEach { upsert($0) }
        save()
    }

    /// O título foi exibido ao usuário: entra no Histórico (uma vez).
    func markShown(_ title: Title) {
        let item = upsert(title)
        if !item.inHistory {
            item.inHistory = true
            item.recommendedAt = Date()
        }
        save()
    }

    func setFavorite(_ title: Title, _ value: Bool) {
        upsert(title).isFavorite = value
        save()
    }

    func setWatched(_ title: Title, _ value: Bool) {
        upsert(title).isWatched = value
        save()
    }

    func removeFromHistory(_ title: Title) {
        fetch(key: title.id)?.inHistory = false
        save()
    }

    func clearHistory() {
        let descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.inHistory })
        for item in (try? context.fetch(descriptor)) ?? [] { item.inHistory = false }
        save()
    }

    /// Ids do mesmo tipo de mídia: favoritos e assistidos primeiro, depois os mais recentes; máx. 200.
    func excludedIDs(for mediaType: MediaType) -> [Int] {
        let raw = mediaType.rawValue
        let descriptor = FetchDescriptor<LibraryItem>(
            predicate: #Predicate { $0.mediaTypeRaw == raw },
            sortBy: [SortDescriptor(\.recommendedAt, order: .reverse)]
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let pinned = items.filter { $0.isFavorite || $0.isWatched }
        let rest = items.filter { !($0.isFavorite || $0.isWatched) }
        return Array((pinned + rest).prefix(Self.maxExcluded)).map(\.tmdbId)
    }

    func save() {
        try? context.save()
    }

    private func fetch(key: String) -> LibraryItem? {
        var descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.libraryKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS.

- [ ] **Step 7: Commit**

```bash
git add FilmFinder/Data FilmFinderTests
git commit -m "feat(ios): add SwiftData library store for history, favorites, watched and exclusions"
```

---

### Task iOS-6: Importador dos dados do app antigo (UserDefaults → SwiftData)

**Files:**
- Create: `FilmFinder/Data/LegacyImporter.swift`
- Test: `FilmFinderTests/LegacyImporterTests.swift`

**Interfaces:**
- Consumes: `LibraryStore`, `LibraryItem`, `Title`, `Providers`, `LocaleInfo` (Tasks iOS-2 e iOS-5)
- Produces: `@MainActor struct LegacyImporter { static let doneKey = "legacyImportDone.v1"; static let legacyKeys: [String]; init(defaults: UserDefaults, store: LibraryStore, region: String = LocaleInfo().region); @discardableResult func runIfNeeded() -> Int }` — devolve o número de itens importados.

Formato legado (de `Model/History.swift`, `FilmData.swift`, `SerieData.swift`): quatro chaves em `UserDefaults` (`allContent`, `favorites`, `watched`, `history`), cada uma um `[WatchedContent]` codificado em JSON; `WatchedContent = { id, date (segundos desde 2001), content: { "filme": FilmData } | { "serie": SerieData } }`; `FilmData/SerieData = { id, idFilme, title, image, releaseDate, originalTitle, duration, plot, rating, favorite, watched }`.

- [ ] **Step 1: Escrever os testes que falham — `FilmFinderTests/LegacyImporterTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LegacyImporterTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "legacy-\(UUID().uuidString)")!
    }

    private func movie(_ id: Int, title: String = "Avatar", favorite: Bool = false, watched: Bool = false, date: Double = 700_000_000) -> String {
        """
        {"id":"A1B2C3D4-0000-0000-0000-000000000001","date":\(date),"content":{"filme":{"id":"A1B2C3D4-0000-0000-0000-000000000002","idFilme":\(id),"title":"\(title)","image":"/abc.jpg","releaseDate":"2009-12-15","originalTitle":"2009-12-15","duration":162,"plot":"Plot","rating":7.5,"favorite":\(favorite),"watched":\(watched)}}}
        """
    }

    private func serie(_ id: Int, title: String = "Dark") -> String {
        """
        {"id":"A1B2C3D4-0000-0000-0000-000000000003","date":700000000,"content":{"serie":{"id":"A1B2C3D4-0000-0000-0000-000000000004","idFilme":\(id),"title":"\(title)","image":"","releaseDate":"2017-12-01","originalTitle":null,"duration":3,"plot":"Plot","rating":8.4,"favorite":false,"watched":false}}}
        """
    }

    private func set(_ defaults: UserDefaults, _ key: String, _ items: [String]) {
        defaults.set(Data("[\(items.joined(separator: ","))]".utf8), forKey: key)
    }

    @Test func importsAllContentWithFlagsFromListsAndItems() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1), movie(2), serie(3)])
        set(defaults, "favorites", [movie(1, favorite: true)])
        set(defaults, "watched", [movie(2, watched: true)])
        set(defaults, "history", [movie(1), serie(3)])

        let count = LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        #expect(count == 3)
        #expect(h.items.count == 3)
        let one = try #require(h.item("movie-1"))
        #expect(one.isFavorite && !one.isWatched && one.inHistory)
        let two = try #require(h.item("movie-2"))
        #expect(two.isWatched && !two.isFavorite && !two.inHistory)
        #expect(try #require(h.item("tv-3")).inHistory)
    }

    @Test func itemsOnlyPresentInFavoritesOrWatchedListsAreStillImported() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "favorites", [movie(7, favorite: true)])
        set(defaults, "watched", [movie(8, watched: true)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        #expect(try #require(h.item("movie-7")).isFavorite)
        #expect(try #require(h.item("movie-8")).isWatched)
    }

    @Test func mapsLegacyFieldsToTitle() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1), serie(3)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        let filmItem = try #require(h.item("movie-1"))
        let film = try #require(filmItem.snapshot)
        #expect(film.title == "Avatar")
        #expect(film.originalTitle == "Avatar")        // o campo legado guardava a data de lançamento
        #expect(film.year == 2009)
        #expect(film.posterPath == "/abc.jpg")
        #expect(film.runtimeMinutes == 162)
        #expect(film.seasons == nil)
        #expect(film.providers == .empty(region: "BR"))

        let showItem = try #require(h.item("tv-3"))
        let show = try #require(showItem.snapshot)
        #expect(show.seasons == 3)                      // `duration` de série era o nº de temporadas
        #expect(show.runtimeMinutes == nil)
        #expect(show.posterPath == nil)                 // imagem vazia
    }

    @Test func keepsTheLegacyDate() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1, date: 700_000_000)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        let date = try #require(h.item("movie-1")).recommendedAt
        #expect(date == Date(timeIntervalSinceReferenceDate: 700_000_000))
    }

    @Test func runsOnlyOnceAndRemovesLegacyKeys() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1)])

        let importer = LegacyImporter(defaults: defaults, store: h.store, region: "BR")
        #expect(importer.runIfNeeded() == 1)
        #expect(importer.runIfNeeded() == 0)
        #expect(h.items.count == 1)
        #expect(LegacyImporter.legacyKeys.allSatisfy { defaults.object(forKey: $0) == nil })
        #expect(defaults.bool(forKey: LegacyImporter.doneKey))
    }

    @Test func skipsCorruptElementsButImportsTheRest() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [#"{"nonsense":true}"#, movie(1)])

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 1)
    }

    @Test func noLegacyDataJustMarksDone() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 0)
        #expect(defaults.bool(forKey: LegacyImporter.doneKey))
    }

    @Test func undecodableDataIsKeptInsteadOfDeleted() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "allContent")

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 0)
        #expect(defaults.data(forKey: "allContent") != nil)
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/LegacyImporterTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'LegacyImporter' in scope`.

- [ ] **Step 3: Criar `FilmFinder/Data/LegacyImporter.swift`**

```swift
import Foundation

/// Converte os dados do app antigo (UserDefaults) para a biblioteca SwiftData, uma única vez.
@MainActor
struct LegacyImporter {
    static let doneKey = "legacyImportDone.v1"
    static let legacyKeys = ["allContent", "favorites", "watched", "history"]

    let defaults: UserDefaults
    let store: LibraryStore
    let region: String

    init(defaults: UserDefaults, store: LibraryStore, region: String = LocaleInfo().region) {
        self.defaults = defaults
        self.store = store
        self.region = region
    }

    @discardableResult
    func runIfNeeded() -> Int {
        guard !defaults.bool(forKey: Self.doneKey) else { return 0 }
        defaults.set(true, forKey: Self.doneKey)

        let hasLegacyData = Self.legacyKeys.contains { defaults.data(forKey: $0) != nil }
        guard hasLegacyData else { return 0 }

        var merged: [String: Merged] = [:]
        absorb(decodeList("allContent"), into: &merged)
        absorb(decodeList("favorites"), favorite: true, into: &merged)
        absorb(decodeList("watched"), watched: true, into: &merged)
        absorb(decodeList("history"), inHistory: true, into: &merged)

        for entry in merged.values {
            let item = store.upsert(entry.title)
            item.isFavorite = entry.favorite
            item.isWatched = entry.watched
            item.inHistory = entry.inHistory
            item.recommendedAt = entry.date
        }
        store.save()

        // Só apaga o legado se algo foi realmente importado.
        if !merged.isEmpty {
            Self.legacyKeys.forEach(defaults.removeObject(forKey:))
        }
        return merged.count
    }

    // MARK: - Mesclagem

    private struct Merged {
        var title: Title
        var date: Date
        var favorite: Bool
        var watched: Bool
        var inHistory: Bool
    }

    private func absorb(
        _ entries: [LegacyEntry],
        favorite: Bool = false,
        watched: Bool = false,
        inHistory: Bool = false,
        into merged: inout [String: Merged]
    ) {
        for entry in entries {
            let title = makeTitle(from: entry)
            let flags = entry.item
            if var existing = merged[title.id] {
                existing.favorite = existing.favorite || favorite || flags.favorite
                existing.watched = existing.watched || watched || flags.watched
                existing.inHistory = existing.inHistory || inHistory
                existing.date = max(existing.date, entry.date)
                merged[title.id] = existing
            } else {
                merged[title.id] = Merged(
                    title: title,
                    date: entry.date,
                    favorite: favorite || flags.favorite,
                    watched: watched || flags.watched,
                    inHistory: inHistory
                )
            }
        }
    }

    private func makeTitle(from entry: LegacyEntry) -> Title {
        let item = entry.item
        let type = entry.mediaType
        return Title(
            tmdbId: Int(item.idFilme),
            mediaType: type,
            title: item.title,
            originalTitle: item.title,
            year: Int(item.releaseDate.prefix(4)),
            overview: item.plot,
            posterPath: item.image.isEmpty ? nil : item.image,
            backdropPath: nil,
            rating: item.rating,
            runtimeMinutes: type == .movie && item.duration > 0 ? item.duration : nil,
            seasons: type == .tv ? item.duration : nil,
            genres: [],
            reason: "",
            providers: .empty(region: region)
        )
    }

    // MARK: - Decodificação do formato legado

    private func decodeList(_ key: String) -> [LegacyEntry] {
        guard let data = defaults.data(forKey: key),
              let lossy = try? JSONDecoder().decode([Lossy<LegacyEntry>].self, from: data)
        else { return [] }
        return lossy.compactMap(\.value)
    }

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    private struct LegacyItem: Decodable {
        let idFilme: Int32
        let title: String
        let image: String
        let releaseDate: String
        let duration: Int
        let plot: String
        let rating: Double
        let favorite: Bool
        let watched: Bool
    }

    private struct LegacyEntry: Decodable {
        let date: Date
        private let content: Content

        private struct Content: Decodable {
            let filme: LegacyItem?
            let serie: LegacyItem?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(Date.self, forKey: .date)
            content = try container.decode(Content.self, forKey: .content)
            guard content.filme != nil || content.serie != nil else {
                throw DecodingError.dataCorruptedError(forKey: .content, in: container, debugDescription: "Empty content")
            }
        }

        private enum CodingKeys: String, CodingKey { case date, content }

        var mediaType: MediaType { content.filme != nil ? .movie : .tv }
        var item: LegacyItem { content.filme ?? content.serie! }
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS.

- [ ] **Step 5: Commit**

```bash
git add FilmFinder/Data/LegacyImporter.swift FilmFinderTests
git commit -m "feat(ios): import legacy UserDefaults history/favorites/watched into SwiftData"
```

---

### Task iOS-7: Montador de consulta por categorias e `ResultsModel` (buffer)

**Files:**
- Create: `FilmFinder/Features/Search/CategoryQueryBuilder.swift`, `FilmFinder/Features/Results/ResultsModel.swift`
- Test: `FilmFinderTests/CategoryQueryBuilderTests.swift`, `FilmFinderTests/ResultsModelTests.swift`

**Interfaces:**
- Consumes: `RecommendationService`, `APIError` (Task iOS-3); `RecommendationRequest`, `RecommendationsResponse`, `Quota`, `LocaleInfo`, `Title`, `MediaType` (Task iOS-2); `LibraryStore` (Task iOS-5)
- Produces:
  - `enum CategoryQueryBuilder { static func query(mediaType: MediaType, moods: [String], genres: [String], themes: [String]) -> String? }` (máx. 500 caracteres; `nil` se nada selecionado)
  - `@MainActor @Observable final class ResultsModel { enum Phase: Equatable { idle, loading, loaded, empty, failed(APIError) }; static let visibleCount = 3; let mediaType; let query; private(set) var phase, visible, buffer, isSwapping, swapError: APIError?; init(mediaType:query:service:store:localeInfo:onQuota:) (`onQuota` é chamado com a cota de cada resposta); func load() async; func retry() async; func swap(_ title: Title) async }`

- [ ] **Step 1: Escrever os testes do montador — `FilmFinderTests/CategoryQueryBuilderTests.swift`**

```swift
import Testing
@testable import FilmFinder

@Suite struct CategoryQueryBuilderTests {
    @Test func returnsNilWhenNothingIsSelected() {
        #expect(CategoryQueryBuilder.query(mediaType: .movie, moods: [], genres: [], themes: []) == nil)
    }

    @Test func buildsOnlyTheSelectedParts() {
        let q = CategoryQueryBuilder.query(mediaType: .movie, moods: [], genres: ["Drama", "Romance"], themes: [])
        #expect(q == "I want to watch a movie. Genres: Drama, Romance.")
    }

    @Test func buildsAllPartsForSeries() {
        let q = CategoryQueryBuilder.query(mediaType: .tv, moods: ["Relaxado"], genres: ["Suspense"], themes: ["Crime", "Enigmas"])
        #expect(q == "I want to watch a TV series. Mood: Relaxado. Genres: Suspense. Themes: Crime, Enigmas.")
    }

    @Test func neverExceedsTheBackendLimit() {
        let many = (0..<80).map { "Categoria número \($0)" }
        let q = CategoryQueryBuilder.query(mediaType: .movie, moods: many, genres: many, themes: many)
        #expect((q?.count ?? 0) <= 500)
    }
}
```

- [ ] **Step 2: Escrever os testes do modelo — `FilmFinderTests/ResultsModelTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

final class FakeService: RecommendationService, @unchecked Sendable {
    var results: [Result<[Title], APIError>]
    var quota: Quota? = Quota(used: 1, limit: 5, resetsAt: Date(timeIntervalSince1970: 1_791_244_800))
    private(set) var requests: [RecommendationRequest] = []

    init(_ results: [Result<[Title], APIError>]) { self.results = results }

    func recommend(_ request: RecommendationRequest) async throws -> RecommendationsResponse {
        requests.append(request)
        guard !results.isEmpty else { return RecommendationsResponse(titles: [], quota: quota) }
        return RecommendationsResponse(titles: try results.removeFirst().get(), quota: quota)
    }
}

private func titles(_ ids: ClosedRange<Int>, type: MediaType = .movie) -> [Title] {
    ids.map { Title.sample(id: $0, type: type, title: "T\($0)") }
}

@MainActor
@Suite struct ResultsModelTests {
    private func makeModel(
        _ service: FakeService, harness: LibraryHarness, type: MediaType = .movie,
        onQuota: (@MainActor (Quota) -> Void)? = nil
    ) -> ResultsModel {
        ResultsModel(
            mediaType: type, query: "algo leve", service: service, store: harness.store,
            localeInfo: LocaleInfo(locale: "pt-BR", region: "BR"), onQuota: onQuota
        )
    }

    @Test func loadShowsThreeAndBuffersTheRest() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])
        let model = makeModel(service, harness: h)

        await model.load()

        #expect(model.phase == .loaded)
        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.buffer.count == 9)
        #expect(service.requests.count == 1)
    }

    @Test func sendsLocaleRegionAndExclusionsOfTheSameMediaType() async throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 50, type: .movie), .sample(id: 60, type: .tv)])
        let service = FakeService([.success(titles(1...5))])

        await makeModel(service, harness: h).load()

        let sent = try #require(service.requests.first)
        #expect(sent.query == "algo leve")
        #expect(sent.mediaType == .movie)
        #expect(sent.locale == "pt-BR")
        #expect(sent.region == "BR")
        #expect(sent.excludeTmdbIds == [50])
    }

    @Test func recordsAllTitlesButOnlyShownOnesEnterHistory() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])

        await makeModel(service, harness: h).load()

        #expect(h.items.count == 12)
        #expect(h.items.filter(\.inHistory).count == 3)
        #expect(h.store.excludedIDs(for: .movie).count == 12)
    }

    @Test func swapUsesTheBufferWithoutANewRequest() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[1])

        #expect(model.visible.map(\.tmdbId) == [1, 4, 3])
        #expect(model.buffer.count == 8)
        #expect(service.requests.count == 1)
        #expect(try #require(h.item("movie-4")).inHistory)
    }

    @Test func swapWithEmptyBufferFetchesAgainExcludingRecordedTitles() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .success(titles(10...14))])
        let model = makeModel(service, harness: h)
        await model.load()
        #expect(model.buffer.isEmpty)

        await model.swap(model.visible[0])

        #expect(service.requests.count == 2)
        #expect(Set(service.requests[1].excludeTmdbIds) == [1, 2, 3])
        #expect(model.visible.map(\.tmdbId) == [10, 2, 3])
        #expect(model.buffer.map(\.tmdbId) == [11, 12, 13, 14])
    }

    @Test func swapFailureKeepsTheVisibleTitlesAndReportsTheError() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .failure(.offline)])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[0])

        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.swapError == .offline)
        #expect(model.phase == .loaded)
    }

    @Test func swapWithNothingNewLeavesTheCardInPlace() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .success([])])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[0])

        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.swapError == nil)
    }

    @Test func reportsTheQuotaOfEveryResponse() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .success(titles(10...12))])
        var seen: [Int] = []
        let model = makeModel(service, harness: h) { seen.append($0.used) }

        await model.load()
        service.quota = Quota(used: 2, limit: 5, resetsAt: Date(timeIntervalSince1970: 1_791_244_800))
        await model.swap(model.visible[0])

        #expect(seen == [1, 2])
    }

    @Test func emptyResponseIsTheEmptyPhase() async throws {
        let h = try LibraryHarness()
        let model = makeModel(FakeService([.success([])]), harness: h)
        await model.load()
        #expect(model.phase == .empty)
    }

    @Test func failureThenRetrySucceeds() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.failure(.serviceUnavailable), .success(titles(1...4))])
        let model = makeModel(service, harness: h)

        await model.load()
        #expect(model.phase == .failed(.serviceUnavailable))

        await model.retry()
        #expect(model.phase == .loaded)
        #expect(model.visible.count == 3)
    }

    @Test func loadRunsOnlyOnce() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...5)), .success(titles(6...9))])
        let model = makeModel(service, harness: h)

        await model.load()
        await model.load()

        #expect(service.requests.count == 1)
    }
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/ResultsModelTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'ResultsModel' in scope`.

- [ ] **Step 4: Criar `FilmFinder/Features/Search/CategoryQueryBuilder.swift`**

```swift
import Foundation

enum CategoryQueryBuilder {
    private static let maxLength = 500

    /// Monta o pedido em linguagem natural a partir das categorias escolhidas.
    /// Os nomes das categorias vão como estão (o modelo entende português e inglês).
    static func query(mediaType: MediaType, moods: [String], genres: [String], themes: [String]) -> String? {
        guard !(moods.isEmpty && genres.isEmpty && themes.isEmpty) else { return nil }
        var parts = ["I want to watch \(mediaType == .movie ? "a movie" : "a TV series")."]
        if !moods.isEmpty { parts.append("Mood: \(moods.joined(separator: ", ")).") }
        if !genres.isEmpty { parts.append("Genres: \(genres.joined(separator: ", ")).") }
        if !themes.isEmpty { parts.append("Themes: \(themes.joined(separator: ", ")).") }
        return String(parts.joined(separator: " ").prefix(maxLength))
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Features/Results/ResultsModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ResultsModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(APIError)
    }

    static let visibleCount = 3

    let mediaType: MediaType
    let query: String

    private(set) var phase: Phase = .idle
    private(set) var visible: [Title] = []
    private(set) var buffer: [Title] = []
    private(set) var isSwapping = false
    private(set) var swapError: APIError?

    private let service: any RecommendationService
    private let store: LibraryStore
    private let localeInfo: LocaleInfo
    private let onQuota: (@MainActor (Quota) -> Void)?

    init(
        mediaType: MediaType,
        query: String,
        service: any RecommendationService,
        store: LibraryStore,
        localeInfo: LocaleInfo = LocaleInfo(),
        onQuota: (@MainActor (Quota) -> Void)? = nil
    ) {
        self.mediaType = mediaType
        self.query = query
        self.service = service
        self.store = store
        self.localeInfo = localeInfo
        self.onQuota = onQuota
    }

    /// Busca inicial. Só age no estado `.idle` (a view pode chamar de novo ao reaparecer).
    func load() async {
        guard phase == .idle else { return }
        phase = .loading
        do {
            let titles = try await fetch()
            guard !titles.isEmpty else {
                phase = .empty
                return
            }
            visible = Array(titles.prefix(Self.visibleCount))
            buffer = Array(titles.dropFirst(Self.visibleCount))
            visible.forEach { store.markShown($0) }
            phase = .loaded
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(Self.apiError(from: error))
        }
    }

    func retry() async {
        phase = .idle
        await load()
    }

    /// Troca um card pelo próximo do buffer; sem buffer, faz uma nova busca (consome cota no servidor).
    func swap(_ title: Title) async {
        guard !isSwapping, let index = visible.firstIndex(of: title) else { return }
        isSwapping = true
        swapError = nil
        defer { isSwapping = false }

        if buffer.isEmpty {
            do {
                buffer = try await fetch()
            } catch is CancellationError {
                return
            } catch {
                swapError = Self.apiError(from: error)
                return
            }
        }
        guard !buffer.isEmpty else { return }
        let next = buffer.removeFirst()
        visible[index] = next
        store.markShown(next)
    }

    private func fetch() async throws -> [Title] {
        let request = RecommendationRequest(
            query: query,
            mediaType: mediaType,
            excludeTmdbIds: store.excludedIDs(for: mediaType),
            locale: localeInfo.locale,
            region: localeInfo.region
        )
        let response = try await service.recommend(request)
        if let quota = response.quota { onQuota?(quota) }
        let titles = response.titles
        let onScreen = Set(visible.map(\.id))
        let fresh = titles.filter { !onScreen.contains($0.id) }
        store.recordRecommended(fresh)
        return fresh
    }

    private static func apiError(from error: Error) -> APIError {
        (error as? APIError) ?? .server(error.localizedDescription)
    }
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS.

- [ ] **Step 7: Commit**

```bash
git add FilmFinder/Features FilmFinderTests
git commit -m "feat(ios): add ResultsModel with 3-card buffer and category query builder"
```

---

### Task iOS-8: Conta e cota — `AccountService` e `AccountModel`

**Files:**
- Create: `FilmFinder/Domain/Hashing.swift`, `FilmFinder/Domain/Account.swift`
- Create: `FilmFinder/Core/API/AccountService.swift`
- Create: `FilmFinder/Features/Account/AccountModel.swift`
- Test: `FilmFinderTests/AccountModelTests.swift`

**Interfaces:**
- Consumes: `AuthorizedAPI`, `HTTPTransport`, `OKResponse`, `APIError` (Task iOS-3); `Quota` (Task iOS-2)
- Produces:
  - `func sha256Hex(_ text: String) -> String`
  - `struct MeResponse: Decodable, Equatable, Sendable { struct User { let id: String }; let user: User?; let entitlements: [String]; let quota: Quota }`
  - `protocol AccountService: Sendable { func challenge() async throws -> String; func me() async throws -> MeResponse; func signIn(identityToken: String, authorizationCode: String, challenge: String) async throws -> MeResponse; func signOut() async throws; func deleteAccount() async throws }`; `struct APIAccountService: AccountService { init(transport: HTTPTransport, api: AuthorizedAPI) }`
  - `@MainActor @Observable final class AccountModel { private(set) var quota: Quota?; private(set) var isSignedIn: Bool; private(set) var isBusy: Bool; private(set) var lastError: APIError?; var signInNonce: String? (SHA-256 hex do desafio pendente); init(service:); func refresh() async; func update(quota: Quota); func prepareSignIn() async; func completeSignIn(identityToken:authorizationCode:) async; func signOut() async; func deleteAccount() async; func clearError() }`

- [ ] **Step 1: Escrever os testes que falham — `FilmFinderTests/AccountModelTests.swift`**

```swift
import Foundation
import Testing
@testable import FilmFinder

private let quota = Quota(used: 2, limit: 5, resetsAt: Date(timeIntervalSince1970: 1_791_244_800))

final class FakeAccountService: AccountService, @unchecked Sendable {
    var meResults: [Result<MeResponse, APIError>] = []
    var signInResult: Result<MeResponse, APIError> = .success(MeResponse(user: .init(id: "u1"), entitlements: [], quota: quota))
    var challenges = ["c1", "c2", "c3"]
    var signOutError: APIError?
    var deleteError: APIError?
    private(set) var signInCalls: [(token: String, code: String, challenge: String)] = []
    private(set) var signOutCalls = 0
    private(set) var deleteCalls = 0

    func challenge() async throws -> String { challenges.removeFirst() }

    func me() async throws -> MeResponse {
        guard !meResults.isEmpty else { return MeResponse(user: nil, entitlements: [], quota: quota) }
        return try meResults.removeFirst().get()
    }

    func signIn(identityToken: String, authorizationCode: String, challenge: String) async throws -> MeResponse {
        signInCalls.append((identityToken, authorizationCode, challenge))
        return try signInResult.get()
    }

    func signOut() async throws {
        signOutCalls += 1
        if let signOutError { throw signOutError }
    }

    func deleteAccount() async throws {
        deleteCalls += 1
        if let deleteError { throw deleteError }
    }
}

@Suite struct HashingTests {
    @Test func sha256HexMatchesTheKnownVector() {
        #expect(sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

@MainActor
@Suite struct AccountModelTests {
    @Test func refreshLoadsQuotaAndSignedInState() async {
        let service = FakeAccountService()
        service.meResults = [.success(MeResponse(user: .init(id: "u1"), entitlements: ["unlimited_search"], quota: quota))]
        let model = AccountModel(service: service)

        await model.refresh()

        #expect(model.isSignedIn)
        #expect(model.quota == quota)
        #expect(model.quota?.remaining == 3)
        #expect(model.lastError == nil)
    }

    @Test func refreshFailureKeepsThePreviousStateAndReportsTheError() async {
        let service = FakeAccountService()
        service.meResults = [.success(MeResponse(user: nil, entitlements: [], quota: quota)), .failure(.offline)]
        let model = AccountModel(service: service)
        await model.refresh()

        await model.refresh()

        #expect(model.quota == quota)
        #expect(model.lastError == .offline)
    }

    @Test func updateQuotaReplacesTheCurrentValue() {
        let model = AccountModel(service: FakeAccountService())
        model.update(quota: quota)
        #expect(model.quota == quota)
    }

    @Test func prepareSignInExposesTheHashedChallengeAsNonce() async {
        let service = FakeAccountService()
        let model = AccountModel(service: service)
        #expect(model.signInNonce == nil)

        await model.prepareSignIn()

        #expect(model.signInNonce == sha256Hex("c1"))
    }

    @Test func completeSignInSendsTheChallengeAndPreparesANewOne() async {
        let service = FakeAccountService()
        let model = AccountModel(service: service)
        await model.prepareSignIn()

        await model.completeSignIn(identityToken: "idt", authorizationCode: "code")

        #expect(service.signInCalls.count == 1)
        #expect(service.signInCalls.first?.challenge == "c1")
        #expect(service.signInCalls.first?.token == "idt")
        #expect(service.signInCalls.first?.code == "code")
        #expect(model.isSignedIn)
        #expect(model.signInNonce == sha256Hex("c2"))
        #expect(!model.isBusy)
    }

    @Test func completeSignInWithoutPreparationFails() async {
        let service = FakeAccountService()
        let model = AccountModel(service: service)

        await model.completeSignIn(identityToken: "idt", authorizationCode: "code")

        #expect(service.signInCalls.isEmpty)
        #expect(model.lastError != nil)
        #expect(!model.isSignedIn)
    }

    @Test func signInFailureReportsTheErrorAndStillPreparesANewChallenge() async {
        let service = FakeAccountService()
        service.signInResult = .failure(.unauthorized)
        let model = AccountModel(service: service)
        await model.prepareSignIn()

        await model.completeSignIn(identityToken: "idt", authorizationCode: "code")

        #expect(model.lastError == .unauthorized)
        #expect(!model.isSignedIn)
        #expect(model.signInNonce == sha256Hex("c2"))
    }

    @Test func signOutCallsTheServiceAndRefreshes() async {
        let service = FakeAccountService()
        service.meResults = [
            .success(MeResponse(user: .init(id: "u1"), entitlements: [], quota: quota)),
            .success(MeResponse(user: nil, entitlements: [], quota: quota)),
        ]
        let model = AccountModel(service: service)
        await model.refresh()
        #expect(model.isSignedIn)

        await model.signOut()

        #expect(service.signOutCalls == 1)
        #expect(!model.isSignedIn)
    }

    @Test func deleteAccountCallsTheServiceAndRefreshes() async {
        let service = FakeAccountService()
        service.meResults = [
            .success(MeResponse(user: .init(id: "u1"), entitlements: [], quota: quota)),
            .success(MeResponse(user: nil, entitlements: [], quota: quota)),
        ]
        let model = AccountModel(service: service)
        await model.refresh()

        await model.deleteAccount()

        #expect(service.deleteCalls == 1)
        #expect(!model.isSignedIn)
    }

    @Test func deleteFailureKeepsTheUserSignedInAndReportsTheError() async {
        let service = FakeAccountService()
        service.deleteError = .server("apple_unavailable")
        service.meResults = [.success(MeResponse(user: .init(id: "u1"), entitlements: [], quota: quota))]
        let model = AccountModel(service: service)
        await model.refresh()

        await model.deleteAccount()

        #expect(model.isSignedIn)
        #expect(model.lastError == .server("apple_unavailable"))
    }

    @Test func clearErrorResetsTheLastError() async {
        let service = FakeAccountService()
        service.meResults = [.failure(.offline)]
        let model = AccountModel(service: service)
        await model.refresh()
        model.clearError()
        #expect(model.lastError == nil)
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests/AccountModelTests 2>&1 | grep -E "error:" | head -3`
Expected: FAIL de compilação — `cannot find 'AccountModel' in scope`.

- [ ] **Step 3: Criar `FilmFinder/Domain/Hashing.swift`**

```swift
import CryptoKit
import Foundation

func sha256Hex(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
}
```

- [ ] **Step 4: Criar `FilmFinder/Domain/Account.swift`**

```swift
import Foundation

struct MeResponse: Decodable, Equatable, Sendable {
    struct User: Decodable, Equatable, Sendable {
        let id: String
    }

    let user: User?
    let entitlements: [String]
    let quota: Quota
}
```

- [ ] **Step 5: Criar `FilmFinder/Core/API/AccountService.swift`**

```swift
import Foundation

protocol AccountService: Sendable {
    func challenge() async throws -> String
    func me() async throws -> MeResponse
    func signIn(identityToken: String, authorizationCode: String, challenge: String) async throws -> MeResponse
    func signOut() async throws
    func deleteAccount() async throws
}

struct APIAccountService: AccountService {
    let transport: HTTPTransport
    let api: AuthorizedAPI

    private struct SignInBody: Encodable, Sendable {
        let identityToken: String
        let authorizationCode: String
        let challenge: String
    }

    func challenge() async throws -> String {
        try await transport.fetchChallenge()
    }

    func me() async throws -> MeResponse {
        try await api.send("GET", "v1/me")
    }

    func signIn(identityToken: String, authorizationCode: String, challenge: String) async throws -> MeResponse {
        try await api.send(
            "POST", "v1/auth/apple",
            body: SignInBody(identityToken: identityToken, authorizationCode: authorizationCode, challenge: challenge)
        )
    }

    func signOut() async throws {
        let _: OKResponse = try await api.send("POST", "v1/auth/logout")
    }

    func deleteAccount() async throws {
        let _: OKResponse = try await api.send("DELETE", "v1/me")
    }
}
```

- [ ] **Step 6: Criar `FilmFinder/Features/Account/AccountModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AccountModel {
    private(set) var quota: Quota?
    private(set) var isSignedIn = false
    private(set) var isBusy = false
    private(set) var lastError: APIError?
    private(set) var pendingChallenge: String?

    private let service: any AccountService

    init(service: any AccountService) {
        self.service = service
    }

    /// Valor para `request.nonce` do Sign in with Apple: o hash do desafio do servidor.
    var signInNonce: String? {
        pendingChallenge.map(sha256Hex)
    }

    func refresh() async {
        do {
            apply(try await service.me())
        } catch is CancellationError {
            return
        } catch {
            lastError = Self.apiError(from: error)
        }
    }

    func update(quota: Quota) {
        self.quota = quota
    }

    /// Busca o desafio que será embutido no `nonce` antes de abrir a folha do Sign in with Apple.
    func prepareSignIn() async {
        pendingChallenge = try? await service.challenge()
    }

    func completeSignIn(identityToken: String, authorizationCode: String) async {
        guard let challenge = pendingChallenge else {
            lastError = .invalidInput("Sign-in was not prepared")
            return
        }
        pendingChallenge = nil
        isBusy = true
        defer { isBusy = false }
        do {
            apply(try await service.signIn(identityToken: identityToken, authorizationCode: authorizationCode, challenge: challenge))
        } catch is CancellationError {
            // sem estado a atualizar
        } catch {
            lastError = Self.apiError(from: error)
        }
        await prepareSignIn() // o desafio é de uso único: prepara o próximo
    }

    func signOut() async {
        await perform { try await self.service.signOut() }
    }

    func deleteAccount() async {
        await perform { try await self.service.deleteAccount() }
    }

    func clearError() {
        lastError = nil
    }

    private func perform(_ action: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
            await refresh()
            await prepareSignIn()
        } catch is CancellationError {
            return
        } catch {
            lastError = Self.apiError(from: error)
        }
    }

    private func apply(_ me: MeResponse) {
        isSignedIn = me.user != nil
        quota = me.quota
        lastError = nil
    }

    private static func apiError(from error: Error) -> APIError {
        (error as? APIError) ?? .server(error.localizedDescription)
    }
}
```

- [ ] **Step 7: Rodar e ver passar**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FilmFinderTests 2>&1 | grep -E "error:|Test run|passed|failed" | tail -5`
Expected: todos PASS. (O teste `signOutCallsTheServiceAndRefreshes` consome 2 desafios em `prepareSignIn` — o `FakeAccountService` tem 3.)

- [ ] **Step 8: Commit**

```bash
git add FilmFinder FilmFinderTests
git commit -m "feat(ios): add account service and AccountModel (quota, sign-in nonce, sign-out, delete)"
```

### Task iOS-9: Fundação da UI — ambiente, app e componentes compartilhados

A partir daqui as tarefas são de interface: a verificação é **compilar** e, nas as tarefas iOS-10 a iOS-13, **ver no simulador**.

**Files:**
- Rename: `FilmFinder/CimemAIApp.swift` → `FilmFinder/App/FilmFinderApp.swift` (reescrito)
- Create: `FilmFinder/App/AppEnvironment.swift`
- Create: `FilmFinder/Features/Shared/PosterImage.swift`, `StarsView.swift`, `ProviderLogos.swift`, `ErrorStateView.swift`, `LoadingStateView.swift`, `CustomDivider.swift`, `MediaType+UI.swift`

**Interfaces:**
- Consumes: `APIClient`, `AuthorizedAPI`, `HTTPTransport`, `APIConfig`, `RecommendationService`, `APIError` (Task iOS-3); `AuthService`, `KeychainSecretStore`, `DeviceAppAttest` (Task iOS-4); `AccountModel`, `APIAccountService` (Task iOS-8); `LibraryItem`, `LibraryStore` (Task iOS-5); `LegacyImporter` (Task iOS-6); `Title`, `StreamingProvider`, `TMDBImage` (Task iOS-2)
- Produces:
  - `@MainActor @Observable final class AppEnvironment { let service: any RecommendationService; let account: AccountModel; static func live() -> AppEnvironment }` (injetado com `.environment(_:)`; lido com `@Environment(AppEnvironment.self)`)
  - `PosterImage(path: String?)`, `StarsView(stars: Int, color: Color, size: CGFloat)`, `ProviderLogoView(provider:size:)`, `ProviderLogosRow(providers:)`
  - `enum ErrorKind { noResults, offline, serviceUnavailable, quotaExceeded, generic; init(_ error: APIError) }`, `ErrorStateView(kind: ErrorKind, onRetry: (() -> Void)?)`
  - `LoadingStateView()`, `CustomDivider(color:width:)`
  - `extension MediaType { var pluralName: LocalizedStringKey; var pluralNameString: String }`

- [ ] **Step 1: Mover o ponto de entrada**

Run: `mkdir -p FilmFinder/App && git mv FilmFinder/CimemAIApp.swift FilmFinder/App/FilmFinderApp.swift`

- [ ] **Step 2: Criar `FilmFinder/App/AppEnvironment.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let service: any RecommendationService
    let account: AccountModel

    init(service: any RecommendationService, account: AccountModel) {
        self.service = service
        self.account = account
    }

    /// Monta os serviços reais: transporte HTTP, identidade do dispositivo (Keychain + App Attest) e conta.
    /// Se `APIBaseURL` estiver ausente, usa um endereço inválido: qualquer busca falha com erro de rede.
    static func live() -> AppEnvironment {
        let baseURL = (try? APIConfig.live().baseURL) ?? URL(string: "https://invalid.invalid")!
        let transport = HTTPTransport(baseURL: baseURL)
        let auth = AuthService(transport: transport, secrets: KeychainSecretStore(), attest: DeviceAppAttest())
        let api = AuthorizedAPI(transport: transport, tokens: auth)
        return AppEnvironment(
            service: APIClient(api: api),
            account: AccountModel(service: APIAccountService(transport: transport, api: api))
        )
    }
}
```

- [ ] **Step 3: Reescrever `FilmFinder/App/FilmFinderApp.swift`**

```swift
import SwiftData
import SwiftUI

@main
struct FilmFinderApp: App {
    @State private var environment = AppEnvironment.live()
    private let container: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: LibraryItem.self)
        } catch {
            fatalError("Could not create the library database: \(error)")
        }
        self.container = container
        LegacyImporter(defaults: .standard, store: LibraryStore(context: container.mainContext)).runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            InicialLoading()
                .preferredColorScheme(.dark)
                .environment(environment)
                .modelContainer(container)
        }
    }
}
```

- [ ] **Step 4: Criar `FilmFinder/Features/Shared/PosterImage.swift`**

```swift
import SwiftUI

struct PosterImage: View {
    let path: String?

    var body: some View {
        if let url = TMDBImage.poster(path) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                default:
                    ZStack {
                        Color.cinza2
                        ProgressView()
                    }
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.cinza2
            Image("error")
                .resizable()
                .scaledToFit()
                .padding(24)
        }
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Features/Shared/StarsView.swift`**

```swift
import SwiftUI

struct StarsView: View {
    let stars: Int
    var color: Color = .white
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) / 5")
    }
}
```

- [ ] **Step 6: Criar `FilmFinder/Features/Shared/ProviderLogos.swift`**

```swift
import SwiftUI

struct ProviderLogoView: View {
    let provider: StreamingProvider
    var size: CGFloat = 28

    var body: some View {
        AsyncImage(url: TMDBImage.logo(provider.logoPath)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Color.cinza2
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .accessibilityLabel(provider.name)
    }
}

struct ProviderLogosRow: View {
    let providers: [StreamingProvider]
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 6) {
            ForEach(providers) { provider in
                ProviderLogoView(provider: provider, size: size)
            }
        }
    }
}
```

- [ ] **Step 7: Criar `FilmFinder/Features/Shared/LoadingStateView.swift`** (extraído do `ChatGptView`)

```swift
import SwiftUI

struct LoadingStateView: View {
    var body: some View {
        VStack {
            (Text("Encontrando as opções mais")
                .foregroundColor(Color("branco"))
                + Text(" compatíveis ")
                .foregroundColor(Color("laranja"))
                + Text("com você")
                .foregroundColor(Color("branco")))
                .fontWidth(.expanded)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            LottieView(name: "pipocascertasmesmo", loopMode: .loop, animationSpeed: 2)
                .frame(width: 250, height: 112)
                .scaleEffect(0.8)
                .padding(.bottom, 60)
        }
    }
}
```

- [ ] **Step 8: Criar `FilmFinder/Features/Shared/ErrorStateView.swift`** (substitui o `ErrorView` antigo)

```swift
import SwiftUI

enum ErrorKind {
    case noResults
    case offline
    case serviceUnavailable
    case quotaExceeded
    case generic

    init(_ error: APIError) {
        switch error {
        case .offline: self = .offline
        case .serviceUnavailable: self = .serviceUnavailable
        case .quotaExceeded: self = .quotaExceeded
        default: self = .generic
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .noResults: "Não encontramos nada..."
        case .offline: "Sem conexão"
        case .serviceUnavailable: "Serviço indisponível no momento"
        case .quotaExceeded: "Suas buscas de hoje acabaram"
        case .generic: "Algo deu errado"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .noResults: "Tente novamente mais tarde ou descreva algo diferente"
        case .offline: "Verifique sua internet e tente novamente"
        case .serviceUnavailable: "Estamos com instabilidade. Tente novamente em instantes"
        case .quotaExceeded: "Volte amanhã para novas recomendações"
        case .generic: "Tente novamente"
        }
    }
}

struct ErrorStateView: View {
    let kind: ErrorKind
    var onRetry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            Image("onboardingTop")
                .padding()

            Image("error")
                .padding(.bottom, 2)
                .padding(.top, 20)

            VStack {
                Text(kind.title)
                    .foregroundColor(Color("branco"))
                    .fontWeight(.bold)
                    .padding(.bottom)

                Text(kind.message)
                    .foregroundColor(Color("branco"))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
            }
            .padding(.vertical)
            .padding(.horizontal, 32)

            if let onRetry {
                Button(action: onRetry) {
                    Text("Tentar de novo")
                        .font(.system(size: 17))
                        .fontWeight(.bold)
                        .foregroundColor(Color("preto"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color("laranja"))
                        .cornerRadius(16)
                }
            }

            Button {
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "chevron.backward")
                    Text("Voltar")
                }
                .font(.system(size: 20))
                .fontWeight(.bold)
                .foregroundColor(Color("laranja"))
            }
            .padding(.vertical, 8)

            Spacer()
        }
    }
}
```

- [ ] **Step 9: Criar `FilmFinder/Features/Shared/CustomDivider.swift`** (movido do `HistoryView`)

```swift
import SwiftUI

struct CustomDivider: View {
    let color: Color
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: width)
            .edgesIgnoringSafeArea(.horizontal)
    }
}
```

- [ ] **Step 10: Remover a definição antiga de `CustomDivider` do `FilmFinder/View/HistoryView.swift`** (apagar o `struct CustomDivider: View { ... }` inteiro, linhas ~70–80 do arquivo antigo; a view antiga continua compilando usando o novo).

- [ ] **Step 11: Criar `FilmFinder/Features/Shared/MediaType+UI.swift`**

```swift
import SwiftUI

extension MediaType {
    var pluralName: LocalizedStringKey {
        switch self {
        case .movie: "Filmes"
        case .tv: "Séries"
        }
    }

    var pluralNameString: String {
        switch self {
        case .movie: String(localized: "Filmes")
        case .tv: String(localized: "Séries")
        }
    }
}
```

- [ ] **Step 12: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`. (O código antigo ainda existe e compila; `InicialLoading` continua sendo a raiz.)

- [ ] **Step 13: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): add app environment, SwiftData container wiring and shared UI components"
```

---

### Task iOS-10: Resultados, card, detalhe e streaming

**Files:**
- Create: `FilmFinder/Features/Results/TitleCard.swift`, `FilmFinder/Features/Results/ResultsView.swift`
- Create: `FilmFinder/Features/Detail/TitleDetail.swift`, `FilmFinder/Features/Detail/StreamingSection.swift`

**Interfaces:**
- Consumes: `ResultsModel` (Task iOS-7); `AppEnvironment` (Task iOS-9); `LibraryStore`, `LibraryItem` (Task iOS-5); componentes compartilhados (Task iOS-9); `Title`, `Providers` (Task iOS-2)
- Produces: `ResultsView(mediaType: MediaType, query: String)` (destino de navegação para a busca); `TitleCard(title:)`; `TitleDetail(title:)`; `StreamingSection(providers:)`

- [ ] **Step 1: Criar `FilmFinder/Features/Detail/StreamingSection.swift`**

```swift
import SwiftUI

struct StreamingSection: View {
    let providers: Providers

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Onde assistir")
                .font(.system(size: 18, weight: .semibold))
                .fontWidth(.expanded)
                .foregroundColor(.branco)

            if providers.isEmpty {
                Text("Não disponível em streaming na sua região")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                group("Assinatura", providers.flatrate)
                group("Grátis", providers.free)
                group("Aluguel", providers.rent)
                group("Compra", providers.buy)

                if let link = providers.link {
                    Link(destination: link) {
                        HStack {
                            Text("Ver onde assistir")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.preto)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.laranja)
                        .cornerRadius(14)
                    }
                }
            }

            Text("Dados de streaming: JustWatch")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func group(_ heading: LocalizedStringKey, _ list: [StreamingProvider]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(heading)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(list) { provider in
                            VStack(spacing: 4) {
                                ProviderLogoView(provider: provider, size: 44)
                                Text(provider.name)
                                    .font(.system(size: 10))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 60)
                            }
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Criar `FilmFinder/Features/Detail/TitleDetail.swift`**

```swift
import SwiftData
import SwiftUI

struct TitleDetail: View {
    let title: Title

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [LibraryItem]

    init(title: Title) {
        self.title = title
        let key = title.id
        _items = Query(filter: #Predicate<LibraryItem> { $0.libraryKey == key })
    }

    private var item: LibraryItem? { items.first }
    private var isFavorite: Bool { item?.isFavorite ?? false }
    private var isWatched: Bool { item?.isWatched ?? false }
    private var store: LibraryStore { LibraryStore(context: modelContext) }

    var body: some View {
        ScrollView {
            VStack(spacing: -25) {
                PosterImage(path: title.posterPath)
                    .frame(maxWidth: .infinity)
                    .frame(height: 560)
                    .clipped()

                VStack(alignment: .leading, spacing: 19) {
                    header
                    chips
                    if !title.genres.isEmpty { genres }
                    if !title.reason.isEmpty { reason }
                    Text(title.overview)
                        .font(.system(size: 16))
                        .padding(.horizontal, 30)
                    StreamingSection(providers: title.providers)
                        .padding(.horizontal, 30)
                    Spacer(minLength: 24)
                }
                .padding(.top, 8)
                .background(Color.preto, in: RoundedRectangle(cornerRadius: 28))
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { BackButton() }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.title)
                    .font(.system(size: 24))
                    .foregroundColor(.branco)
                    .fontWeight(.semibold)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StarsView(stars: title.stars, color: .laranja)
            }

            Button {
                store.setFavorite(title, !isFavorite)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 23))
                    .foregroundColor(isFavorite ? .laranja : .branco)
            }
            .accessibilityLabel(isFavorite ? "Remover dos favoritos" : "Favoritar")

            Button {
                store.setWatched(title, !isWatched)
            } label: {
                Image(isWatched ? "Olhozin" : "Olhozin.fill")
                    .resizable()
                    .frame(width: 40, height: 25)
                    .scaledToFit()
            }
            .accessibilityLabel(isWatched ? "Desmarcar como assistido" : "Marcar como assistido")
        }
        .padding(.horizontal, 30)
    }

    private var chips: some View {
        HStack(spacing: 10) {
            if let minutes = title.runtimeMinutes {
                chip { Label("\(minutes) min", systemImage: "clock") }
            }
            if let seasons = title.seasons {
                chip { Text("\(seasons) temporadas") }
            }
            if let year = title.year {
                chip { Text(String(year)) }
            }
            Spacer()
        }
        .padding(.leading, 30)
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(size: 14))
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .overlay(RoundedRectangle(cornerRadius: 10).inset(by: 0.5).stroke(Color.branco, lineWidth: 1))
    }

    private var genres: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(title.genres, id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 13))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.roxo.opacity(0.5), in: Capsule())
                }
            }
            .padding(.horizontal, 30)
        }
    }

    private var reason: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Por que combina")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title.reason)
                .font(.system(size: 16))
                .foregroundColor(.laranja)
        }
        .padding(.horizontal, 30)
    }
}
```

- [ ] **Step 3: Criar `FilmFinder/Features/Results/TitleCard.swift`**

```swift
import SwiftUI

struct TitleCard: View {
    let title: Title

    private let width: CGFloat = 265
    private let height: CGFloat = 400

    var body: some View {
        ZStack {
            PosterImage(path: title.posterPath)
                .frame(width: width, height: height)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.35),
                            .init(color: Color(red: 0.29, green: 0.01, blue: 0.46), location: 0.98),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 17))

            VStack {
                HStack {
                    Spacer()
                    NavigationLink {
                        TitleDetail(title: title)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .preto, radius: 5)
                    }
                }
                .padding()

                Spacer()

                Text(title.title)
                    .font(.system(size: 20))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                StarsView(stars: title.stars)
                    .padding(.bottom, 8)

                if !title.reason.isEmpty {
                    Text(title.reason)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                let highlighted = title.providers.highlighted()
                if !highlighted.isEmpty {
                    HStack(spacing: 8) {
                        Text("Disponível em")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                        ProviderLogosRow(providers: highlighted, size: 24)
                    }
                    .padding(.bottom, 16)
                } else {
                    Spacer().frame(height: 16)
                }
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }
}
```

- [ ] **Step 4: Criar `FilmFinder/Features/Results/ResultsView.swift`**

```swift
import SwiftData
import SwiftUI

struct ResultsView: View {
    let mediaType: MediaType
    let query: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var model: ResultsModel?
    @State private var currentIndex = 0
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingStateView()
            }
        }
        .task {
            if model == nil {
                model = ResultsModel(
                    mediaType: mediaType,
                    query: query,
                    service: environment.service,
                    store: LibraryStore(context: modelContext),
                    onQuota: { environment.account.update(quota: $0) }
                )
            }
            // `load()` só age em `.idle`: reexecuta com segurança se a task foi cancelada ao navegar.
            await model?.load()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { BackButton() }
            }
        }
    }

    @ViewBuilder
    private func content(_ model: ResultsModel) -> some View {
        switch model.phase {
        case .idle, .loading:
            LoadingStateView()
        case .empty:
            ErrorStateView(kind: .noResults)
        case .failed(let error):
            ErrorStateView(kind: ErrorKind(error)) {
                Task { await model.retry() }
            }
        case .loaded:
            carousel(model)
        }
    }

    private func carousel(_ model: ResultsModel) -> some View {
        let titles = model.visible
        let index = min(currentIndex, max(titles.count - 1, 0))

        return VStack(alignment: .leading, spacing: 16) {
            heading
                .font(.system(size: 24))
                .fontWidth(.expanded)

            ZStack {
                ForEach(Array(titles.enumerated()), id: \.element.id) { position, title in
                    TitleCard(title: title)
                        .scaleEffect(0.9)
                        .opacity(index == position ? 1.0 : 0.5)
                        .scaleEffect(index == position ? 1.2 : 0.8)
                        .offset(x: CGFloat(position - index) * 260 + dragOffset, y: 0)
                }
            }
            .frame(maxWidth: .infinity)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in state = value.translation.width }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        withAnimation {
                            if value.translation.width > threshold {
                                currentIndex = max(0, index - 1)
                            } else if value.translation.width < -threshold {
                                currentIndex = min(titles.count - 1, index + 1)
                            }
                        }
                    }
            )
            .padding()
            .padding(.leading)

            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        guard titles.indices.contains(index) else { return }
                        Task { await model.swap(titles[index]) }
                    } label: {
                        Group {
                            if model.isSwapping {
                                ProgressView().tint(.branco)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .foregroundStyle(Color.branco)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 14).foregroundStyle(Color.laranja))
                    }
                    .disabled(model.isSwapping)
                    .accessibilityLabel("Trocar por outra opção")
                    Spacer()
                }

                if let error = model.swapError {
                    Text(ErrorKind(error).title)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 30)
    }

    private var heading: Text {
        let lead: LocalizedStringKey = mediaType == .movie ? "Estes são os filmes " : "Estas são as séries "
        return Text(lead).foregroundColor(.white).fontWeight(.semibold)
            + Text("mais compatíveis ").foregroundColor(.laranja).bold()
            + Text("com você agora:").foregroundColor(.white).fontWeight(.semibold)
    }
}
```

- [ ] **Step 5: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`. Corrija erros de tipo/sintaxe nestes arquivos sem mudar a estrutura (o código acima é o contrato; ajuste só o necessário para compilar no Xcode instalado).

- [ ] **Step 6: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): add results carousel, title card/detail and streaming availability section"
```

---

### Task iOS-11: Busca e categorias ligadas ao `ResultsView`

**Files:**
- Modify (reescrever): `FilmFinder/View/SearchView.swift` → mover para `FilmFinder/Features/Search/SearchView.swift`
- Modify (editar): `FilmFinder/View/CategoriesView.swift` → mover para `FilmFinder/Features/Search/CategoriesView.swift`

**Interfaces:**
- Consumes: `ResultsView` (Task iOS-10), `CategoryQueryBuilder` (Task iOS-7), `MediaType` e `pluralName`/`pluralNameString` (Tasks iOS-2 e iOS-9)
- Produces: `SearchView()` e `CategoriesView(type: Binding<MediaType>)` (já usados por `MainView`)

- [ ] **Step 1: Mover os arquivos**

Run: `mkdir -p FilmFinder/Features/Search && git mv FilmFinder/View/SearchView.swift FilmFinder/Features/Search/SearchView.swift && git mv FilmFinder/View/CategoriesView.swift FilmFinder/Features/Search/CategoriesView.swift`

- [ ] **Step 2: Reescrever `FilmFinder/Features/Search/SearchView.swift`**

```swift
import SwiftUI

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

private enum SearchMethod: Hashable {
    case description
    case categories
}

struct SearchView: View {
    @State private var message = ""
    @State private var selectedType: MediaType = .movie
    @State private var selectedMethod: SearchMethod = .description
    @Environment(AppEnvironment.self) private var environment

    private var trimmedMessage: String {
        String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
    }

    var body: some View {
        NavigationStack {
            VStack {
                Image("FilmFinder_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 35)
                    .padding(5)

                if let quota = environment.account.quota {
                    Text("\(quota.remaining) buscas restantes hoje")
                        .font(.system(size: 13))
                        .foregroundColor(quota.remaining == 0 ? .red : Color("branco").opacity(0.7))
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading) {
                        Text("Selecione o tipo de conteúdo que você está procurando:")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .foregroundColor(Color("branco"))

                        Picker("Appearance", selection: $selectedType) {
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Text(type.pluralName).tag(type)
                            }
                        }
                        .colorMultiply(selectedType == .movie ? Color("laranja") : .purple)
                        .pickerStyle(.segmented)

                        Text("Escolha um método de busca:")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .foregroundColor(Color("branco"))

                        Picker("Appearance", selection: $selectedMethod) {
                            Text("Descrição").tag(SearchMethod.description)
                            Text("Selecionar categorias").tag(SearchMethod.categories)
                        }
                        .colorMultiply(selectedMethod == .description ? Color("laranja") : .purple)
                        .pickerStyle(.segmented)
                    }
                    .padding()

                    VStack(alignment: .center) {
                        if selectedMethod == .description {
                            TextField("", text: $message, axis: .vertical)
                                .placeholder(when: message.isEmpty) {
                                    VStack(alignment: .leading) {
                                        Text("Descreva o tipo de filme que você está a fim de assistir agora")
                                    }
                                    .foregroundColor(.white)
                                }
                                .lineLimit(5...10)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(width: 300, height: 300, alignment: .topLeading)
                                .background(Color("cinza2"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.cinza1, lineWidth: 1)
                                )

                            NavigationLink {
                                ResultsView(mediaType: selectedType, query: trimmedMessage)
                            } label: {
                                HStack {
                                    Text("Pesquisar \(selectedType.pluralNameString)")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 15))
                                .fontWeight(.bold)
                                .foregroundColor(Color("preto"))
                                .frame(width: 200, height: 40, alignment: .center)
                                .background(Color("laranja").opacity(trimmedMessage.isEmpty ? 0.4 : 1))
                                .cornerRadius(16)
                            }
                            .disabled(trimmedMessage.isEmpty)
                        } else {
                            CategoriesView(type: $selectedType)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .background(Color("cinza1"))
            .task { await environment.account.refresh() }
        }
    }
}

#Preview {
    SearchView()
        .environment(AppEnvironment.live())
}
```

- [ ] **Step 3: Editar `FilmFinder/Features/Search/CategoriesView.swift`** — quatro substituições exatas

(a) tipo do binding:
```swift
// de
    @Binding var type: String
// para
    @Binding var type: MediaType
```

(b) substituir o `NavigationLink` final — do `NavigationLink {` (o que monta `inputText`) até a linha `            }` que fecha o `label` (logo depois de `.cornerRadius(16)` e de uma linha em branco; as duas chaves seguintes, `        }` e `    }`, fecham o `VStack` e o `body` e **permanecem**) — por:
```swift
            NavigationLink {
                ResultsView(mediaType: type, query: builtQuery ?? "")
            } label: {
                HStack {
                    Text("Pesquisar \(type.pluralNameString)")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15))
                .fontWeight(.bold)
                .foregroundColor(Color("preto"))
                .frame(width: 200, height: 40, alignment: .center)
                .background(Color("laranja").opacity(builtQuery == nil ? 0.4 : 1))
                .cornerRadius(16)
            }
            .disabled(builtQuery == nil)
```

(c) acrescentar, logo antes de `func joinedNames(from categories: [Category]) -> String {`:
```swift
    private var builtQuery: String? {
        CategoryQueryBuilder.query(
            mediaType: type,
            moods: selectedMood.map(\.name),
            genres: selectedGenre.map(\.name),
            themes: selectedScript.map(\.name)
        )
    }

```

(d) o preview:
```swift
// de
        CategoriesView(type: Binding.constant("Filmes"))
// para
        CategoriesView(type: .constant(.movie))
```

- [ ] **Step 4: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`.

- [ ] **Step 5: Verificar no simulador, ponta a ponta contra o Worker `dev`**

Use o MCP do simulador (`mcp__Claude_Code_iOS_Simulator__control`): `attach` (antes de construir), construir com `xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build`, depois `launch` com `app_path` `build/Build/Products/Debug-iphonesimulator/FilmFinder.app`, passar o onboarding, escolher **Filmes**, escrever "ficção científica que mexe com o tempo" e tocar em Pesquisar.
Expected (screenshots): tela de carregamento com a animação; depois 3 cards com pôster, estrelas, **motivo em 1–2 linhas** e **logos "Disponível em"**; arrastar troca o card em foco; o botão de trocar substitui o card sem tela de carregamento; "+" abre o detalhe com a seção **Onde assistir** e o texto **Dados de streaming: JustWatch**. Registrar o que não bater e corrigir antes do commit.

- [ ] **Step 6: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): wire search and categories to the recommendations backend"
```

---

### Task iOS-12: Telas de biblioteca (Histórico, Favoritos, Assistidos) e Perfil

**Files:**
- Create: `FilmFinder/Features/Library/LibraryListView.swift`, `LibraryRow.swift`, `HistoryView.swift`
- Create: `FilmFinder/Features/Profile/ProfileView.swift`, `LibraryPreviewRectangle.swift`
- Delete: `FilmFinder/View/HistoryView.swift`, `FilmFinder/View/Profile/` (todos os arquivos), `FilmFinder/View/CardListView.swift`

**Interfaces:**
- Consumes: `LibraryItem`, `LibraryStore` (Task iOS-5); `TitleDetail` (Task iOS-10); `PosterImage`, `CustomDivider` (Task iOS-9)
- Produces: `LibraryListView(kind:showsBackButton:)`, `HistoryView()` (usado pelo `MainView`), `ProfileView()` (usado pelo `MainView`)

- [ ] **Step 1: Remover as telas antigas que dependem de `DataManager`**

Run: `git rm -r FilmFinder/View/HistoryView.swift FilmFinder/View/Profile FilmFinder/View/CardListView.swift && mkdir -p FilmFinder/Features/Library FilmFinder/Features/Profile`

- [ ] **Step 2: Criar `FilmFinder/Features/Library/LibraryRow.swift`**

```swift
import SwiftUI

struct LibraryRow: View {
    let title: Title
    let date: Date

    var body: some View {
        NavigationLink {
            TitleDetail(title: title)
        } label: {
            HStack {
                PosterImage(path: title.posterPath)
                    .frame(width: 70, height: 105)
                    .clipped()
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title.title)
                        .font(.system(size: 16))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.branco)
                    if let year = title.year {
                        Text(String(year))
                            .font(.system(size: 13))
                            .foregroundColor(.branco)
                    }
                    Text(date, style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(Color(uiColor: .gray))
                }
                .padding()
                Spacer()
            }
            .padding(.leading)
            .frame(maxWidth: .infinity)
        }
    }
}
```

- [ ] **Step 3: Criar `FilmFinder/Features/Library/LibraryListView.swift`**

```swift
import SwiftData
import SwiftUI

struct LibraryListView: View {
    enum Kind {
        case history
        case favorites
        case watched

        var heading: LocalizedStringKey {
            switch self {
            case .history: "Histórico"
            case .favorites: "Favoritos"
            case .watched: "Assistidos"
            }
        }
    }

    let kind: Kind
    let showsBackButton: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [LibraryItem]

    init(kind: Kind, showsBackButton: Bool = true) {
        self.kind = kind
        self.showsBackButton = showsBackButton
        switch kind {
        case .history:
            _items = Query(filter: #Predicate<LibraryItem> { $0.inHistory }, sort: \.recommendedAt, order: .reverse)
        case .favorites:
            _items = Query(filter: #Predicate<LibraryItem> { $0.isFavorite }, sort: \.recommendedAt, order: .reverse)
        case .watched:
            _items = Query(filter: #Predicate<LibraryItem> { $0.isWatched }, sort: \.recommendedAt, order: .reverse)
        }
    }

    var body: some View {
        VStack {
            Image("FilmFinder_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 25)
                .padding(5)

            VStack {
                HStack {
                    Text(kind.heading)
                        .fontWidth(.expanded)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.laranja)
                    Spacer()
                    EditButton()
                        .foregroundColor(.laranja)
                }
                CustomDivider(color: .laranja, width: 2)
            }
            .padding()

            List {
                ForEach(items) { item in
                    if let title = item.snapshot {
                        LibraryRow(title: title, date: item.recommendedAt)
                            .listRowBackground(Color.cinza1)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
        }
        .background(Color.cinza1)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if showsBackButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { BackButton() }
                }
            }
        }
        .toolbar(showsBackButton ? .automatic : .hidden, for: .navigationBar)
    }

    private func delete(at offsets: IndexSet) {
        let store = LibraryStore(context: modelContext)
        let titles = offsets.compactMap { items[$0].snapshot }
        withAnimation {
            for title in titles {
                switch kind {
                case .history: store.removeFromHistory(title)
                case .favorites: store.setFavorite(title, false)
                case .watched: store.setWatched(title, false)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Criar `FilmFinder/Features/Library/HistoryView.swift`**

```swift
import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            LibraryListView(kind: .history, showsBackButton: false)
        }
    }
}
```

- [ ] **Step 5: Criar `FilmFinder/Features/Profile/LibraryPreviewRectangle.swift`**

```swift
import SwiftUI

struct LibraryPreviewRectangle: View {
    let heading: LocalizedStringKey
    let items: [LibraryItem]

    var body: some View {
        VStack {
            Text(heading)
                .font(.system(size: 15))
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .foregroundStyle(Color.laranja)
                .padding(.top)
            CustomDivider(color: .laranja, width: 2)
                .padding(.horizontal)

            HStack {
                if items.isEmpty {
                    Color.clear.frame(width: 95, height: 142)
                } else {
                    ForEach(items.prefix(3)) { item in
                        PosterImage(path: item.snapshot?.posterPath)
                            .frame(width: 95, height: 142)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }
        }
        .frame(width: 341, height: 207.3125)
        .background(Color(red: 0.2, green: 0.2, blue: 0.2), in: RoundedRectangle(cornerRadius: 15.5))
    }
}
```

- [ ] **Step 6: Criar `FilmFinder/Features/Profile/ProfileView.swift`**

```swift
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query(filter: #Predicate<LibraryItem> { $0.isFavorite }, sort: \.recommendedAt, order: .reverse)
    private var favorites: [LibraryItem]

    @Query(filter: #Predicate<LibraryItem> { $0.isWatched }, sort: \.recommendedAt, order: .reverse)
    private var watched: [LibraryItem]

    var body: some View {
        NavigationStack {
            VStack(alignment: .center) {
                Image("FilmFinder_logoPB")
                    .resizable()
                    .frame(width: 54, height: 29)

                Image("perfil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94)
                    .padding(.top, 20)

                Text("Meu Perfil")
                    .font(.system(size: 20))
                    .fontWidth(.expanded)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                    .foregroundColor(.laranja)

                Text("\(watched.count) assistidos | \(favorites.count) favoritos")
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundColor(.branco)

                VStack {
                    NavigationLink {
                        LibraryListView(kind: .favorites)
                    } label: {
                        LibraryPreviewRectangle(heading: "Favoritos", items: favorites)
                    }
                    NavigationLink {
                        LibraryListView(kind: .watched)
                    } label: {
                        LibraryPreviewRectangle(heading: "Assistidos", items: watched)
                    }
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cinza1)
        }
    }
}
```

- [ ] **Step 7: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`. Se houver referência restante a `DataManager`/`WatchedContent` em arquivo **que ainda será apagado na Task iOS-14** (ex.: `FilmView`, `SerieView`, `ChatGptView`), é esperado e aceitável; o erro deve ser só nesses arquivos legados. Nesse caso, siga direto para a Task iOS-14 e faça o build lá (os dois passos são commitados juntos).

- [ ] **Step 8: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): add library list screens and profile backed by SwiftData"
```

---

### Task iOS-13: Tela de Ajustes — login com Apple, conta e créditos

**Files:**
- Create: `FilmFinder/Features/Settings/SettingsView.swift`
- Modify: `FilmFinder/View/MainView.swift` (4ª aba; o arquivo é movido na Task iOS-14)

**Interfaces:**
- Consumes: `AppEnvironment.account` / `AccountModel` (Tasks iOS-8 e iOS-9); `ErrorKind` (Task iOS-9)
- Produces: `SettingsView()` — seções **Conta** (botão "Entrar com Apple"; quando logado: "Sair" e "Excluir conta" com confirmação), **Buscas** (restantes hoje), **Sobre** (créditos TMDB e JustWatch, links de privacidade/termos quando configurados, versão)

- [ ] **Step 1: Criar `FilmFinder/Features/Settings/SettingsView.swift`**

```swift
import AuthenticationServices
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var confirmingDelete = false

    private var account: AccountModel { environment.account }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                searchesSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.cinza1)
            .navigationTitle("Ajustes")
            .task {
                await account.refresh()
                if !account.isSignedIn { await account.prepareSignIn() }
            }
            .confirmationDialog("Excluir conta?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Excluir conta", role: .destructive) {
                    Task { await account.deleteAccount() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Sua conta e sua assinatura vinculada serão removidas dos nossos servidores. Seus filmes salvos neste aparelho continuam aqui.")
            }
        }
    }

    // MARK: - Conta

    private var accountSection: some View {
        Section("Conta") {
            if account.isSignedIn {
                Label("Conectado com a Apple", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.laranja)
                Button("Sair") {
                    Task { await account.signOut() }
                }
                Button("Excluir conta", role: .destructive) {
                    confirmingDelete = true
                }
            } else {
                Text("Entre para usar sua assinatura em todos os seus aparelhos. Você pode buscar sem entrar.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = []
                    request.nonce = account.signInNonce
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 48)
                .disabled(account.signInNonce == nil || account.isBusy)
            }

            if let error = account.lastError {
                Text(ErrorKind(error).title)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let codeData = credential.authorizationCode,
                let token = String(data: tokenData, encoding: .utf8),
                let code = String(data: codeData, encoding: .utf8)
            else { return }
            Task { await account.completeSignIn(identityToken: token, authorizationCode: code) }
        case .failure:
            // Cancelou ou falhou: o desafio já foi usado pela folha, pega um novo.
            Task { await account.prepareSignIn() }
        }
    }

    // MARK: - Buscas

    private var searchesSection: some View {
        Section("Buscas") {
            if let quota = account.quota {
                Text("\(quota.remaining) de \(quota.limit) buscas restantes hoje")
            } else {
                Text("Carregando…")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sobre

    private var aboutSection: some View {
        Section("Sobre") {
            Text("Dados de filmes e séries: TMDB")
            Text("Dados de streaming: JustWatch")
            if let url = infoURL("PrivacyPolicyURL") {
                Link("Política de privacidade", destination: url)
            }
            if let url = infoURL("TermsURL") {
                Link("Termos de uso", destination: url)
            }
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                LabeledContent("Versão", value: version)
            }
        }
    }

    private func infoURL(_ key: String) -> URL? {
        guard let raw = Bundle.main.infoDictionary?[key] as? String, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment.live())
}
```

- [ ] **Step 2: Acrescentar a aba em `FilmFinder/View/MainView.swift`** — logo depois do bloco da aba `ProfileView()` (que termina em `.tag(2)`), antes do `}` que fecha o `TabView`:

```swift
            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(3)
```

- [ ] **Step 3: Compilar**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:` além das de código legado que a Task iOS-14 apaga (ver o aviso do Step 7 da Task iOS-12).

- [ ] **Step 4: Verificar no simulador (aparência e estado deslogado)**

Use o MCP do simulador: `attach` antes de construir; construir para o iPhone 17 (`-derivedDataPath build`); `launch`; passar o onboarding; abrir a aba **Ajustes**.
Expected (screenshots): seção **Conta** com o texto de explicação e o botão branco **Continuar com a Apple / Entrar com Apple**; seção **Buscas** com "N de 5 buscas restantes hoje" (o app já se registrou sozinho no Worker `dev`, sem atestação, por estar no simulador); seção **Sobre** com os dois créditos e a versão. Fazer uma busca e voltar: o contador cai em 1.
O fluxo de login em si (a folha da Apple) depende de uma conta Apple entrada no simulador/aparelho e é validado no checklist da Task iOS-14.

- [ ] **Step 5: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(ios): add Settings screen with Sign in with Apple, account management and credits"
```

### Task iOS-14: Limpeza do código legado, Swift 6, traduções e verificação final (simulador e iPhone)

**Files:**
- Delete: `FilmFinder/Model/` (tudo, **exceto** `Cores.swift`), `FilmFinder/View/ChatGptView.swift`, `FilmFinder/View/FilmsViews/`, `FilmFinder/View/SeriesView/`, `FilmFinder/View/ErrorView.swift`, `FilmFinder/Secrets.swift` (o temporário da Task iOS-1), `FilmFinder/Source/FlexStack.swift` (se não referenciado)
- Move: onboarding/loading/main/back/cores para `Features/`
- Modify: `project.yml` (Swift 6), `FilmFinder/Localizable.xcstrings`, `README.md` (raiz)

**Interfaces:**
- Consumes: tudo das Tasks iOS-2 a iOS-13
- Produces: app sem referências ao código legado, em Swift 6, com strings em PT/EN, verificado ponta a ponta no simulador e (checklist) em iPhone real.

- [ ] **Step 1: Confirmar que nada novo referencia o legado e checar o que é seguro apagar**

Run:
```bash
grep -rnE "DataManager|WatchedContent|FilmData|SerieData|ChatGptView|FilmView|SerieView|ErrorView\b|FlexStack|ImageProvider|Secrets\." FilmFinder --include='*.swift' | grep -vE "^FilmFinder/(Model|View/(ChatGptView|FilmsViews|SeriesView|ErrorView)|Source/FlexStack)"
```
Expected: sem linhas (só o próprio legado, filtrado, referencia o legado). Se algo de `Features/`, `Core/`, `Data/` ou `App/` aparecer, corrija antes de apagar. (`ImageProvider` pode aparecer no final de `View/BackButton.swift`; ele é removido no Step 3.)

- [ ] **Step 2: Apagar o legado**

Run:
```bash
git rm -r FilmFinder/Model/ChatGptModel.swift FilmFinder/Model/ChatGptResponseModel.swift FilmFinder/Model/ChatGptFilterModel.swift FilmFinder/Model/FilmData.swift FilmFinder/Model/FilmResponseModel.swift FilmFinder/Model/SerieData.swift FilmFinder/Model/SerieResponseModel.swift FilmFinder/Model/History.swift FilmFinder/Model/UserDefaultsManenger.swift FilmFinder/View/ChatGptView.swift FilmFinder/View/FilmsViews FilmFinder/View/SeriesView FilmFinder/View/ErrorView.swift
rm -f FilmFinder/Secrets.swift
grep -rn "FlexStack" FilmFinder --include='*.swift' | grep -v "Source/FlexStack.swift" || git rm FilmFinder/Source/FlexStack.swift
```
Expected: `Model/` fica só com `Cores.swift`.

- [ ] **Step 3: Reorganizar as telas mantidas**

Run:
```bash
mkdir -p FilmFinder/Features/Onboarding FilmFinder/Features/Shared FilmFinder/Features/Home
git mv FilmFinder/View/Onboarding/*.swift FilmFinder/Features/Onboarding/
git mv FilmFinder/View/InitialLoading.swift FilmFinder/Features/Home/InitialLoading.swift
git mv FilmFinder/View/MainView.swift FilmFinder/Features/Home/MainView.swift
git mv FilmFinder/View/BackButton.swift FilmFinder/Features/Shared/BackButton.swift
git mv FilmFinder/Model/Cores.swift FilmFinder/Features/Shared/Cores.swift
rmdir FilmFinder/View/Onboarding FilmFinder/View FilmFinder/Model 2>/dev/null; ls FilmFinder
```
Expected: `ls` mostra `Animation`, `App`, `Assets.xcassets`, `Core`, `Data`, `Domain`, `Features`, `Images`, `Info.plist`, `Localizable.xcstrings`, `Preview Content`, `FilmFinder.entitlements` (e `Source` se ainda existir). Remover de `Features/Shared/BackButton.swift` o `protocol ImageProvider { ... }` do final do arquivo, se estiver lá (era usado só pelo legado).

- [ ] **Step 4: Compilar com tudo limpo (ainda em Swift 5)**

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep -E "error:" | head`
Expected: nenhuma linha `error:`.

- [ ] **Step 5: Ligar o Swift 6** — em `project.yml`, trocar `SWIFT_VERSION: '5.0'` por `SWIFT_VERSION: '6.0'`

Run: `xcodegen generate && xcodebuild build -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E "error:" | head -20`
Expected: pode haver erros de concorrência. Corrija-os arquivo a arquivo, nesta ordem de preferência: (1) `@MainActor` no tipo/propriedade que toca UI ou SwiftData; (2) `Sendable` em structs de valor; (3) `nonisolated(unsafe)` só em estado global de teste. Candidatos prováveis: `LottieView.swift`, `Cores.swift` (`Color` estáticos), `MockURLProtocol`/`RecordBox` (já `@unchecked Sendable`), onboarding, closures `@Sendable` nos testes de `AuthService`. **Não** silencie com `@preconcurrency` sem necessidade. Repita até zero `error:`.

- [ ] **Step 6: Rodar toda a suíte em Swift 6**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Test run|passed|failed" | tail -6`
Expected: todos PASS (75 testes na versão deste plano).

- [ ] **Step 7: Adicionar as traduções em inglês** (as chaves em português já funcionam como texto-fonte; falta o inglês)

Run:
```bash
python3 - <<'EOF'
import json
p = 'FilmFinder/Localizable.xcstrings'
d = json.load(open(p))
new = {
  "Disponível em": "Available on",
  "Por que combina": "Why it fits",
  "Onde assistir": "Where to watch",
  "Assinatura": "Subscription",
  "Grátis": "Free",
  "Aluguel": "Rent",
  "Compra": "Buy",
  "Não disponível em streaming na sua região": "Not available to stream in your region",
  "Ver onde assistir": "See where to watch",
  "Dados de streaming: JustWatch": "Streaming data: JustWatch",
  "Dados de filmes e séries: TMDB": "Movie and series data: TMDB",
  "%lld min": "%lld min",
  "%lld temporadas": "%lld seasons",
  "%lld assistidos | %lld favoritos": "%lld watched | %lld favorites",
  "%lld buscas restantes hoje": "%lld searches left today",
  "%lld de %lld buscas restantes hoje": "%lld of %lld searches left today",
  "Sem conexão": "No connection",
  "Verifique sua internet e tente novamente": "Check your internet and try again",
  "Serviço indisponível no momento": "Service unavailable right now",
  "Estamos com instabilidade. Tente novamente em instantes": "We're having issues. Please try again shortly",
  "Suas buscas de hoje acabaram": "You're out of searches for today",
  "Volte amanhã para novas recomendações": "Come back tomorrow for new recommendations",
  "Algo deu errado": "Something went wrong",
  "Tente novamente": "Try again",
  "Tentar de novo": "Try again",
  "Trocar por outra opção": "Swap for another option",
  "Favoritar": "Add to favorites",
  "Remover dos favoritos": "Remove from favorites",
  "Marcar como assistido": "Mark as watched",
  "Desmarcar como assistido": "Unmark as watched",
  "Estes são os filmes ": "These are the movies ",
  "Estas são as séries ": "These are the series ",
  "Ajustes": "Settings",
  "Conta": "Account",
  "Buscas": "Searches",
  "Sobre": "About",
  "Conectado com a Apple": "Signed in with Apple",
  "Sair": "Sign out",
  "Excluir conta": "Delete account",
  "Excluir conta?": "Delete account?",
  "Cancelar": "Cancel",
  "Sua conta e sua assinatura vinculada serão removidas dos nossos servidores. Seus filmes salvos neste aparelho continuam aqui.": "Your account and linked subscription will be removed from our servers. Movies saved on this device stay here.",
  "Entre para usar sua assinatura em todos os seus aparelhos. Você pode buscar sem entrar.": "Sign in to use your subscription on all your devices. You can search without signing in.",
  "Carregando…": "Loading…",
  "Política de privacidade": "Privacy policy",
  "Termos de uso": "Terms of use",
  "Versão": "Version",
}
added = 0
for key, en in new.items():
    entry = d["strings"].setdefault(key, {})
    locs = entry.setdefault("localizations", {})
    if "en" not in locs:
        locs["en"] = {"stringUnit": {"state": "translated", "value": en}}
        added += 1
    locs.setdefault("pt-BR", {"stringUnit": {"state": "translated", "value": key}})
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
print("traduções adicionadas:", added)
EOF
```
Expected: `traduções adicionadas: N` (chaves que já existiam no catálogo são preservadas).

- [ ] **Step 8: Atualizar o `README.md` da raiz** — acrescentar ao final

```markdown

## Desenvolvimento

O app depende de um backend (Cloudflare Worker em `backend/`).

    brew install xcodegen
    cp Config/Local.xcconfig.example Config/Local.xcconfig   # ou crie o arquivo com DEVELOPMENT_TEAM = <seu Team ID>
    xcodegen generate
    open FilmFinder.xcodeproj

A URL da API vem de `Config/*.xcconfig` (`API_BASE_URL`). Não há chave de API no app: o dispositivo se registra no
backend (App Attest em aparelho real; sem atestação no simulador, aceito só pelo ambiente `dev`) e usa tokens de sessão.
Sign in with Apple é opcional (Ajustes). Testes:

    xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17'
```
E criar `Config/Local.xcconfig.example` com o conteúdo `DEVELOPMENT_TEAM = ABCDE12345` (versionado; o `Local.xcconfig` real continua no `.gitignore`).

- [ ] **Step 9: Verificação final no simulador** (mesmo fluxo da Task iOS-11, Step 5, agora no app limpo)

Construir, instalar e abrir no iPhone 17 (`attach` antes do build). Roteiro, com screenshot em cada passo:
1. Abrir o app → onboarding (ou Home) normal; **nenhuma chave de API no app**.
2. **Filmes** + descrição → 3 cards com motivo e logos; selo "N buscas restantes hoje" na aba de busca cai em 1 a cada busca; trocar um card (sem tela de carregamento e **sem** gastar cota); abrir o detalhe (Onde assistir + **Dados de streaming: JustWatch**); favoritar e marcar assistido.
3. Fazer a **mesma busca** de novo: favoritos/assistidos/já mostrados **não** reaparecem.
4. Aba **Histórico**: lista só os títulos exibidos; apagar um item. Aba **Perfil**: contadores e prévias corretos.
5. **Séries** + categorias → resultados de séries; detalhe mostra "N temporadas".
6. Esgotar a cota (5 buscas) → a 6ª mostra "Suas buscas de hoje acabaram" e **não** chama a IA.
7. Modo avião → buscar → "Sem conexão" com **Tentar de novo**; voltar a rede e tocar → resultados.
8. **Ajustes**: contador de buscas coerente com o selo; créditos TMDB/JustWatch; botão de Apple visível.
Expected: tudo acima funciona; registrar qualquer divergência e corrigir antes de commitar.

- [ ] **Step 10: Teste da migração com dados no formato antigo** (SwiftData + UserDefaults no simulador)

Run (com o app fechado):
```bash
xcrun simctl spawn booted defaults write com.andre.filmfinder allContent -data "$(printf '%s' '[{"id":"A1B2C3D4-0000-0000-0000-000000000001","date":700000000,"content":{"filme":{"id":"A1B2C3D4-0000-0000-0000-000000000002","idFilme":19995,"title":"Avatar","image":"/iNMP8uzaV2Ing6ZCw0IICgEFVNfC.jpg","releaseDate":"2009-12-15","originalTitle":"2009-12-15","duration":162,"plot":"Plot","rating":7.5,"favorite":false,"watched":false}}}]' | xxd -p | tr -d '\n')"
xcrun simctl spawn booted defaults delete com.andre.filmfinder legacyImportDone.v1 2>/dev/null; true
```
Depois abrir o app e fazer uma busca de **filmes** que provavelmente sugeriria Avatar (ex.: "ficção científica épica com alienígenas"). Expected: **Avatar (id 19995) não aparece**, porque o importador o registrou como já recomendado. Conferir também que a chave antiga sumiu: `xcrun simctl spawn booted defaults read com.andre.filmfinder allContent` deve falhar com "does not exist". A cobertura completa do importador (flags, séries, datas, idempotência, dados corrompidos) está nos testes da Task iOS-6.

- [ ] **Step 11: Commit**

```bash
git add -A FilmFinder project.yml README.md Config .gitignore
git commit -m "refactor(ios): remove legacy ChatGPT/UserDefaults code, enable Swift 6, add English strings"
```

- [ ] **Step 12: [USUÁRIO] Checklist em iPhone real** (App Attest e Sign in with Apple só funcionam de verdade no aparelho)

Pré-requisitos: iPhone com iOS 18+, conectado ao Mac; conta Apple Developer paga; no Xcode, abrir `FilmFinder.xcodeproj` → target **FilmFinder** → *Signing & Capabilities*: Team selecionado, e as capabilities **Sign in with Apple** e **App Attest** presentes (vêm do `FilmFinder.entitlements`); rodar no aparelho (Debug → `appattest-environment = development`).
1. Abrir o app e fazer uma busca. Em outro terminal: `cd backend && npx wrangler tail --env dev --format pretty`. Expected: `POST /v1/devices` 200 (**sem** `attestation_failed`) seguido de `POST /v1/recommendations` 200. Se aparecer `attestation_failed`, o `message` traz o motivo exato (ver a Task BE-9, Step 13) e o ajuste é no backend (`APPLE_TEAM_ID`, `APPATTEST_ENVS`) ou no verificador.
2. Deixar passar 15 minutos (ou matar e reabrir o app depois disso) e buscar de novo: deve haver `POST /v1/auth/refresh` 200.
3. **Ajustes → Entrar com Apple**: concluir a folha; `POST /v1/auth/apple` 200 e o cartão passa a mostrar "Conectado com a Apple".
4. **Sair**: volta ao estado anônimo; entrar de novo funciona.
5. **Excluir conta**: confirmar; `DELETE /v1/me` 200 e o app volta ao estado anônimo. Se a Apple não conseguir revogar, o app mostra o erro e a conta continua (tentar de novo).
6. Reinstalar o app e buscar: o app deve se registrar de novo sem erro (a chave do App Attest antiga é descartada).
Registrar o resultado (ou o `message` de qualquer falha) para corrigir o que for preciso.

---

## Próximos planos

4. **Monetização** (StoreKit 2, `POST /v1/appstore/transactions`, webhook de notificações, paywall; trata `APIError.quotaExceeded` abrindo o paywall e concede a entitlement `unlimited_search`).
5. **Lançamento** (CI, alertas e Analytics Engine, produção — `ALLOW_UNATTESTED=false`, `APPATTEST_ENVS=production`, URL de produção, token do AI Gateway só com Run —, criptografia em repouso do token do Apple, App Store Connect, privacidade e TestFlight).
