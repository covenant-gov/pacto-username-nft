# pacto-username-nft

Unique usernames for [Pacto](https://github.com/covenant-gov/pacto-app), keyed by Nostr npub, with **global fallback gas sponsorship** for app on-chain actions.

- **Identity:** `PactoUsernameNFT` — one npub → one `UsernameRecord` (name + EVM controller); EIP-712 claim; 2-step address rotation
- **Registry:** `PactoProtocolRegistry` — generation pointer; owner `migrate`s a coherent paymaster bundle; `disableEip7702` kill switch
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

# Dry-run (writes simulations/<chainId>/*.json with simulated addresses; does not send txs)
pnpm simulate-deploy:sepolia

# Broadcast + write deployments/<chainId>/full-system.json, then verify via VerifyDeploy
pnpm deploy:sepolia
pnpm deploy:mainnet
pnpm deploy:arbitrum

# Re-verify full stack from deployments/<chainId>/full-system.json (fresh DeployUsernameSystem only)
pnpm verify:sepolia

# After a generation migrate: verify the new paymaster (and any newly deployed deps)
pnpm verify:upgrades:sepolia

# After a real deploy: EntryPoint deposit + paymaster stake (needs live full-system.json)
pnpm fund:paymaster:sepolia

# Alpha: deploy a replacement NFT, construct a new paymaster with it, then migrate
pnpm deploy:nft:sepolia
PAYMASTER=<new-paymaster> pnpm update:registry:sepolia

# UN-1 (AA epic): construct a paymaster with the 7702 impl from
# deployments/<chainId>/eip7702-account.json, then migrate. Do NOT run full-system
# deploy — keep live protocolRegistry for squad SS-3
PAYMASTER=<new-paymaster> pnpm update:registry:sepolia

# In-place policy allowlist edits do not need migrate. Swapping the policy contract
# requires a new paymaster + PAYMASTER=<new-paymaster> pnpm update:registry:sepolia
```

Verify EIP-7702 allowlist and kill switch:

```bash
cast call $PROTOCOL_REGISTRY 'allowed7702Implementation()(address)' --rpc-url $SEPOLIA_RPC
cast call $PROTOCOL_REGISTRY 'eip7702Enabled()(bool)' --rpc-url $SEPOLIA_RPC
cast call $GLOBAL_PM 'ALLOWED_7702_IMPLEMENTATION()(address)' --rpc-url $SEPOLIA_RPC
# impls match; eip7702Enabled is the live disable switch
```

Fund the global sponsor pool:

```bash
cast send $POOL "deposit()" --value 1ether --rpc-url $SEPOLIA_RPC --private-key $OPS_KEY
```

`simulate-*` never signs or pays gas. Use `pnpm deploy:sepolia` (with `--broadcast`) to unlock the keystore, deploy on-chain, and produce a fundable artifact. If `FOUNDRY_ETH_KEYSTORE_PASSWORD` is set in your environment, forge skips the interactive password prompt.

`deploy:sepolia`, `deploy:mainnet`, `deploy:arbitrum`, and `deploy:nft:sepolia` pass `--slow --gas-estimate-multiplier 1000`. `DeployUsernameSystem` CREATE2-deploys `NostrClaimLink` via Arachnid (`salt = 0` → `0x7D7EA6cb…`), then `CREATE`s the factory; `DeployUsernameNft` CREATE2-deploys the same library before the NFT. Foundry’s prague estimate for that CREATE2 is ~514k; Sepolia `eth_estimateGas` is ~4.0M, so 1000% sets a ~5.1M **limit**. The factory estimate is ~7.58M → ~75.8M limit. **You pay `gasUsed × price`, not the limit**; unused gas is refunded. `--slow` waits for the library receipt before the factory tx.

`forge script --gas-limit` is the script-EVM / block cap, **not** the signed tx gas — do not use it to pad CREATE2. Broadcast tx gas is `--gas-estimate-multiplier` (percent of Foundry’s estimate).

## License

MIT — see [LICENSE](LICENSE)
