# pacto-app Follow-ups — Username NFT + Global Sponsor

Tracking items for [pacto-app](https://github.com/covenant-gov/pacto-app). Contracts live in **pacto-username-nft**; this doc is the integration checklist.

---

## Address book & bindings

- [ ] Add `globalUsernameSponsor` section to `src/lib/evm/pacto-protocol-addresses.json` from `deployments/<chainId>/full-system.json`
- [ ] Include `bootstrapMintPool` and `bootstrapClaimPolicy` (new in v2 deploy JSON)
- [ ] Document in `docs/wallet/PROTOCOL_ADDRESS_BOOK.md`
- [ ] Generate Alloy bindings for `PactoUsernameNFT`, `PactoGlobalPaymaster`, `GlobalSponsorPool`, `BootstrapMintPool`, `SponsorPolicyRegistry`
- [ ] Pin Sepolia addresses after first broadcast deploy

---

## Sponsor path

- [ ] Implement `sponsor_path.rs`: EOA → squad → global member fallback
- [ ] Add **bootstrap lane** for first `claim()` when `npubOf(rosterEvm) == 0`
- [ ] Extend `gov_module_write.rs` (and other write paths) to use global member path when squad unavailable
- [ ] Add `global_paymasterAndData` encoder in `src/lib/evm/sponsor/global_paymaster.ts` + golden vectors
- [ ] Member path: always pass `policy = address(0)` — custom policies rejected on-chain
- [ ] Add `pacto_actions.ts` catalog synced with `policyVersion`
- [ ] Preflight bootstrap: `canBootstrapClaim` + `BootstrapMintPool.spendablePoolWei()`
- [ ] Preflight member: `eligibleMember(rosterEvm)` + policy target check before `eth_sendUserOperation`
- [ ] Ledger: optional `global_sponsored_fee_usage` table (mirror squad ledger)

---

## Username claim & identity

- [ ] Profile UI: claim username flow (availability check, lowercase validation)
- [ ] Shared `hashNostrClaim(pubkey, evmAddress, name, nonce, issuedAt, salt)` encoder — match `NostrClaimLink.sol`
- [ ] Golden vectors: port `test/fixtures/claim-link.golden.json` + `generate-vectors.mjs` for client CI
- [ ] EIP-712 `ClaimBinding` v2 signing (domain version **`2`**, includes `salt`)
- [ ] BIP-340 Schnorr signing over `PactoNostrClaim` digest (64-byte sig)
- [ ] Nostr link event publish (kind **`31337`**) — relay/social layer; same field tuple as on-chain binding
- [ ] Publish + cache link event; verify on badge render (two-layer: relay + chain)
- [ ] Verified checkmark component using `recordOf` + Nostr link + `evmAddress` match
- [ ] Pending transfer indicator (`isPendingTransfer`)
- [ ] Settings: initiate / claim / cancel address transfer flows
- [ ] Optional: re-publish Nostr link after address rotation

---

## Launchpad / SquadAdmin

- [ ] SquadAdmin-only bootstrap path when Nave Pirata not deployed — use global member sponsor if NFT holder
- [ ] Post-deploy: protocol admin or app hook to `registerTarget(squadAdminClone)` on policy registry
- [ ] Coordinate with pacto-gov deploy helper addresses per chain

---

## Policy admin (protocol ops)

- [ ] Script or multisig runbook to `registerTarget` / `registerSelector` for new app features
- [ ] Do **not** register `claim()` on member registry — bootstrap uses fixed `BootstrapClaimPolicy`
- [ ] Bump `policyVersion` communicated to clients (release notes / address book update)
- [ ] Seed pacto-gov factory addresses on Mainnet / Arbitrum when known
- [ ] Fund `BootstrapMintPool` separately from `GlobalSponsorPool`; monitor bootstrap drain

---

## Testing

- [ ] Unit tests: paymaster data encoder round-trip
- [ ] Unit tests: `hashNostrClaim` + EIP-712 v2 golden vector parity with contract fixtures
- [ ] E2E Sepolia: bootstrap sponsored claim → badge → global sponsored rotation write
- [ ] E2E Sepolia: claim username → global sponsored gov or SquadAdmin write
- [ ] Regression: squad sponsor still preferred when squad pool funded
- [ ] Regression: bootstrap path rejected after mint (`npubOf != 0`)
- [ ] Smoke doc in `docs/wallet/OPERATOR_SMOKE.md` (upstream)

---

## Open product decisions (pacto-app)

| Topic | Notes |
|-------|-------|
| Nostr link event kind | **`31337`** (`PACTO_USERNAME_CLAIM_KIND`) — document in NIP-style app doc |
| Badge on DMs vs profile only | UX choice |
| Show username vs npub fallback | When unclaimed |
| Bootstrap pool funding | Ops-funded; monitor Sybil drain (valid dual sig per claim) |
| EIP-7702 activation gas | Separate ops pool; out of bootstrap/global sponsor scope |

---

## Related upstream docs

- [PACTO_SQUAD_SPONSOR.md](https://github.com/covenant-gov/pacto-app/blob/main/docs/wallet/PACTO_SQUAD_SPONSOR.md)
- [PACTO_GOV.md](https://github.com/covenant-gov/pacto-app/blob/main/docs/wallet/PACTO_GOV.md)
- [DESKTOP_CLIENT_INTEGRATION.md](./DESKTOP_CLIENT_INTEGRATION.md) (this repo)
