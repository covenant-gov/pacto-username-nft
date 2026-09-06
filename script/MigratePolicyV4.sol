// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';

import {Constants} from 'script/Constants.sol';
import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';
import {PolicySeeding} from 'script/PolicySeeding.sol';
import {PolicyTargetResolver} from 'script/PolicyTargetResolver.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Seeds policy v4 targets on a newly deployed SponsorPolicyRegistry for alpha migration
contract MigratePolicyV4 is DeploymentArtifacts {
  using stdJson for string;

  function run() external {
    string memory _path = _deploymentJsonPath('full-system.json');
    string memory _json;
    try vm.readFile(_path) returns (string memory raw) {
      _json = raw;
    } catch {
      revert MissingDeploymentArtifact(_path);
    }

    address _registry = _json.readAddress('.protocolRegistry');
    address _usernameNft = PactoProtocolRegistry(_registry).usernameNft();
    address _policy = _resolvePolicyAddress();
    Constants.ChainConfig memory _config = Constants.getConfig(block.chainid);

    vm.startBroadcast();
    address _deployer = _broadcastDeployer();
    SponsorPolicyRegistry _policyRegistry = SponsorPolicyRegistry(_policy);

    if (_deployer == PactoProtocolRegistry(_registry).owner()) {
      PolicySeeding.seedMemberPolicyV4(
        _policyRegistry, _usernameNft, PolicyTargetResolver.resolveFactoryTargets(_config)
      );
    }
    vm.stopBroadcast();

    console.log('PactoProtocolRegistry:', _registry);
    console.log('SponsorPolicyRegistry:', _policy);
    console.log('Username NFT:', _usernameNft);
    console.log('Policy version:', _policyRegistry.policyVersion());
    console.log('Deployer:', _deployer);
  }

  /// @notice Resolves the policy registry from env or sponsor-policy-registry.json
  function _resolvePolicyAddress() internal view returns (address policy) {
    policy = vm.envOr('POLICY', address(0));
    if (policy != address(0)) return policy;

    try vm.readFile(_deploymentJsonPath('sponsor-policy-registry.json')) returns (string memory policyJson) {
      policy = policyJson.readAddress('.sponsorPolicyRegistry');
    } catch {
      policy = address(0);
    }

    if (policy == address(0)) revert MissingPolicyAddress();
  }

  /// @notice Returns the forge script broadcaster address
  /// @return deployer The broadcaster address
  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing
  error MissingDeploymentArtifact(string path);

  /// @notice Thrown when no policy registry address is configured
  error MissingPolicyAddress();
}
