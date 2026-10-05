# FilmFinder API (Cloudflare Worker)

Recebe um pedido em linguagem natural, obtém indicações de Claude Haiku 4.5 ou Gemini Flash-Lite (com fallback; GPT mini disponível, desligado por padrão) e devolve títulos resolvidos no TMDB com onde assistir.

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
| `ai.primary` | `anthropic` \| `gemini` \| `openai` | `anthropic` |
| `ai.secondary` | idem (diferente do primário) | `gemini` |
| `ai.models.anthropic` | ID do modelo | `claude-haiku-4-5` |
| `ai.models.gemini` | ID do modelo | `gemini-3.5-flash-lite` |
| `ai.models.openai` | ID do modelo | `gpt-5-mini` |

    npx wrangler kv key put --env dev --binding CONFIG ai.primary openai --remote

## Endpoints (Fatia 1)

- `GET /health`
- `POST /v1/recommendations` — header `x-dev-key` obrigatório; `x-ai-provider` opcional força um provedor.

Corpo: `{ query, mediaType: "movie"|"tv", excludeTmdbIds?, locale?: "pt-BR", region?: "BR" }`
Resposta: `{ titles: Title[], quota: null }`

Dados de filmes e séries: TMDB. Dados de streaming: JustWatch (via TMDB).
