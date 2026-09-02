// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Pluggable policy for what global sponsorship may pay for
interface ISponsorPolicy {
  /// @notice Returns whether a UserOp call may be sponsored
  /// @param target The call target address
  /// @param callData The call data payload
  /// @param member The sponsoring member address
  /// @param tokenId The username NFT token id for the member
  /// @return sponsorable True when the call is allowed by policy
  function isSponsorable(
    address target,
    bytes calldata callData,
    address member,
    uint256 tokenId
  ) external view returns (bool sponsorable);
}
