// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {UsernameSystemFactory} from 'contracts/UsernameSystemFactory.sol';

import {Constants} from 'script/Constants.sol';
import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

/// @notice Deploys the username NFT and global sponsorship system on a supported chain
contract DeployUsernameSystem is Script, DeploymentArtifacts {
  UsernameSystemFactory internal _factory;

  bytes4 internal constant _INITIATE_ADDRESS_TRANSFER_SELECTOR = 0xa4df29b5;
  bytes4 internal constant _CLAIM_ADDRESS_TRANSFER_SELECTOR = 0xbf010955;
  bytes4 internal constant _CANCEL_ADDRESS_TRANSFER_SELECTOR = 0xd88208dc;

  function run() external {
    Constants.ChainConfig memory _config = Constants.getConfig(block.chainid);
    address _allowed7702 = _resolveAllowed7702Implementation(_config.allowed7702Implementation);
    address _owner = vm.envOr('PROTOCOL_OWNER', address(0));

    vm.startBroadcast();
    address _deployer = _broadcastDeployer();
    if (_owner == address(0)) _owner = _deployer;

    _factory = new UsernameSystemFactory(IEntryPoint(_config.entryPoint), _owner, _allowed7702);
    if (_deployer == _owner) {
      _seedMemberPolicySelectors(SponsorPolicyRegistry(_factory.POLICY()), _factory.USERNAME_NFT());
    }
    vm.stopBroadcast();

    address _nostrClaimLink = _readNostrClaimLinkFromBroadcast();
    _logDeployment(_config.entryPoint, _allowed7702, _owner, _nostrClaimLink);
    _writeFullSystemJson(
      _config.entryPoint,
      _allowed7702,
      address(_factory),
      _factory.USERNAME_NFT(),
      _factory.POOL(),
      _factory.BOOTSTRAP_POOL(),
      _factory.POLICY(),
      _factory.BOOTSTRAP_POLICY(),
      _factory.PAYMASTER(),
      _nostrClaimLink,
      SponsorPolicyRegistry(_factory.POLICY()).policyVersion(),
      _deployer
    );
  }

  /// @notice Registers member-path username NFT rotation selectors on the default policy registry
  function _seedMemberPolicySelectors(SponsorPolicyRegistry policy, address usernameNft) internal {
    policy.registerSelector(usernameNft, _INITIATE_ADDRESS_TRANSFER_SELECTOR);
    policy.registerSelector(usernameNft, _CLAIM_ADDRESS_TRANSFER_SELECTOR);
    policy.registerSelector(usernameNft, _CANCEL_ADDRESS_TRANSFER_SELECTOR);
  }

  /// @notice Logs deployed contract addresses
  /// @param entryPoint The EntryPoint address
  /// @param allowed7702 The allowlisted 7702 implementation
  /// @param owner The protocol owner address
  /// @param nostrClaimLink The linked NostrClaimLink library
  function _logDeployment(
    address entryPoint,
    address allowed7702,
    address owner,
    address nostrClaimLink
  ) internal view {
    console.log('UsernameSystemFactory:', address(_factory));
    console.log('PactoUsernameNFT:', _factory.USERNAME_NFT());
    console.log('GlobalSponsorPool:', _factory.POOL());
    console.log('BootstrapMintPool:', _factory.BOOTSTRAP_POOL());
    console.log('SponsorPolicyRegistry:', _factory.POLICY());
    console.log('BootstrapClaimPolicy:', _factory.BOOTSTRAP_POLICY());
    console.log('PactoGlobalPaymaster:', _factory.PAYMASTER());
    console.log('NostrClaimLink:', nostrClaimLink);
    console.log('EntryPoint:', entryPoint);
    console.log('Allowed7702:', allowed7702);
    console.log('Protocol owner:', owner);
    console.log('Policy version:', SponsorPolicyRegistry(_factory.POLICY()).policyVersion());
  }

  /// @notice Returns the forge script broadcaster address
  /// @return deployer The broadcaster address
  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }
}
