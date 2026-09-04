# pacto-username-nft

Unique usernames for [Pacto](https://github.com/covenant-gov/pacto-app), keyed by Nostr npub, with **global fallback gas sponsorship** for app on-chain actions.

- **Identity:** `PactoUsernameNFT` — one npub → one `UsernameRecord` (name + EVM controller); EIP-712 claim; 2-step address rotation
- **Registry:** `PactoProtocolRegistry` — mutable alpha address book for NFT / paymaster / pools / policies
- **Sponsorship:** `PactoGlobalPaymaster` + `GlobalSponsorPool` + modular `SponsorPolicyRegistry`
- **Deploy:** `UsernameSystemFactory` chain singleton

Squad-scoped sponsorship remains in [pacto-squad-sponsor](https://github.com/covenant-gov/pacto-squad-sponsor) (preferred when available).

## Docs

- [TECH_SPEC.md](docs/TECH_SPEC.md) — architecture and locked decisions
- [DESKTOP_CLIENT_INTEGRATION.md](docs/DESKTOP_CLIENT_INTEGRATION.md) — pacto-app UserOp / badge / path selection
- [PACTO_APP_FOLLOWUPS.md](docs/PACTO_APP_FOLLOWUPS.md) — upstream integration checklist

## Setup

1. [Install Foundry](https://book.getfoundry.sh/getting-started/installation)
2. Copy `.env.example` → `.env`
3. Optional: `cargo install lintspec bulloak`
4. `pnpm install`

## Build & test

```bash
pnpm build
pnpm test:unit
pnpm coverage
```

## Deploy

Configure `.env` and import deployer keys into Foundry keystore (`cast wallet import …`).

```bash
source .env

# Dry-run (writes deployments/*.json with simulated addresses; does not send txs)
pnpm simulate-deploy:sepolia

# Broadcast + write deployments/<chainId>/full-system.json, then verify via VerifyDeploy
pnpm deploy:sepolia
pnpm deploy:mainnet
pnpm deploy:arbitrum

# Re-verify from deployments/<chainId>/full-system.json (includes NostrClaimLink library)
pnpm verify:sepolia

# After a real deploy: EntryPoint deposit + paymaster stake (needs live full-system.json)
pnpm fund:paymaster:sepolia

# Alpha: deploy a replacement NFT, then point the protocol registry at it
pnpm deploy:nft:sepolia
pnpm update:registry:sepolia

# UN-1 (AA epic): set Allowed7702 from deployments/<chainId>/eip7702-account.json
# Do NOT run full-system deploy — keep live protocolRegistry for squad SS-3
pnpm update:registry:sepolia

# Optional: Ownable2Step SponsorPolicyRegistry swap (no full redeploy)
pnpm deploy:policy:sepolia
pnpm update:registry:sepolia   # POLICY from sponsor-policy-registry.json; reseeds rotation selectors
```

Verify EIP-7702 allowlist after UN-1:

```bash
cast call $PROTOCOL_REGISTRY 'allowed7702Implementation()(address)' --rpc-url $SEPOLIA_RPC
cast call $GLOBAL_PM 'ALLOWED_7702_IMPLEMENTATION()(address)' --rpc-url $SEPOLIA_RPC
# both == 0x2E9156deE65d7946305C334824e2648Ff9128f45
```

Fund the global sponsor pool:

```bash
cast send $POOL "deposit()" --value 1ether --rpc-url $SEPOLIA_RPC --private-key $OPS_KEY
```

`simulate-*` never signs or pays gas. Use `pnpm deploy:sepolia` (with `--broadcast`) to unlock the keystore, deploy on-chain, and produce a fundable artifact. If `FOUNDRY_ETH_KEYSTORE_PASSWORD` is set in your environment, forge skips the interactive password prompt.

## License

MIT — see [LICENSE](LICENSE)
