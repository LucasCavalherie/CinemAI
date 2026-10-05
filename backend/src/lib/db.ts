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
