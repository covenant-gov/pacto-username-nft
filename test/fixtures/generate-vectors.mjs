/**
 * Generates golden vectors for NostrClaimLink Solidity tests.
 * Run: node test/fixtures/generate-vectors.mjs
 */
import { createHash } from 'node:crypto';
import { finalizeEvent, getPublicKey, generateSecretKey, serializeEvent } from 'nostr-tools';

const KIND = 31337;
const TAG_D = 'pacto-username-claim-v1';

function claimTagsJson(evmAddress, name, nonce, issuedAt, saltHex) {
  const evm = evmAddress.toLowerCase();
  return `[["d","${TAG_D}"],["evm","${evm}"],["name","${name}"],["nonce","${nonce}"],["issued_at","${issuedAt}"],["salt","${saltHex.toLowerCase()}"]]`;
}

function claimLinkEventId(pubkeyHex, createdAt, evmAddress, name, nonce, issuedAt, saltHex) {
  const serialized = `[0,"${pubkeyHex}",${createdAt},${KIND},${claimTagsJson(evmAddress, name, nonce, issuedAt, saltHex)},""]`;
  return createHash('sha256').update(serialized, 'utf8').digest('hex');
}

function npubHashFromPubkey(pubkeyHex) {
  const pubkey = Buffer.from(pubkeyHex, 'hex');
  const npubBytes = Buffer.concat([Buffer.from([0x02]), pubkey]);
  return createHash('sha256').update(npubBytes).digest('hex');
}

const secretKey = generateSecretKey();
const pubkeyHex = getPublicKey(secretKey);
const createdAt = 1_735_689_600;
const evmAddress = '0xa11ce00000000000000000000000000000000000';
const name = 'alice';
const nonce = 1;
const issuedAt = createdAt;
const salt = '0x' + '11'.repeat(32);

const template = {
  kind: KIND,
  created_at: createdAt,
  tags: [
    ['d', TAG_D],
    ['evm', evmAddress.toLowerCase()],
    ['name', name],
    ['nonce', String(nonce)],
    ['issued_at', String(issuedAt)],
    ['salt', salt.toLowerCase()],
  ],
  content: '',
};

const signed = finalizeEvent(template, secretKey);
const serialized = serializeEvent(signed);
const expectedId = claimLinkEventId(pubkeyHex, createdAt, evmAddress, name, nonce, issuedAt, salt);

console.log(
  JSON.stringify(
    {
      pubkey: `0x${pubkeyHex}`,
      createdAt,
      evmAddress,
      name,
      nonce,
      issuedAt,
      salt,
      npubHash: `0x${npubHashFromPubkey(pubkeyHex)}`,
      eventId: signed.id,
      expectedId,
      serialized,
      signature: signed.sig,
      idMatchesLocalSerializer: signed.id === expectedId,
    },
    null,
    2,
  ),
);

if (signed.id !== expectedId) {
  console.error('Local serializer mismatch — inspect tag ordering or encoding');
  process.exit(1);
}
