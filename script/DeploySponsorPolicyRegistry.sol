// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Deploys a replacement SponsorPolicyRegistry for alpha registry upgrades
contract DeploySponsorPolicyRegistry is DeploymentArtifacts {
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
    address _owner = vm.envOr('PROTOCOL_OWNER', PactoProtocolRegistry(_registry).owner());

    vm.startBroadcast();
    address _deployer = _broadcastDeployer();
    SponsorPolicyRegistry _policy = new SponsorPolicyRegistry(_owner);
    vm.stopBroadcast();

    console.log('PactoProtocolRegistry:', _registry);
    console.log('SponsorPolicyRegistry:', address(_policy));
    console.log('Owner:', _owner);
    console.log('Deployer:', _deployer);

    _writeSponsorPolicyRegistryJson(address(_policy), _deployer);
  }

  /// @notice Returns the forge script broadcaster address
  /// @return deployer The broadcaster address
  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing
  error MissingDeploymentArtifact(string path);
}
