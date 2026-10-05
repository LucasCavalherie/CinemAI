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
