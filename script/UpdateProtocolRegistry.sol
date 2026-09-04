// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Updates protocol registry slots and migrates NFT member policy selectors
contract UpdateProtocolRegistry is DeploymentArtifacts {
  using stdJson for string;

  bytes4 internal constant _INITIATE_ADDRESS_TRANSFER_SELECTOR = 0xa4df29b5;
  bytes4 internal constant _CLAIM_ADDRESS_TRANSFER_SELECTOR = 0xbf010955;
  bytes4 internal constant _CANCEL_ADDRESS_TRANSFER_SELECTOR = 0xd88208dc;

  /// @notice Optional registry slot updates from env / artifacts
  /// @param usernameNft Replacement username NFT address (zero skips)
  /// @param paymaster Replacement paymaster address (zero skips)
  /// @param pool Replacement global sponsor pool address (zero skips)
  /// @param bootstrapPool Replacement bootstrap mint pool address (zero skips)
  /// @param policy Replacement member policy registry address (zero skips)
  /// @param bootstrapPolicy Replacement bootstrap claim policy address (zero skips)
  /// @param entryPoint Replacement EntryPoint address (zero skips)
  /// @param allowed7702 Replacement EIP-7702 allowlist address when has7702Update
  /// @param has7702Update Whether an EIP-7702 allowlist update was supplied
  struct RegistryUpdates {
    address usernameNft;
    address paymaster;
    address pool;
    address bootstrapPool;
    address policy;
    address bootstrapPolicy;
    address entryPoint;
    address allowed7702;
    bool has7702Update;
  }

  function run() external {
    string memory _json = _readFullSystemJson();
    PactoProtocolRegistry _registry = PactoProtocolRegistry(_json.readAddress('.protocolRegistry'));
    RegistryUpdates memory _updates = _loadUpdates();
    _requireHasUpdates(_updates);

    vm.startBroadcast();
    address _deployer = _broadcastDeployer();
    _applyUpdates(_registry, _updates, _deployer);
    vm.stopBroadcast();

    _logRegistry(_registry);
    _writeFullSystemJson(_buildArtifact(_registry, _json, _deployer));
  }

  /// @notice Reads deployments/<chainId>/full-system.json
  function _readFullSystemJson() internal view returns (string memory json) {
    string memory _path = _deploymentJsonPath('full-system.json');
    try vm.readFile(_path) returns (string memory raw) {
      json = raw;
    } catch {
      revert MissingDeploymentArtifact(_path);
    }
  }

  /// @notice Loads optional update addresses from env and local deployment artifacts
  function _loadUpdates() internal view returns (RegistryUpdates memory updates) {
    updates.usernameNft = _resolveUsernameNft();
    updates.paymaster = vm.envOr('PAYMASTER', address(0));
    updates.pool = vm.envOr('POOL', address(0));
    updates.bootstrapPool = vm.envOr('BOOTSTRAP_POOL', address(0));
    updates.policy = _resolvePolicy();
    updates.bootstrapPolicy = vm.envOr('BOOTSTRAP_POLICY', address(0));
    updates.entryPoint = vm.envOr('ENTRY_POINT', address(0));
    (updates.allowed7702, updates.has7702Update) = _resolveAllowed7702Update();
  }

  /// @notice Reverts when no registry update was requested
  function _requireHasUpdates(RegistryUpdates memory updates) internal pure {
    require(
      updates.usernameNft != address(0) || updates.paymaster != address(0) || updates.pool != address(0)
        || updates.bootstrapPool != address(0) || updates.policy != address(0) || updates.bootstrapPolicy != address(0)
        || updates.entryPoint != address(0) || updates.has7702Update,
      'update: no registry changes'
    );
  }

  /// @notice Applies owner-gated registry updates during broadcast
  function _applyUpdates(PactoProtocolRegistry registry, RegistryUpdates memory updates, address deployer) internal {
    address _oldNft = registry.usernameNft();
    if (updates.usernameNft != address(0) && updates.usernameNft != _oldNft) {
      registry.set(IPactoProtocolRegistry.ProtocolComponent.UsernameNft, updates.usernameNft);
      if (deployer == registry.owner()) {
        _migrateMemberPolicySelectors(SponsorPolicyRegistry(registry.policy()), _oldNft, updates.usernameNft);
      }
    }
    if (updates.paymaster != address(0)) {
      registry.set(IPactoProtocolRegistry.ProtocolComponent.Paymaster, updates.paymaster);
    }
    if (updates.pool != address(0)) registry.set(IPactoProtocolRegistry.ProtocolComponent.Pool, updates.pool);
    if (updates.bootstrapPool != address(0)) {
      registry.set(IPactoProtocolRegistry.ProtocolComponent.BootstrapPool, updates.bootstrapPool);
    }
    if (updates.policy != address(0) && updates.policy != registry.policy()) {
      registry.set(IPactoProtocolRegistry.ProtocolComponent.Policy, updates.policy);
      if (deployer == registry.owner()) {
        _seedMemberPolicySelectors(SponsorPolicyRegistry(updates.policy), registry.usernameNft());
      }
    }
    if (updates.bootstrapPolicy != address(0)) {
      registry.set(IPactoProtocolRegistry.ProtocolComponent.BootstrapPolicy, updates.bootstrapPolicy);
    }
    if (updates.entryPoint != address(0)) {
      registry.set(IPactoProtocolRegistry.ProtocolComponent.EntryPoint, updates.entryPoint);
    }
    if (updates.has7702Update) {
      registry.set(IPactoProtocolRegistry.ProtocolComponent.Allowed7702Implementation, updates.allowed7702);
    }
  }

  /// @notice Logs the live registry slots
  function _logRegistry(PactoProtocolRegistry registry) internal view {
    console.log('PactoProtocolRegistry:', address(registry));
    console.log('usernameNft:', registry.usernameNft());
    console.log('paymaster:', registry.paymaster());
    console.log('pool:', registry.pool());
    console.log('bootstrapPool:', registry.bootstrapPool());
    console.log('policy:', registry.policy());
    console.log('bootstrapPolicy:', registry.bootstrapPolicy());
    console.log('entryPoint:', registry.entryPoint());
    console.log('allowed7702Implementation:', registry.allowed7702Implementation());
    console.log('policyVersion:', SponsorPolicyRegistry(registry.policy()).policyVersion());
  }

  /// @notice Builds the refreshed full-system artifact from the live registry
  function _buildArtifact(
    PactoProtocolRegistry registry,
    string memory json,
    address deployer
  ) internal view returns (FullSystemArtifact memory artifact) {
    artifact.entryPoint = registry.entryPoint();
    artifact.allowed7702Implementation = registry.allowed7702Implementation();
    artifact.protocolRegistry = address(registry);
    artifact.usernameSystemFactory = json.readAddress('.usernameSystemFactory');
    artifact.pactoUsernameNft = registry.usernameNft();
    artifact.globalSponsorPool = registry.pool();
    artifact.bootstrapMintPool = registry.bootstrapPool();
    artifact.sponsorPolicyRegistry = registry.policy();
    artifact.bootstrapClaimPolicy = registry.bootstrapPolicy();
    artifact.pactoGlobalPaymaster = registry.paymaster();
    artifact.nostrClaimLink = _resolveNostrClaimLink(json);
    artifact.policyVersion = SponsorPolicyRegistry(registry.policy()).policyVersion();
    artifact.deployer = deployer;
  }

  /// @notice Resolves the replacement username NFT from env or username-nft.json
  function _resolveUsernameNft() internal view returns (address usernameNft) {
    usernameNft = vm.envOr('USERNAME_NFT', address(0));
    if (usernameNft != address(0)) return usernameNft;

    try vm.readFile(_deploymentJsonPath('username-nft.json')) returns (string memory nftJson) {
      usernameNft = nftJson.readAddress('.pactoUsernameNft');
    } catch {
      usernameNft = address(0);
    }
  }

  /// @notice Resolves the replacement member policy from env or sponsor-policy-registry.json
  function _resolvePolicy() internal view returns (address policy) {
    policy = vm.envOr('POLICY', address(0));
    if (policy != address(0)) return policy;

    try vm.readFile(_deploymentJsonPath('sponsor-policy-registry.json')) returns (string memory policyJson) {
      policy = policyJson.readAddress('.sponsorPolicyRegistry');
    } catch {
      policy = address(0);
    }
  }

  /// @notice Resolves Allowed7702 from ALLOWED_7702 env or eip7702-account.json
  /// @return allowed7702 The allowlist address (may be zero when clearing via env)
  /// @return hasUpdate True when an update should be applied
  function _resolveAllowed7702Update() internal view returns (address allowed7702, bool hasUpdate) {
    if (vm.envExists('ALLOWED_7702')) {
      return (vm.envAddress('ALLOWED_7702'), true);
    }
    allowed7702 = _readPactoSimple7702FromArtifact();
    if (allowed7702 != address(0)) return (allowed7702, true);
    return (address(0), false);
  }

  /// @notice Registers member-path username NFT rotation selectors on a policy registry
  function _seedMemberPolicySelectors(SponsorPolicyRegistry policy, address usernameNft) internal {
    policy.registerSelector(usernameNft, _INITIATE_ADDRESS_TRANSFER_SELECTOR);
    policy.registerSelector(usernameNft, _CLAIM_ADDRESS_TRANSFER_SELECTOR);
    policy.registerSelector(usernameNft, _CANCEL_ADDRESS_TRANSFER_SELECTOR);
  }

  /// @notice Migrates member-path NFT rotation selectors from old NFT to new NFT
  function _migrateMemberPolicySelectors(SponsorPolicyRegistry policy, address oldNft, address newNft) internal {
    if (oldNft != address(0)) {
      policy.deregisterSelector(oldNft, _INITIATE_ADDRESS_TRANSFER_SELECTOR);
      policy.deregisterSelector(oldNft, _CLAIM_ADDRESS_TRANSFER_SELECTOR);
      policy.deregisterSelector(oldNft, _CANCEL_ADDRESS_TRANSFER_SELECTOR);
    }
    _seedMemberPolicySelectors(policy, newNft);
  }

  function _resolveNostrClaimLink(string memory json) internal view returns (address link) {
    if (vm.keyExistsJson(json, '.nostrClaimLink')) {
      link = json.readAddress('.nostrClaimLink');
      if (link != address(0)) return link;
    }
    link = _readNostrClaimLinkFromBroadcast();
  }

  /// @notice Returns the forge script broadcaster address
  /// @return deployer The broadcaster address
  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing
  error MissingDeploymentArtifact(string path);
}
