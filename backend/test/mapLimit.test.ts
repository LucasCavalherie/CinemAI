import { describe, expect, it } from 'vitest'
import { mapLimit } from '../src/lib/mapLimit'

describe('mapLimit', () => {
  it('preserves order and never exceeds the limit', async () => {
    let active = 0
    let peak = 0
    const out = await mapLimit([5, 1, 4, 2, 3], 2, async (n) => {
      active++
      peak = Math.max(peak, active)
      await new Promise((r) => setTimeout(r, n))
      active--
      return n * 10
    })
    expect(out).toEqual([50, 10, 40, 20, 30])
    expect(peak).toBe(2)
  })

  it('handles empty input', async () => {
    expect(await mapLimit([], 3, async (x) => x)).toEqual([])
  })
})
