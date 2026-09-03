// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IUsernameSystemFactory} from 'interfaces/IUsernameSystemFactory.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Etherscan verification for username system contracts from deployments/<chainId>/full-system.json
/// @dev Requires FOUNDRY_PROFILE=verify (ffi = true). Run after DeployUsernameSystem.
contract VerifyDeploy is Script {
  using stdJson for string;

  string internal constant _FACTORY = 'src/contracts/UsernameSystemFactory.sol:UsernameSystemFactory';
  string internal constant _REGISTRY = 'src/contracts/PactoProtocolRegistry.sol:PactoProtocolRegistry';
  string internal constant _NFT = 'src/contracts/PactoUsernameNFT.sol:PactoUsernameNFT';
  string internal constant _POOL = 'src/contracts/GlobalSponsorPool.sol:GlobalSponsorPool';
  string internal constant _BOOTSTRAP_POOL = 'src/contracts/BootstrapMintPool.sol:BootstrapMintPool';
  string internal constant _POLICY = 'src/contracts/SponsorPolicyRegistry.sol:SponsorPolicyRegistry';
  string internal constant _BOOTSTRAP_POLICY = 'src/contracts/BootstrapClaimPolicy.sol:BootstrapClaimPolicy';
  string internal constant _PAYMASTER = 'src/contracts/PactoGlobalPaymaster.sol:PactoGlobalPaymaster';
  string internal constant _NOSTR_CLAIM_LINK = 'src/contracts/utils/NostrClaimLink.sol:NostrClaimLink';

  struct Deployed {
    address entryPoint;
    address allowed7702;
    address registry;
    address factory;
    address nft;
    address pool;
    address bootstrapPool;
    address policy;
    address bootstrapPolicy;
    address paymaster;
    address owner;
    address nostrClaimLink;
  }

  function run() external {
    string memory chain = _chainSlug();
    Deployed memory d = _loadAndAssert();

    string memory libFlag =
      string.concat('src/contracts/utils/NostrClaimLink.sol:NostrClaimLink:', vm.toString(d.nostrClaimLink));

    console.log('Verifying username contracts on', chain);
    _verify(d.nostrClaimLink, _NOSTR_CLAIM_LINK, chain, new bytes(0), '');
    _verify(d.registry, _REGISTRY, chain, abi.encode(d.owner, d.factory), '');
    _verify(d.factory, _FACTORY, chain, abi.encode(IEntryPoint(d.entryPoint), d.owner, d.allowed7702), libFlag);
    _verify(d.nft, _NFT, chain, abi.encode(d.owner), libFlag);
    _verify(d.pool, _POOL, chain, abi.encode(IPactoProtocolRegistry(d.registry)), '');
    _verify(d.bootstrapPool, _BOOTSTRAP_POOL, chain, abi.encode(IPactoProtocolRegistry(d.registry)), '');
    _verify(d.policy, _POLICY, chain, abi.encode(d.owner), '');
    _verify(d.bootstrapPolicy, _BOOTSTRAP_POLICY, chain, abi.encode(IPactoProtocolRegistry(d.registry)), '');
    _verify(
      d.paymaster, _PAYMASTER, chain, abi.encode(IEntryPoint(d.entryPoint), IPactoProtocolRegistry(d.registry)), ''
    );
  }

  function _loadAndAssert() internal view returns (Deployed memory d) {
    string memory json = vm.readFile(string.concat('deployments/', vm.toString(block.chainid), '/full-system.json'));
    d.entryPoint = json.readAddress('.entryPoint');
    d.allowed7702 = json.readAddress('.allowed7702Implementation');
    d.registry = json.readAddress('.protocolRegistry');
    d.factory = json.readAddress('.usernameSystemFactory');
    d.nft = json.readAddress('.pactoUsernameNft');
    d.pool = json.readAddress('.globalSponsorPool');
    d.bootstrapPool = json.readAddress('.bootstrapMintPool');
    d.policy = json.readAddress('.sponsorPolicyRegistry');
    d.bootstrapPolicy = json.readAddress('.bootstrapClaimPolicy');
    d.paymaster = json.readAddress('.pactoGlobalPaymaster');
    d.owner = Ownable(d.registry).owner();
    d.nostrClaimLink = _resolveNostrClaimLink(json);

    IUsernameSystemFactory factory = IUsernameSystemFactory(d.factory);
    IPactoProtocolRegistry registry = IPactoProtocolRegistry(d.registry);
    require(factory.REGISTRY() == d.registry, 'verify: registry mismatch');
    require(factory.USERNAME_NFT() == d.nft, 'verify: NFT mismatch');
    require(factory.POOL() == d.pool, 'verify: pool mismatch');
    require(factory.BOOTSTRAP_POOL() == d.bootstrapPool, 'verify: bootstrap pool mismatch');
    require(factory.POLICY() == d.policy, 'verify: policy mismatch');
    require(factory.BOOTSTRAP_POLICY() == d.bootstrapPolicy, 'verify: bootstrap policy mismatch');
    require(factory.PAYMASTER() == d.paymaster, 'verify: paymaster mismatch');
    require(registry.usernameNft() == d.nft, 'verify: registry NFT mismatch');
    require(registry.paymaster() == d.paymaster, 'verify: registry paymaster mismatch');
    require(registry.pool() == d.pool, 'verify: registry pool mismatch');
    require(registry.bootstrapPool() == d.bootstrapPool, 'verify: registry bootstrap pool mismatch');
    require(registry.policy() == d.policy, 'verify: registry policy mismatch');
    require(registry.bootstrapPolicy() == d.bootstrapPolicy, 'verify: registry bootstrap policy mismatch');
    require(registry.entryPoint() == d.entryPoint, 'verify: registry entryPoint mismatch');
    require(registry.allowed7702Implementation() == d.allowed7702, 'verify: registry 7702 mismatch');
    require(d.nostrClaimLink != address(0), 'verify: missing NostrClaimLink');
    require(d.nostrClaimLink.code.length > 0, 'verify: NostrClaimLink has no code');
  }

  /// @notice Resolves NostrClaimLink from artifact, then broadcast libraries, then env
  function _resolveNostrClaimLink(string memory json) internal view returns (address link) {
    if (vm.keyExistsJson(json, '.nostrClaimLink')) {
      link = json.readAddress('.nostrClaimLink');
      if (link != address(0)) return link;
    }

    link = _readNostrClaimLinkFromBroadcast();
    if (link != address(0)) return link;

    link = vm.envOr('NOSTR_CLAIM_LINK', address(0));
  }

  /// @notice Reads linked NostrClaimLink address from forge broadcast libraries
  function _readNostrClaimLinkFromBroadcast() internal view returns (address link) {
    string memory path =
      string.concat('broadcast/DeployUsernameSystem.sol/', vm.toString(block.chainid), '/run-latest.json');
    try vm.readFile(path) returns (string memory raw) {
      string[] memory libs = raw.readStringArray('.libraries');
      for (uint256 i; i < libs.length; ++i) {
        if (_contains(libs[i], 'NostrClaimLink')) {
          return vm.parseAddress(_suffixAfterLastColon(libs[i]));
        }
      }
    } catch {}
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

  function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
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
    require(last != type(uint256).max && last + 1 < b.length, 'verify: bad library entry');
    uint256 start = last + 1;
    bytes memory out = new bytes(b.length - start);
    for (uint256 i; i < out.length; ++i) {
      out[i] = b[start + i];
    }
    return string(out);
  }

  /// @notice Thrown when the chain is unsupported
  error UnsupportedChain(uint256 chainId);
}
