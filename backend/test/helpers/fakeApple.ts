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
