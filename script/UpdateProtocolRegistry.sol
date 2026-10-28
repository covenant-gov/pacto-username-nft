// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {IPactoGlobalPaymaster} from 'interfaces/IPactoGlobalPaymaster.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

import {Constants} from 'script/Constants.sol';
import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';
import {PolicySeeding} from 'script/PolicySeeding.sol';
import {PolicyTargetResolver} from 'script/PolicyTargetResolver.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Migrates the protocol registry to a coherent paymaster generation
contract UpdateProtocolRegistry is DeploymentArtifacts {
  using stdJson for string;

  bytes4 internal constant _INITIATE_ADDRESS_TRANSFER_SELECTOR = 0xa4df29b5;
  bytes4 internal constant _CLAIM_ADDRESS_TRANSFER_SELECTOR = 0xbf010955;
  bytes4 internal constant _CANCEL_ADDRESS_TRANSFER_SELECTOR = 0xd88208dc;

  function run() external {
    string memory _json = _readFullSystemJson();
    PactoProtocolRegistry _registry = PactoProtocolRegistry(_json.readAddress('.protocolRegistry'));
    IPactoGlobalPaymaster _paymaster = IPactoGlobalPaymaster(vm.envAddress('PAYMASTER'));
    IPactoProtocolRegistry.ProtocolAddresses memory _next = _addressesFromPaymaster(_paymaster);
    if (address(_paymaster.REGISTRY()) != address(_registry)) revert PaymasterRegistryMismatch();

    address _oldNft = _registry.usernameNft();
    address _oldPolicy = _registry.policy();

    vm.startBroadcast();
    address _deployer = _broadcastDeployer();
    _registry.migrate(_next);
    if (_deployer == _registry.owner()) {
      if (_next.usernameNft != _oldNft) {
        _migrateMemberPolicySelectors(SponsorPolicyRegistry(_next.policy), _oldNft, _next.usernameNft);
      }
      if (_next.policy != _oldPolicy) {
        Constants.ChainConfig memory _config = Constants.getConfig(block.chainid);
        PolicySeeding.seedMemberPolicyV4(
          SponsorPolicyRegistry(_next.policy),
          _next.usernameNft,
          PolicyTargetResolver.resolveRequiredFactoryTargets(_config)
        );
      }
    }
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

  /// @notice Copies the next address book from a deployed paymaster's immutables
  /// @param paymaster The next-generation paymaster
  /// @return addresses The coherent protocol addresses
  function _addressesFromPaymaster(IPactoGlobalPaymaster paymaster)
    internal
    view
    returns (IPactoProtocolRegistry.ProtocolAddresses memory addresses)
  {
    addresses.usernameNft = address(paymaster.USERNAME_NFT());
    addresses.paymaster = address(paymaster);
    addresses.pool = address(paymaster.POOL());
    addresses.bootstrapPool = address(paymaster.BOOTSTRAP_POOL());
    addresses.policy = address(paymaster.POLICY());
    addresses.bootstrapPolicy = address(paymaster.BOOTSTRAP_POLICY());
    addresses.entryPoint = address(PactoGlobalPaymaster(payable(address(paymaster))).entryPoint());
    addresses.allowed7702Implementation = paymaster.ALLOWED_7702_IMPLEMENTATION();
    addresses.eip7702Enabled = _resolveEip7702Enabled(addresses.allowed7702Implementation);
  }

  /// @notice Resolves whether the next generation accepts EIP-7702 senders
  /// @param allowed7702 The paymaster's pinned EIP-7702 implementation
  /// @return enabled True when EIP-7702 sponsorship should be enabled
  function _resolveEip7702Enabled(address allowed7702) internal view returns (bool enabled) {
    if (vm.envExists('EIP7702_ENABLED')) return vm.envBool('EIP7702_ENABLED');
    enabled = allowed7702 != address(0);
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
    console.log('eip7702Enabled:', registry.eip7702Enabled());
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
    artifact.eip7702Enabled = registry.eip7702Enabled();
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

  /// @notice Migrates member-path NFT sponsorship from legacy selectors or targets to a new NFT
  function _migrateMemberPolicySelectors(SponsorPolicyRegistry policy, address oldNft, address newNft) internal {
    if (oldNft != address(0)) {
      policy.deregisterSelector(oldNft, _INITIATE_ADDRESS_TRANSFER_SELECTOR);
      policy.deregisterSelector(oldNft, _CLAIM_ADDRESS_TRANSFER_SELECTOR);
      policy.deregisterSelector(oldNft, _CANCEL_ADDRESS_TRANSFER_SELECTOR);
      if (policy.isContractAllowed(oldNft)) policy.deregisterTarget(oldNft);
    }
    policy.registerTarget(newNft);
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

  /// @notice Thrown when the paymaster is bound to a different registry
  error PaymasterRegistryMismatch();
}
