// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
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
    address _owner = Ownable(_registry).owner();
    address _scriptOwner = vm.envOr('PROTOCOL_OWNER', address(0));

    vm.startBroadcast();
    address _deployer = _broadcastDeployer();
    if (_scriptOwner == address(0)) _scriptOwner = _deployer;
    // Prefer the live registry owner so the NFT admin matches protocol ownership
    address _nftOwner = _owner == address(0) ? _scriptOwner : _owner;

    PactoUsernameNFT _nft = new PactoUsernameNFT(_nftOwner);
    vm.stopBroadcast();

    console.log('PactoProtocolRegistry:', _registry);
    console.log('PactoUsernameNFT:', address(_nft));
    console.log('NFT owner:', _nftOwner);
    console.log('Deployer:', _deployer);

    _writeUsernameNftJson(address(_nft), _nftOwner, _deployer);
  }

  /// @notice Returns the forge script broadcaster address
  /// @return deployer The broadcaster address
  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing
  error MissingDeploymentArtifact(string path);
}
