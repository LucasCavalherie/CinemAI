# FilmFinder — Relançamento freemium

**Data:** 2026-10-05
**Status:** design aprovado, aguardando revisão da spec
**Branch:** `relaunch`

## 1. Objetivo

Relançar o FilmFinder na App Store como produto freemium, operado por nós. O fluxo central continua o mesmo:

> Usuário descreve em linguagem natural o que quer assistir → IA interpreta e devolve indicações estruturadas → backend resolve cada indicação no TMDB (incluindo onde assistir) → app mostra 3 opções, com buffer para trocar.

Mudanças principais em relação ao app atual:

1. Chaves de IA e TMDB saem do app e passam a viver num backend (Cloudflare Worker).
2. IA moderna com saída JSON garantida por schema, dois provedores (Gemini Flash-Lite primário e Claude Haiku 4.5 fallback) com fallback e primário/secundário alternáveis sem deploy. *(Revisão 2026-10-05: Gemini substitui GPT mini por falta de créditos OpenAI e custo menor; o adaptador OpenAI continua no código, desligado.)*
3. Cada título mostra em quais streamings está disponível na região do usuário (TMDB `watch/providers`, dados JustWatch).
4. Modelo freemium por cota de buscas, assinatura via StoreKit 2.
5. Sign in with Apple opcional, para Pro valer em vários devices.
6. Refatoração profunda do app iOS (iOS 18, `@Observable`, SwiftData, camada de serviços, unificação Filme/Série), mantendo a identidade visual.

## 2. Estado atual (resumo do que muda)

- `ChatGptView` chama `gpt-3.5-turbo` direto do app com chave embutida (`Secrets.swift`), resposta em texto `nome1;nome2;…` com parsing frágil.
- `FilmView`/`SerieView` (e Card/Detail) duplicam ~700 linhas; buscam TMDB só por nome, pegam o primeiro resultado, 2 requests por título; idioma do detalhe fixo em `pt-BR`.
- `DataManager` mantém 4 listas paralelas em UserDefaults. Bug: `addContent` para série chama a si mesmo em vez de `addToHistory`.
- Tipo de mídia representado pelas strings `"Filmes"`/`"Séries"`.

## 3. Arquitetura geral

```
iOS app (SwiftUI, iOS 18)
   │  HTTPS + bearer token
   ▼
Cloudflare Worker (TypeScript, Hono, Zod)
   ├── D1  (usuários, devices, entitlements, uso)
   ├── KV  (config, cache TMDB)
   ├── Analytics Engine (métricas)
   ├── AI Gateway ──► Anthropic (Claude Haiku 4.5)
   │              └─► OpenAI (GPT mini)
   ├── TMDB API
   └── Apple (App Attest, Sign in with Apple JWKS/revoke, App Store Server API)
```

Monorepo: `backend/` ao lado de `FilmFinder/`.

## 4. Backend (Cloudflare Worker)

### 4.1 Stack

TypeScript, Hono (roteamento), Zod (validação de entrada e de saída da IA), D1, KV, Analytics Engine, Cloudflare AI Gateway na frente dos dois provedores. Ambientes `dev` e `prod` via wrangler envs. Secrets (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `TMDB_TOKEN`, chaves Apple, segredo de JWT) via `wrangler secret`.

### 4.2 Identidade

- **Anônimo por padrão.** No primeiro launch o app gera uma chave App Attest e chama `POST /v1/devices`. O Worker valida a atestação com a Apple e devolve `accessToken` (JWT, 1h) + `refreshToken`. Requests seguintes usam App Attest assertion no refresh. Buscas grátis funcionam sem conta (guideline 5.1.1).
- **Sign in with Apple opcional.** `POST /v1/auth/apple` recebe o `identityToken`, valida assinatura com o JWKS da Apple, `aud` = bundle id, `iss`, `exp`. Cria ou encontra `users` por `apple_sub` e vincula o device atual.
- **Merge ao logar:** entitlements do device anônimo passam para o usuário; uso do dia do usuário passa a ser o maior entre os dois contadores (nunca soma a favor do usuário).
- **Logout:** device volta a anônimo, mas o contador de uso do device permanece (logout não reseta cota).
- **Exclusão de conta (obrigatória pela Apple):** `DELETE /v1/me` remove `users` e vínculos, chama `https://appleid.apple.com/auth/revoke`, mantém apenas o registro de uso do device para anti-abuso.

### 4.3 Endpoints

| Método e rota | Entrada | Saída |
|---|---|---|
| `POST /v1/devices` | atestação App Attest | `accessToken`, `refreshToken` |
| `POST /v1/auth/refresh` | `refreshToken` + assertion | novo `accessToken` |
| `POST /v1/auth/apple` | `identityToken`, `authorizationCode` | tokens vinculados ao usuário |
| `GET /v1/me` | — | `entitlements[]`, `quota { used, limit, resetsAt }`, `user?` |
| `DELETE /v1/me` | — | 204 |
| `POST /v1/recommendations` | `{ query, mediaType, excludeTmdbIds[], locale, region }` | `{ titles: Title[], quota }` |
| `POST /v1/appstore/transactions` | JWS da `Transaction` (StoreKit 2) | `entitlements[]` |
| `POST /v1/appstore/notifications` | App Store Server Notifications v2 (JWS) | 200 |

Erros seguem um formato único `{ error: { code, message } }` com códigos: `unauthorized`, `quota_exceeded` (HTTP 402), `invalid_input`, `ai_unavailable` (503), `no_results` (200 com `titles: []`).

### 4.4 Cota e entitlements

- Entitlements são uma lista de strings com validade, não um booleano. MVP tem um só: `unlimited_search`.
- Limites lidos do KV: `limits.free.daily = 5`, `limits.pro.daily = 100` (fair use).
- Dia de cota = dia UTC.
- Cota grátis é verificada contra o device **e** contra o usuário (quando logado); a busca é bloqueada se qualquer um atingiu o limite.
- A cota só é consumida quando a resposta tem pelo menos 1 título. Falha de IA, falha de TMDB ou zero resultados não consomem.
- Implementação: reserva com `UPDATE … SET count = count + 1 WHERE count < limit` no início; se a requisição terminar sem títulos, decrementa.

### 4.5 Camada de IA

```ts
interface RecommendationProvider {
  name: 'anthropic' | 'openai'
  recommend(input: PromptInput, signal: AbortSignal): Promise<AiPick[]>
}

type AiPick = { title: string; originalTitle: string; year: number; reason: string }
```

- `AnthropicProvider`: Claude Haiku 4.5 com saída estruturada por JSON schema.
- `GeminiProvider`: Gemini Flash-Lite via `generateContent` (REST), com `generationConfig.responseMimeType = application/json` e `responseJsonSchema`.
- `OpenAIProvider`: GPT mini com `response_format: json_schema` em modo strict (disponível, desligado por padrão).
- Ambos chamam via URL do AI Gateway. O mesmo schema Zod valida a saída dos dois.
- IDs de modelo ficam em KV (`ai.models.anthropic`, `ai.models.openai`), não hardcoded.

**Orquestrador:** lê `ai.primary` e `ai.secondary` do KV (`anthropic`, `gemini` ou `openai`; padrão `gemini` → `anthropic`). Tenta o primário com timeout de 8s. Erro de rede, timeout, falha de validação Zod ou menos de 3 picks válidos → tenta o secundário. Ambos falham → `ai_unavailable`, sem consumo de cota. Cada chamada registra `{ provider, model, latencyMs, fallback, picks, promptVersion }` no Analytics Engine.

**Prompt:**

- System prompt fixo no código, versionado (`PROMPT_VERSION = 1`).
- Pede 15 picks do `mediaType` solicitado, no idioma do `locale`.
- `reason`: uma frase explicando por que o título combina com o pedido; é exibida no card.
- Exclusões entram como lista `Título (ano)`, montada pelo Worker a partir dos `excludeTmdbIds` com cache KV.
- Texto do usuário vai num bloco delimitado, limitado a 500 caracteres. Pior caso de prompt injection é uma recomendação ruim; o prompt não contém dados sensíveis.
- `excludeTmdbIds` aceita no máximo 200 IDs (app envia os mais recentes).

### 4.6 Resolução no TMDB

Para cada pick, com concorrência máxima de 6:

1. `search/{movie|tv}?query={originalTitle}&year={year}` (para TV, `first_air_date_year`).
2. Sem resultado → repete sem ano.
3. Sem resultado → repete com `title` localizado.
4. Sem resultado → descarta o pick.
5. Com ID: `/{movie|tv}/{id}?language={locale}&append_to_response=watch/providers`.
6. Providers recortados para `region`: `flatrate`, `rent`, `buy`, `free` (junção de `free` e `ads`) (nome, logo, prioridade) + `link` JustWatch.

Depois: remove IDs presentes em `excludeTmdbIds`, remove duplicados, mantém a ordem da IA, devolve até 12.

**Cache KV:** `search:{mediaType}:{hash(query,year)}` 30 dias; `tmdb:{mediaType}:{id}:{locale}` 7 dias (providers mudam, por isso TTL menor). Cache é compartilhado entre todos os usuários.

### 4.7 Modelo `Title` (resposta)

```ts
type Title = {
  tmdbId: number
  mediaType: 'movie' | 'tv'
  title: string
  originalTitle: string
  year: number | null
  overview: string
  posterPath: string | null
  backdropPath: string | null
  rating: number
  runtimeMinutes: number | null   // filmes
  seasons: number | null          // séries
  genres: string[]
  reason: string
  providers: {
    region: string
    link: string | null
    flatrate: Provider[]
    rent: Provider[]
    buy: Provider[]
    free: Provider[]   // TMDB `free` + `ads`, sem duplicados
  }
}
type Provider = { id: number; name: string; logoPath: string }
```

### 4.8 Assinaturas

- Produtos (mensal e anual, com trial) definidos no App Store Connect; preço é decisão de negócio fora desta spec.
- `appAccountToken` = UUID do usuário/device enviado na compra, para o webhook associar a transação.
- `POST /v1/appstore/notifications` valida a cadeia de certificados do JWS, trata `SUBSCRIBED`, `DID_RENEW`, `EXPIRED`, `DID_FAIL_TO_RENEW`, `REFUND`, `REVOKE` atualizando `entitlements.expires_at`.
- Após compra ou restore, o app envia o JWS da `Transaction` para `POST /v1/appstore/transactions`; o Worker valida e grava o entitlement na hora, sem esperar o webhook.

### 4.9 Dados (D1)

```sql
users        (id TEXT PK, apple_sub TEXT UNIQUE, created_at)
devices      (id TEXT PK, attest_key_id TEXT UNIQUE, public_key BLOB, counter INT, user_id TEXT NULL, created_at)
entitlements (id TEXT PK, owner_id TEXT, owner_kind TEXT CHECK(owner_kind IN ('user','device')),
              kind TEXT, expires_at, original_transaction_id TEXT UNIQUE)
usage        (owner_id TEXT, owner_kind TEXT, day TEXT, count INT, PRIMARY KEY(owner_id, owner_kind, day))
refresh_tokens (token_hash TEXT PK, device_id TEXT, expires_at)
```

### 4.10 Config (KV)

`ai.primary`, `ai.secondary`, `ai.models.anthropic`, `ai.models.gemini`, `ai.models.openai`, `limits.free.daily`, `limits.pro.daily`. Mudanças valem sem deploy.

## 5. App iOS

### 5.1 Base

iOS 18 mínimo, Swift 6 com strict concurrency, `@Observable`, `async/await`, SwiftData. XcodeGen e Lottie mantidos. Identidade visual (cores, fontes, onboarding, animação de pipoca) mantida, com ajustes pontuais.

### 5.2 Estrutura

```
FilmFinder/
  App/         FilmFinderApp, AppEnvironment (injeção de serviços)
  Core/
    API/       APIClient (URLSession, auth header, refresh automático, erros tipados)
    Auth/      DeviceAttestService, AppleSignInService, KeychainStore
    Store/     SubscriptionService (StoreKit 2: produtos, compra, restore, Transaction.updates)
  Domain/      Title, MediaType, Provider, Quota, APIError
  Data/        LibraryItem (SwiftData), LegacyImporter
  Features/
    Onboarding/ Search/ Categories/ Results/ Detail/ Library/ Paywall/ Settings/
```

Views não fazem rede; usam modelos `@Observable` que dependem de serviços injetados.

### 5.3 Unificação Filme/Série

`FilmView`+`SerieView` → `ResultsView`; `FilmCard`+`SerieCard` → `TitleCard`; `FilmDetail`+`SerieDetail` → `TitleDetail`. Tudo parametrizado por `enum MediaType { movie, tv }`. `FilmData`, `SerieData`, `WatchedContent`, `ChatGpt*`, `*ResponseModel` são removidos.

### 5.4 Biblioteca local

```swift
@Model final class LibraryItem {
  var tmdbId: Int
  var mediaType: MediaType
  var snapshot: Title        // Codable, para exibir offline
  var isFavorite: Bool
  var isWatched: Bool
  var recommendedAt: Date
}
```

Unicidade por `(tmdbId, mediaType)`. É a única fonte para Histórico, Favoritos e Assistidos e para os `excludeTmdbIds` enviados ao Worker (todos os itens, ordenados por `recommendedAt` desc, máximo 200).

**LegacyImporter:** no primeiro launch da nova versão, lê as chaves `allContent`, `favorites`, `watched`, `history` do UserDefaults, converte para `LibraryItem` (IDs TMDB já existem nos dados antigos), salva e remove as chaves. Roda uma vez; falha de decodificação é ignorada sem travar o app.

Biblioteca não sincroniza entre devices no MVP.

### 5.5 Busca, resultados e buffer

- Search e Categories montam `query` e `mediaType`.
- `ResultsModel` chama `/v1/recommendations`, registra todos os títulos recebidos como recomendados na biblioteca, mostra 3 e guarda o restante como buffer.
- Botão trocar substitui o card atual por um do buffer, sem custo de cota.
- Buffer vazio → nova busca com a mesma query (consome 1 de cota).

### 5.6 Streaming na UI

- `TitleCard`: até 3 logos de `flatrate` com rótulo "Disponível em".
- `TitleDetail`: seções Assinatura / Aluguel / Compra / Grátis; crédito "Dados de streaming: JustWatch" visível nesta tela (exigência do TMDB); botão abre `providers.link`.
- Sem providers na região: texto "Não disponível em streaming na sua região".
- Região padrão `Locale.current.region`, alterável em Ajustes.

### 5.7 Paywall e conta

- Search mostra "N buscas restantes hoje" para usuários grátis.
- `quota_exceeded` → sheet com `SubscriptionStoreView`.
- Ajustes: entrar/sair com Apple, excluir conta, restaurar compras, região, Sobre (créditos TMDB e JustWatch), política de privacidade e termos.

### 5.8 Erros

`ErrorView` reaproveitada com casos: offline, cota esgotada (abre paywall), servidor/IA indisponível (tentar de novo), sem resultados (sugere reformular).

## 6. Atribuições e conformidade

- Logo/crédito TMDB e "Dados de streaming: JustWatch" na tela Sobre; crédito JustWatch também no bloco de streaming do detalhe.
- `PrivacyInfo.xcprivacy`, App Privacy labels, URLs de política de privacidade e termos.
- Exclusão de conta in-app (seção 4.2).

## 7. Testes

**Backend** (Vitest + `@cloudflare/vitest-pool-workers`, D1 e KV locais):

- Orquestrador: primário ok; timeout → fallback; JSON inválido → fallback; menos de 3 picks → fallback; ambos falham → 503 sem consumo de cota; troca de `ai.primary` no KV.
- Cota: grátis 5/dia, 6ª busca → 402; Pro até 100; merge ao logar; logout não reseta; zero resultados não consome.
- TMDB: fixtures gravadas, matching com/sem ano, fallback para título localizado, filtro de excluídos, recorte de região.
- Auth: App Attest com fixtures, `identityToken` com JWKS mock, refresh, exclusão de conta.
- Assinaturas: JWS válido/inválido, cada tipo de notificação atualiza entitlements.

**Smoke manual:** script com 20 prompts reais PT/EN contra os dois provedores, comparando qualidade de match no TMDB e latência, antes de fixar o primário em produção.

**iOS** (Swift Testing): `APIClient` com `URLProtocol` mock (incluindo refresh), `ResultsModel` (buffer, troca, cota), `LegacyImporter` com dados reais do formato antigo, `SubscriptionService` com arquivo `.storekit` local.

## 8. Operação

- CI GitHub Actions: lint + testes do backend; build + testes iOS.
- Alertas via Analytics Engine: taxa de fallback > 20% ou taxa de erro > 5% em janela de 1h.
- Limite de gasto configurado nos painéis Anthropic e OpenAI.
- Rotacionar as chaves OpenAI e TMDB usadas na versão antiga antes do lançamento.

## 9. Fora do escopo do MVP

Sincronização da biblioteca, filtro "só meus streamings", anúncios, Android/web, notificações push, recomendações proativas.

## 10. Ordem de entrega

1. **Worker básico:** `/v1/recommendations` com IA + fallback + TMDB + providers, sem auth, só em `dev`.
2. **Refatoração iOS:** nova estrutura, SwiftData + LegacyImporter, unificação Filme/Série, busca ponta a ponta contra o Worker dev, streaming na UI.
3. **Identidade e cota:** App Attest, Sign in with Apple, refresh, `/v1/me`, exclusão de conta, cota.
4. **Monetização:** StoreKit 2, `/v1/appstore/*`, paywall.
5. **Lançamento:** CI, alertas, privacidade, App Store Connect, TestFlight.

Cada fatia termina com o app funcional.
