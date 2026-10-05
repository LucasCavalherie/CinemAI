# FilmFinder API (Cloudflare Worker)

Recebe um pedido em linguagem natural, obtém indicações de Gemini Flash-Lite ou Claude Haiku 4.5 (com fallback; GPT mini disponível, desligado por padrão) e devolve títulos resolvidos no TMDB com onde assistir.

## Rodando fora da Cloudflare (VPS / Docker)

O mesmo código roda como servidor Node (SQLite em arquivo). Guia completo para Dokploy: `docs/deploy/dokploy.md`.

    npm run docker:build
    docker run -p 3000:3000 -v ffdata:/data -e JWT_SECRET=... -e TMDB_TOKEN=... -e GEMINI_API_KEY=... \
      -e APPLE_TEAM_ID=... -e APPLE_BUNDLE_ID=com.andre.filmfinder filmfinder-api

## Desenvolvimento

    npm install
    cp .dev.vars.example .dev.vars   # preencher
    npm run dev                      # wrangler dev (ambiente local)
    npm test
    npm run typecheck

## Smoke test (rede real, gasta créditos de IA)

    DEV_API_KEY=... npm run smoke                     # contra localhost:8787 (SMOKE_PROVIDERS=anthropic,gemini)
    SMOKE_URL=https://... DEV_API_KEY=... npm run smoke

## Configuração em runtime (KV `CONFIG`, sem deploy)

| Chave | Valores | Padrão |
|---|---|---|
| `ai.primary` | `gemini` \| `anthropic` \| `openai` | `gemini` |
| `ai.secondary` | idem (diferente do primário) | `anthropic` |
| `ai.models.anthropic` | ID do modelo | `claude-haiku-4-5` |
| `ai.models.gemini` | ID do modelo | `gemini-3.5-flash-lite` |
| `ai.models.openai` | ID do modelo | `gpt-5-mini` |

    npx wrangler kv key put --env dev --binding CONFIG ai.primary openai --remote

## Endpoints

Públicos: `GET /health`, `POST /v1/auth/challenge`, `POST /v1/devices`, `POST /v1/auth/refresh`.
Autenticados (`Authorization: Bearer <accessToken>`): `POST /v1/recommendations`, `GET /v1/me`, `DELETE /v1/me`,
`POST /v1/auth/apple`, `POST /v1/auth/logout`.

Sessão: `POST /v1/devices` devolve `{ accessToken, expiresAt, refreshToken }` (acesso de 15 min; refresh de 60 dias, rotativo).
No ambiente `dev` (`ALLOW_UNATTESTED=true`) aceita `{ "unattested": true }`; em produção exige App Attest
(`{ keyId, attestation, challenge }`). `x-ai-provider` só vale com `ALLOW_PROVIDER_OVERRIDE=true`.

Cota: 5 buscas/dia grátis, 100/dia com a entitlement `unlimited_search` (KV `limits.free.daily`, `limits.pro.daily`).
Erros: `{ "error": { "code", "message" } }`; cota esgotada = HTTP 402 `quota_exceeded`.

Dados de filmes e séries: TMDB. Dados de streaming: JustWatch (via TMDB).
