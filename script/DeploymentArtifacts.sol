// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {VmSafe} from 'forge-std/Vm.sol';

/// @notice Writes JSON artifacts under deployments/<chainId>/ (broadcast/resume) or simulations/<chainId>/ (dry-run)
abstract contract DeploymentArtifacts is Script {
  using stdJson for string;

  /// @notice Returns whether deployment JSON should be written (dry-run, broadcast, or resume — not forge test)
  function _shouldWriteDeploymentJson() internal view returns (bool) {
    return vm.isContext(VmSafe.ForgeContext.ScriptDryRun) || vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)
      || vm.isContext(VmSafe.ForgeContext.ScriptResume);
  }

  /// @notice Artifact root for writes: simulations on dry-run, deployments on broadcast/resume
  /// @return root The directory name under the package root
  function _artifactWriteRoot() internal view returns (string memory root) {
    root = vm.isContext(VmSafe.ForgeContext.ScriptDryRun) ? 'simulations' : 'deployments';
  }

  /// @notice Resolves the canonical deployment JSON path for a filename (reads always use deployments/)
  /// @param filename The JSON filename
  /// @return path The deployment JSON path
  function _deploymentJsonPath(string memory filename) internal view returns (string memory path) {
    path = string.concat('deployments/', vm.toString(block.chainid), '/', filename);
  }

  /// @notice Reads pactoSimple7702Account from pacto-aa eip7702 artifact when present locally
  /// @return account The allowlisted 7702 account or zero
  function _readPactoSimple7702FromArtifact() internal view returns (address account) {
    try vm.readFile(_deploymentJsonPath('eip7702-account.json')) returns (string memory json) {
      account = json.readAddress('.pactoSimple7702Account');
    } catch {
      account = address(0);
    }
  }

  /// @notice Resolves the allowlisted EIP-7702 implementation for deployment
  /// @param configDefault The chain default from Constants
  /// @return allowed7702 The resolved implementation address
  function _resolveAllowed7702Implementation(address configDefault) internal view returns (address allowed7702) {
    allowed7702 = _readPactoSimple7702FromArtifact();
    if (allowed7702 != address(0)) return allowed7702;

    allowed7702 = vm.envOr('PACTO_7702_ACCOUNT', configDefault);
    if (allowed7702 == address(0)) revert Zero7702Allowlist();
  }

  /// @notice Writes deployment JSON to disk (simulations/ on dry-run, deployments/ on broadcast/resume)
  /// @param json The serialized JSON object
  /// @param filename The target filename
  function _writeDeploymentJson(string memory json, string memory filename) internal {
    string memory root = _artifactWriteRoot();
    string memory dir = string.concat(root, '/', vm.toString(block.chainid));
    vm.createDir(dir, true);
    vm.writeJson(json, string.concat(dir, '/', filename));
  }

  /// @notice Addresses and metadata written to full-system.json
  /// @param entryPoint The ERC-4337 EntryPoint
  /// @param allowed7702Implementation The allowlisted EIP-7702 account implementation
  /// @param eip7702Enabled Whether EIP-7702 delegated senders are accepted
  /// @param protocolRegistry The protocol address book
  /// @param usernameSystemFactory The username system factory
  /// @param pactoUsernameNft The username NFT
  /// @param globalSponsorPool The global sponsor pool
  /// @param bootstrapMintPool The bootstrap mint pool
  /// @param sponsorPolicyRegistry The member-path sponsor policy registry
  /// @param bootstrapClaimPolicy The bootstrap claim policy
  /// @param pactoGlobalPaymaster The global paymaster
  /// @param nostrClaimLink The linked NostrClaimLink library
  /// @param policyVersion The initial sponsor policy version
  /// @param deployer The forge script broadcaster
  struct FullSystemArtifact {
    address entryPoint;
    address allowed7702Implementation;
    bool eip7702Enabled;
    address protocolRegistry;
    address usernameSystemFactory;
    address pactoUsernameNft;
    address globalSponsorPool;
    address bootstrapMintPool;
    address sponsorPolicyRegistry;
    address bootstrapClaimPolicy;
    address pactoGlobalPaymaster;
    address nostrClaimLink;
    uint256 policyVersion;
    address deployer;
  }

  /// @notice Writes the username system deployment artifact
  /// @param artifact The deployment addresses and metadata
  function _writeFullSystemJson(FullSystemArtifact memory artifact) internal {
    if (!_shouldWriteDeploymentJson()) return;
    if (artifact.nostrClaimLink == address(0)) revert MissingNostrClaimLink();

    string memory _key = 'username_full_system';
    vm.serializeUint(_key, 'chainId', block.chainid);
    vm.serializeAddress(_key, 'entryPoint', artifact.entryPoint);
    vm.serializeAddress(_key, 'allowed7702Implementation', artifact.allowed7702Implementation);
    vm.serializeBool(_key, 'eip7702Enabled', artifact.eip7702Enabled);
    vm.serializeAddress(_key, 'protocolRegistry', artifact.protocolRegistry);
    vm.serializeAddress(_key, 'usernameSystemFactory', artifact.usernameSystemFactory);
    vm.serializeAddress(_key, 'pactoUsernameNft', artifact.pactoUsernameNft);
    vm.serializeAddress(_key, 'globalSponsorPool', artifact.globalSponsorPool);
    vm.serializeAddress(_key, 'bootstrapMintPool', artifact.bootstrapMintPool);
    vm.serializeAddress(_key, 'sponsorPolicyRegistry', artifact.sponsorPolicyRegistry);
    vm.serializeAddress(_key, 'bootstrapClaimPolicy', artifact.bootstrapClaimPolicy);
    vm.serializeAddress(_key, 'pactoGlobalPaymaster', artifact.pactoGlobalPaymaster);
    vm.serializeAddress(_key, 'nostrClaimLink', artifact.nostrClaimLink);
    vm.serializeUint(_key, 'policyVersion', artifact.policyVersion);
    string memory _json = vm.serializeAddress(_key, 'deployer', artifact.deployer);
    _writeDeploymentJson(_json, 'full-system.json');
  }

  /// @notice Writes a standalone username NFT deployment artifact
  /// @param pactoUsernameNft The newly deployed username NFT
  /// @param deployer The deployer address
  function _writeUsernameNftJson(address pactoUsernameNft, address deployer) internal {
    if (!_shouldWriteDeploymentJson()) return;

    string memory _key = 'username_nft';
    vm.serializeUint(_key, 'chainId', block.chainid);
    vm.serializeAddress(_key, 'pactoUsernameNft', pactoUsernameNft);
    string memory _json = vm.serializeAddress(_key, 'deployer', deployer);
    _writeDeploymentJson(_json, 'username-nft.json');
  }

  /// @notice Writes a standalone sponsor policy registry deployment artifact
  /// @param sponsorPolicyRegistry The newly deployed policy registry
  /// @param deployer The deployer address
  function _writeSponsorPolicyRegistryJson(address sponsorPolicyRegistry, address deployer) internal {
    if (!_shouldWriteDeploymentJson()) return;

    string memory _key = 'sponsor_policy_registry';
    vm.serializeUint(_key, 'chainId', block.chainid);
    vm.serializeAddress(_key, 'sponsorPolicyRegistry', sponsorPolicyRegistry);
    string memory _json = vm.serializeAddress(_key, 'deployer', deployer);
    _writeDeploymentJson(_json, 'sponsor-policy-registry.json');
  }

  /// @notice Reads NostrClaimLink from forge broadcast libraries, then CREATE2 transactions
  /// @return link The library address or zero when unavailable
  function _readNostrClaimLinkFromBroadcast() internal view returns (address link) {
    string memory path =
      string.concat('broadcast/DeployUsernameSystem.sol/', vm.toString(block.chainid), '/run-latest.json');
    try vm.readFile(path) returns (string memory raw) {
      return _parseNostrClaimLinkFromBroadcastJson(raw);
    } catch {}
  }

  /// @notice Parses NostrClaimLink from a forge broadcast JSON body
  /// @dev Prefer `.libraries`; mid-script that array is often empty, so fall back to CREATE2 txs
  /// @param raw The broadcast run-latest.json contents
  /// @return link The library address or zero when unavailable
  function _parseNostrClaimLinkFromBroadcastJson(string memory raw) internal view returns (address link) {
    if (vm.keyExistsJson(raw, '.libraries')) {
      string[] memory libs = raw.readStringArray('.libraries');
      for (uint256 i; i < libs.length; ++i) {
        if (_containsSubstring(libs[i], 'NostrClaimLink')) {
          return vm.parseAddress(_suffixAfterLastColon(libs[i]));
        }
      }
    }

    for (uint256 i;; ++i) {
      string memory nameKey = string.concat('.transactions[', vm.toString(i), '].contractName');
      if (!vm.keyExistsJson(raw, nameKey)) break;
      if (keccak256(bytes(raw.readString(nameKey))) != keccak256(bytes('NostrClaimLink'))) continue;
      return raw.readAddress(string.concat('.transactions[', vm.toString(i), '].contractAddress'));
    }
  }

  function _containsSubstring(string memory haystack, string memory needle) internal pure returns (bool) {
    bytes memory h = bytes(haystack);
    bytes memory n = bytes(needle);
    if (n.length > h.length) return false;
    for (uint256 i; i <= h.length - n.length; ++i) {
      bool matched = true;
      for (uint256 j; j < n.length; ++j) {
        if (h[i + j] != n[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return true;
    }
    return false;
  }

  function _suffixAfterLastColon(string memory s) internal pure returns (string memory) {
    bytes memory b = bytes(s);
    uint256 last = type(uint256).max;
    for (uint256 i; i < b.length; ++i) {
      if (b[i] == ':') last = i;
    }
    require(last != type(uint256).max && last + 1 < b.length, 'artifacts: bad library entry');
    uint256 start = last + 1;
    bytes memory out = new bytes(b.length - start);
    for (uint256 i; i < out.length; ++i) {
      out[i] = b[start + i];
    }
    return string(out);
  }

  /// @notice Thrown when no EIP-7702 allowlist address is configured
  error Zero7702Allowlist();

  /// @notice Thrown when NostrClaimLink cannot be resolved for a deployment artifact write
  error MissingNostrClaimLink();
}
