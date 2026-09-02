# pacto-app Follow-ups — Username NFT + Global Sponsor

Tracking items for [pacto-app](https://github.com/covenant-gov/pacto-app). Contracts live in **pacto-username-nft**; this doc is the integration checklist.

---

## Address book & bindings

- [ ] Add `globalUsernameSponsor` section to `src/lib/evm/pacto-protocol-addresses.json` from `deployments/<chainId>/full-system.json`
- [ ] Document in `docs/wallet/PROTOCOL_ADDRESS_BOOK.md`
- [ ] Generate Alloy bindings for `PactoUsernameNFT`, `PactoGlobalPaymaster`, `GlobalSponsorPool`, `SponsorPolicyRegistry`
- [ ] Pin Sepolia addresses after first broadcast deploy

---

## Sponsor path

- [ ] Implement `sponsor_path.rs`: EOA → squad → global fallback
- [ ] Extend `gov_module_write.rs` (and other write paths) to use global path when squad unavailable
- [ ] Add `global_paymasterAndData` encoder in `src/lib/evm/sponsor/global_paymaster.ts` + golden vectors
- [ ] Add `pacto_actions.ts` catalog synced with `policyVersion`
- [ ] Preflight: `eligibleMember(rosterEvm)` + policy target check before `eth_sendUserOperation`
- [ ] Ledger: optional `global_sponsored_fee_usage` table (mirror squad ledger)

---

## Username claim & identity

- [ ] Profile UI: claim username flow (availability check, lowercase validation)
- [ ] EIP-712 `ClaimBinding` signing (match `PactoUsernameNFT` domain)
- [ ] Nostr dual-signed link event (kind TBD — suggest app-specific kind in NIP-style doc)
- [ ] Publish + cache link event; verify on badge render
- [ ] Verified checkmark component using `recordOf` + Nostr link + `evmAddress` match
- [ ] Pending transfer indicator (`isPendingTransfer`)
- [ ] Settings: initiate / claim / cancel address transfer flows
- [ ] Optional: re-publish Nostr link after address rotation

---

## Launchpad / SquadAdmin

- [ ] SquadAdmin-only bootstrap path when Nave Pirata not deployed — use global sponsor if NFT holder
- [ ] Post-deploy: protocol admin or app hook to `registerTarget(squadAdminClone)` on policy registry
- [ ] Coordinate with pacto-gov deploy helper addresses per chain

---

## Policy admin (protocol ops)

- [ ] Script or multisig runbook to `registerTarget` / `registerSelector` for new app features
- [ ] Bump `policyVersion` communicated to clients (release notes / address book update)
- [ ] Seed pacto-gov factory addresses on Mainnet / Arbitrum when known

---

## Testing

- [ ] Unit tests: paymaster data encoder round-trip
- [ ] E2E Sepolia: claim username → global sponsored gov or SquadAdmin write
- [ ] Regression: squad sponsor still preferred when squad pool funded
- [ ] Smoke doc in `docs/wallet/OPERATOR_SMOKE.md` (upstream)

---

## Open product decisions (pacto-app)

| Topic | Notes |
|-------|-------|
| Nostr link event kind | App-specific; document before ship |
| Badge on DMs vs profile only | UX choice |
| Show username vs npub fallback | When unclaimed |
| Global sponsor for first claim | Policy + pool must allow; otherwise EOA ETH |

---

## Related upstream docs

- [PACTO_SQUAD_SPONSOR.md](https://github.com/covenant-gov/pacto-app/blob/main/docs/wallet/PACTO_SQUAD_SPONSOR.md)
- [PACTO_GOV.md](https://github.com/covenant-gov/pacto-app/blob/main/docs/wallet/PACTO_GOV.md)
- [DESKTOP_CLIENT_INTEGRATION.md](./DESKTOP_CLIENT_INTEGRATION.md) (this repo)
