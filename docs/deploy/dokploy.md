# Deploy do backend na VPS com Dokploy

O backend roda como um container Node (Hono + SQLite). A API é a mesma do Worker da Cloudflare, então o app só precisa
trocar a URL. Código: `backend/src/node/`, imagem: `backend/Dockerfile`.

## 1. Criar a aplicação

No Dokploy: **Project → Create Service → Application**.

| Campo | Valor |
|---|---|
| Provider | GitHub (ou Git) — repositório `LucasCavalherie/CinemAI` (ou o seu fork) |
| Branch | `relaunch` (depois `main`) |
| Build Type | **Dockerfile** |
| Build Path / Docker Context Path | `backend` |
| Dockerfile Path | `Dockerfile` |

## 2. Variáveis de ambiente (aba *Environment*)

Obrigatórias — o container **não sobe** (e lista o que falta nos logs) sem elas:

| Variável | Valor |
|---|---|
| `JWT_SECRET` | segredo aleatório, mínimo 32 caracteres (`openssl rand -base64 48`) |
| `TMDB_TOKEN` | *API Read Access Token* do TMDB |
| `GEMINI_API_KEY` e/ou `ANTHROPIC_API_KEY` (e/ou `OPENAI_API_KEY`) | chaves dos provedores de IA (pelo menos uma) |
| `APPLE_TEAM_ID` | Team ID de 10 caracteres (ex.: `L2AH2M48T4`) |
| `APPLE_BUNDLE_ID` | `com.andre.filmfinder` |

Para o botão "Entrar com a Apple": `APPLE_KEY_ID` (Key ID da chave do Sign in with Apple) e `APPLE_PRIVATE_KEY`
(conteúdo do `.p8`; em uma linha só, com `\n` no lugar das quebras — o serviço converte).

Recomendadas:

| Variável | Produção | Observação |
|---|---|---|
| `ALLOW_UNATTESTED` | `false` | `true` só em ambiente de teste (aceita dispositivos sem App Attest, ex.: simulador) |
| `ALLOW_PROVIDER_OVERRIDE` | `false` | `true` só em teste (header `x-ai-provider`) |
| `APPATTEST_ENVS` | `production` | builds rodados pelo Xcode usam `development`: em teste use `development,production` |

Opcionais (ajustes sem mexer no código; aplicados ao reiniciar): `AI_PRIMARY` (`gemini`/`anthropic`/`openai`),
`AI_SECONDARY`, `AI_MODEL_GEMINI`, `AI_MODEL_ANTHROPIC`, `AI_MODEL_OPENAI`, `LIMIT_FREE_DAILY` (padrão 5),
`LIMIT_PRO_DAILY` (padrão 100). `PORT` (3000) e `DATABASE_PATH` (`/data/filmfinder.db`) já vêm na imagem.

## 3. Volume do banco (aba *Advanced → Volumes*)

Adicione um **Volume Mount** (tipo *Volume*, **não** *Bind Mount*): nome `filmfinder-data`, caminho no container `/data`.
Sem isso o SQLite é apagado a cada redeploy. Com volume nomeado o Docker herda as permissões da imagem (usuário `node`);
um bind mount de pasta do host criada como root causa "unable to open database file".

## 4. Domínio e HTTPS (aba *Domains*)

Host: `api.seudominio.com` (DNS tipo A apontando para o IP da VPS), **Container Port `3000`**, HTTPS ligado
(Let's Encrypt). Não publique a porta 3000 direto no host: o limitador de taxa lê o IP do cabeçalho `X-Forwarded-For`
enviado pelo Traefik, e esse cabeçalho só é confiável atrás dele.

## 5. Deploy e verificação

Clique em **Deploy**. O container fica `healthy` em ~15 s. Depois:

```bash
curl -s https://api.seudominio.com/health                       # {"ok":true}
curl -s -X POST https://api.seudominio.com/v1/auth/challenge   # {"challenge":"..."}
```
Em ambiente de teste (`ALLOW_UNATTESTED=true`) dá para exercitar o ciclo completo com `backend/scripts/smoke.ts`:
`SMOKE_URL=https://api.seudominio.com npm run smoke` (gasta créditos de IA).

## 6. Apontar o app para a VPS

Em `Config/Release.xcconfig` (e `Debug.xcconfig`, se quiser testar), troque
`API_BASE_URL = https:/$()/api.seudominio.com` e gere o projeto de novo (`xcodegen generate`).

## 7. Operação

- **Instância única:** o SQLite não deve ser compartilhado entre réplicas; mantenha 1 réplica.
- **Backup:** copie o arquivo do volume com o banco consistente (WAL):
  `docker exec <container> node -e "require('node:sqlite'); const {DatabaseSync}=require('node:sqlite'); const d=new DatabaseSync('/data/filmfinder.db'); d.exec(\"VACUUM INTO '/data/backup.db'\")"`
  e leve `backup.db` para fora (ou use os *Backups de volume* do Dokploy).
- **Logs:** cada chamada de IA e cada resolução do TMDB aparece como JSON nos logs do container (`ai_call`, `resolve`).
- **Atualizar:** novo deploy; as migrações em `backend/migrations/` são aplicadas sozinhas e uma vez só.
