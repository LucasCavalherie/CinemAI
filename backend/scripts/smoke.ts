import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'

type Prompt = { query: string; mediaType: 'movie' | 'tv'; locale: string; region: string }
type Row = { provider: string; query: string; status: number; latencyMs: number; titles: number; top3: string[]; withStreaming: number }

const baseUrl = process.env.SMOKE_URL ?? 'http://localhost:8787'
const devKey = process.env.DEV_API_KEY
if (!devKey) throw new Error('Set DEV_API_KEY')

const prompts = JSON.parse(readFileSync(new URL('./smoke-prompts.json', import.meta.url), 'utf8')) as Prompt[]
const rows: Row[] = []
const providers = (process.env.SMOKE_PROVIDERS ?? 'anthropic,gemini').split(',')

for (const provider of providers) {
  for (const p of prompts) {
    const started = Date.now()
    const res = await fetch(`${baseUrl}/v1/recommendations`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-dev-key': devKey, 'x-ai-provider': provider },
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
