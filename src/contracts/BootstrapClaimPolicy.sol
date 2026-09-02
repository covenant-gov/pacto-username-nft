// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @title BootstrapClaimPolicy
/// @notice Fixed sponsorship policy for one-time username NFT bootstrap claims
contract BootstrapClaimPolicy is ISponsorPolicy {
  /// @notice Username NFT targeted by bootstrap claims
  IPactoUsernameNFT public immutable USERNAME_NFT;

  /// @notice `claim(string,bytes32,bytes32,uint256,uint256,bytes32,bytes,bytes)` selector
  bytes4 internal constant CLAIM_SELECTOR = 0x9824550d;

  /// @notice Initializes the bootstrap claim policy
  /// @param usernameNft The username NFT contract
  constructor(IPactoUsernameNFT usernameNft) {
    USERNAME_NFT = usernameNft;
  }

  /// @inheritdoc ISponsorPolicy
  function isSponsorable(
    address target,
    bytes calldata callData,
    address member,
    uint256 tokenId
  ) external view returns (bool sponsorable) {
    if (target != address(USERNAME_NFT)) return false;
    if (tokenId != 0) return false;
    if (callData.length < 4) return false;
    if (bytes4(callData[:4]) != CLAIM_SELECTOR) return false;

    (string memory _name, bytes32 _npubHash,,,,, bytes memory _nostrSignature,) =
      abi.decode(callData[4:], (string, bytes32, bytes32, uint256, uint256, bytes32, bytes, bytes));

    if (!USERNAME_NFT.canBootstrapClaim(member, _npubHash)) return false;
    if (!USERNAME_NFT.nameAvailable(_name)) return false;
    if (USERNAME_NFT.isReservedName(keccak256(bytes(_name)))) return false;
    if (_nostrSignature.length != 64) return false;

    return true;
  }
}
