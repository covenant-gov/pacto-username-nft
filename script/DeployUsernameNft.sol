// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Deploys a replacement PactoUsernameNFT for alpha registry upgrades
contract DeployUsernameNft is DeploymentArtifacts {
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

    vm.startBroadcast();
    address _deployer = _broadcastDeployer();
    PactoUsernameNFT _nft = new PactoUsernameNFT();
    vm.stopBroadcast();

    console.log('PactoProtocolRegistry:', _registry);
    console.log('PactoUsernameNFT:', address(_nft));
    console.log('Deployer:', _deployer);

    _writeUsernameNftJson(address(_nft), _deployer);
  }

  /// @notice Returns the forge script broadcaster address
  /// @return deployer The broadcaster address
  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing
  error MissingDeploymentArtifact(string path);
}
