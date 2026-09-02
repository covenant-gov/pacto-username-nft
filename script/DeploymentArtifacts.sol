// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {VmSafe} from 'forge-std/Vm.sol';

/// @notice Writes JSON artifacts under deployments/<chainId>/ when running forge script
abstract contract DeploymentArtifacts is Script {
  using stdJson for string;

  /// @notice Returns whether deployment JSON should be written (broadcast/resume only — not dry-run simulations)
  function _shouldWriteDeploymentJson() internal view returns (bool) {
    return vm.isContext(VmSafe.ForgeContext.ScriptBroadcast) || vm.isContext(VmSafe.ForgeContext.ScriptResume);
  }

  /// @notice Resolves the deployment JSON path for a filename
  /// @param filename The JSON filename
  /// @return path The deployment JSON path
  function _deploymentJsonPath(string memory filename) internal view returns (string memory path) {
    path = string.concat('deployments/', vm.toString(block.chainid), '/', filename);
  }

  /// @notice Reads pactoSimple7702Account from pacto-squad-sponsor eip7702 artifact when present locally
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

  /// @notice Writes deployment JSON to disk
  /// @param json The serialized JSON object
  /// @param filename The target filename
  function _writeDeploymentJson(string memory json, string memory filename) internal {
    vm.createDir(string.concat('deployments/', vm.toString(block.chainid)), true);
    vm.writeJson(json, _deploymentJsonPath(filename));
  }

  /// @notice Writes the username system deployment artifact
  /// @param entryPoint The EntryPoint v0.7 address
  /// @param allowed7702Implementation The allowlisted 7702 account implementation
  /// @param usernameSystemFactory The factory address
  /// @param pactoUsernameNft The username NFT address
  /// @param globalSponsorPool The global sponsor pool address
  /// @param bootstrapMintPool The bootstrap mint pool address
  /// @param sponsorPolicyRegistry The policy registry address
  /// @param bootstrapClaimPolicy The bootstrap claim policy address
  /// @param pactoGlobalPaymaster The global paymaster address
  /// @param policyVersion The initial policy version after seeding
  /// @param deployer The deployer address
  function _writeFullSystemJson(
    address entryPoint,
    address allowed7702Implementation,
    address usernameSystemFactory,
    address pactoUsernameNft,
    address globalSponsorPool,
    address bootstrapMintPool,
    address sponsorPolicyRegistry,
    address bootstrapClaimPolicy,
    address pactoGlobalPaymaster,
    uint256 policyVersion,
    address deployer
  ) internal {
    if (!_shouldWriteDeploymentJson()) return;

    string memory _key = 'username_full_system';
    vm.serializeUint(_key, 'chainId', block.chainid);
    vm.serializeAddress(_key, 'entryPoint', entryPoint);
    vm.serializeAddress(_key, 'allowed7702Implementation', allowed7702Implementation);
    vm.serializeAddress(_key, 'usernameSystemFactory', usernameSystemFactory);
    vm.serializeAddress(_key, 'pactoUsernameNft', pactoUsernameNft);
    vm.serializeAddress(_key, 'globalSponsorPool', globalSponsorPool);
    vm.serializeAddress(_key, 'bootstrapMintPool', bootstrapMintPool);
    vm.serializeAddress(_key, 'sponsorPolicyRegistry', sponsorPolicyRegistry);
    vm.serializeAddress(_key, 'bootstrapClaimPolicy', bootstrapClaimPolicy);
    vm.serializeAddress(_key, 'pactoGlobalPaymaster', pactoGlobalPaymaster);
    vm.serializeUint(_key, 'policyVersion', policyVersion);
    string memory _json = vm.serializeAddress(_key, 'deployer', deployer);
    _writeDeploymentJson(_json, 'full-system.json');
  }

  /// @notice Thrown when no EIP-7702 allowlist address is configured
  error Zero7702Allowlist();
}
