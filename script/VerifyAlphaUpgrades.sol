// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Etherscan verification for one-off alpha NFT + SponsorPolicyRegistry upgrades
/// @dev Prefer this over VerifyDeploy after pointer swaps: full-system verify re-checks factory/registry
///      whose on-chain bytecode may lag Ownable2Step / NFT constructor source. Requires FOUNDRY_PROFILE=verify.
contract VerifyAlphaUpgrades is Script {
  using stdJson for string;

  string internal constant _NFT = 'src/contracts/PactoUsernameNFT.sol:PactoUsernameNFT';
  string internal constant _POLICY = 'src/contracts/SponsorPolicyRegistry.sol:SponsorPolicyRegistry';

  function run() external {
    string memory chain = _chainSlug();
    string memory fullSystem = _readDeploymentJson('full-system.json');

    address nft = _resolveNft();
    address policy = _resolvePolicy();
    address owner = Ownable(fullSystem.readAddress('.protocolRegistry')).owner();
    address nostrClaimLink = fullSystem.readAddress('.nostrClaimLink');
    require(nft != address(0), 'verify-alpha: missing NFT');
    require(policy != address(0), 'verify-alpha: missing policy');
    require(nostrClaimLink != address(0), 'verify-alpha: missing NostrClaimLink');
    require(nostrClaimLink.code.length > 0, 'verify-alpha: NostrClaimLink has no code');

    string memory libFlag =
      string.concat('src/contracts/utils/NostrClaimLink.sol:NostrClaimLink:', vm.toString(nostrClaimLink));

    console.log('Verifying alpha upgrades on', chain);
    console.log('PactoUsernameNFT:', nft);
    console.log('SponsorPolicyRegistry:', policy);
    console.log('Owner (SPR ctor):', owner);
    console.log('NostrClaimLink:', nostrClaimLink);

    _verify(nft, _NFT, chain, new bytes(0), libFlag);
    _verify(policy, _POLICY, chain, abi.encode(owner), '');
  }

  /// @notice Prefers username-nft.json, else full-system.json
  function _resolveNft() internal view returns (address nft) {
    try vm.readFile(_deploymentPath('username-nft.json')) returns (string memory json) {
      nft = json.readAddress('.pactoUsernameNft');
      if (nft != address(0)) return nft;
    } catch {}
    nft = _readDeploymentJson('full-system.json').readAddress('.pactoUsernameNft');
  }

  /// @notice Prefers sponsor-policy-registry.json, else full-system.json
  function _resolvePolicy() internal view returns (address policy) {
    try vm.readFile(_deploymentPath('sponsor-policy-registry.json')) returns (string memory json) {
      policy = json.readAddress('.sponsorPolicyRegistry');
      if (policy != address(0)) return policy;
    } catch {}
    policy = _readDeploymentJson('full-system.json').readAddress('.sponsorPolicyRegistry');
  }

  function _readDeploymentJson(string memory filename) internal view returns (string memory json) {
    string memory path = _deploymentPath(filename);
    try vm.readFile(path) returns (string memory raw) {
      json = raw;
    } catch {
      revert MissingDeploymentArtifact(path);
    }
  }

  function _deploymentPath(string memory filename) internal view returns (string memory path) {
    path = string.concat('deployments/', vm.toString(block.chainid), '/', filename);
  }

  function _verify(
    address addr,
    string memory contractId,
    string memory chain,
    bytes memory constructorArgs,
    string memory libraries
  ) internal {
    console.log('==>', contractId, addr);
    bool withLibs = bytes(libraries).length != 0;
    string[] memory inputs = new string[](withLibs ? 14 : 12);
    inputs[0] = 'forge';
    inputs[1] = 'verify-contract';
    inputs[2] = vm.toString(addr);
    inputs[3] = contractId;
    inputs[4] = '--rpc-url';
    inputs[5] = chain;
    inputs[6] = '--chain';
    inputs[7] = chain;
    inputs[8] = '--constructor-args';
    inputs[9] = vm.toString(constructorArgs);
    inputs[10] = '--skip-is-verified-check';
    inputs[11] = '--watch';
    if (withLibs) {
      inputs[12] = '--libraries';
      inputs[13] = libraries;
    }
    console.log(string(vm.ffi(inputs)));
  }

  function _chainSlug() internal view returns (string memory) {
    uint256 id = block.chainid;
    if (id == 11_155_111) return 'sepolia';
    if (id == 1) return 'mainnet';
    if (id == 42_161) return 'arbitrum';
    revert UnsupportedChain(id);
  }

  /// @notice Thrown when a required deployment artifact is missing
  error MissingDeploymentArtifact(string path);

  /// @notice Thrown when the chain is unsupported
  error UnsupportedChain(uint256 chainId);
}
