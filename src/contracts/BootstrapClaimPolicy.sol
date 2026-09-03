// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @title BootstrapClaimPolicy
/// @notice Fixed sponsorship policy for one-time username NFT bootstrap claims
contract BootstrapClaimPolicy is ISponsorPolicy {
  /// @notice Thrown when the registry address is zero
  error BootstrapClaimPolicy_ZeroAddress();

  /// @notice Protocol registry used to resolve the live username NFT
  IPactoProtocolRegistry public immutable REGISTRY;

  /// @notice `claim(string,bytes32,bytes32,uint256,uint256,bytes32,bytes,bytes)` selector
  bytes4 internal constant CLAIM_SELECTOR = 0x9824550d;

  /// @notice Initializes the bootstrap claim policy
  /// @param registry The protocol registry
  constructor(IPactoProtocolRegistry registry) {
    if (registry == IPactoProtocolRegistry(address(0))) revert BootstrapClaimPolicy_ZeroAddress();
    REGISTRY = registry;
  }

  /// @inheritdoc ISponsorPolicy
  function isSponsorable(
    address target,
    bytes calldata callData,
    address member,
    uint256 tokenId
  ) external view returns (bool sponsorable) {
    IPactoUsernameNFT _usernameNft = IPactoUsernameNFT(REGISTRY.usernameNft());
    if (target != address(_usernameNft)) return false;
    if (tokenId != 0) return false;
    if (callData.length < 4) return false;
    if (bytes4(callData[:4]) != CLAIM_SELECTOR) return false;

    (string memory _name, bytes32 _npubHash,,,,, bytes memory _nostrSignature,) =
      abi.decode(callData[4:], (string, bytes32, bytes32, uint256, uint256, bytes32, bytes, bytes));

    if (!_usernameNft.canBootstrapClaim(member, _npubHash)) return false;
    if (!_usernameNft.nameAvailable(_name)) return false;
    if (_nostrSignature.length != 64) return false;

    return true;
  }
}
