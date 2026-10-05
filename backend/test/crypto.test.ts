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
