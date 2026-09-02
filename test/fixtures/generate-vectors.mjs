/**
 * Generates golden vectors for NostrClaimLink struct-hash tests.
 * Run: npm install && node generate-vectors.mjs
 */
import { createHash } from 'node:crypto';
import { schnorr } from '@noble/curves/secp256k1';
import { bytesToHex, hexToBytes } from '@noble/hashes/utils';
import { keccak256, encodeAbiParameters, parseAbiParameters, toBytes } from 'viem';
import { generateSecretKey, getPublicKey } from 'nostr-tools';

const NOSTR_CLAIM_TYPEHASH = keccak256(
  toBytes(
    'PactoNostrClaim(bytes32 pubkey,address evmAddress,bytes32 nameHash,uint256 nonce,uint256 issuedAt,bytes32 salt)',
  ),
);

function npubHashFromPubkey(pubkeyHex) {
  const pubkey = Buffer.from(pubkeyHex, 'hex');
  const npubBytes = Buffer.concat([Buffer.from([0x02]), pubkey]);
  return createHash('sha256').update(npubBytes).digest('hex');
}

function hashNostrClaim(pubkeyHex, evmAddress, name, nonce, issuedAt, saltHex) {
  const pubkey = `0x${pubkeyHex}`;
  const salt = saltHex;
  const nameHash = keccak256(toBytes(name));

  return keccak256(
    encodeAbiParameters(
      parseAbiParameters('bytes32, bytes32, address, bytes32, uint256, uint256, bytes32'),
      [NOSTR_CLAIM_TYPEHASH, pubkey, evmAddress, nameHash, BigInt(nonce), BigInt(issuedAt), salt],
    ),
  );
}

const secretKey = generateSecretKey();
const pubkeyHex = getPublicKey(secretKey);
const evmAddress = '0xA11Ce00000000000000000000000000000000000';
const name = 'alice';
const nonce = 1;
const issuedAt = 1_735_689_600;
const salt = `0x${'11'.repeat(32)}`;

const digest = hashNostrClaim(pubkeyHex, evmAddress, name, nonce, issuedAt, salt);
const digestBytes = hexToBytes(digest.slice(2));
const signature = schnorr.sign(digestBytes, secretKey);
const signatureHex = bytesToHex(signature);

console.log(
  JSON.stringify(
    {
      pubkey: `0x${pubkeyHex}`,
      evmAddress,
      name,
      nonce,
      issuedAt,
      salt,
      npubHash: `0x${npubHashFromPubkey(pubkeyHex)}`,
      nostrClaimDigest: digest,
      signature: signatureHex,
    },
    null,
    2,
  ),
);
