// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

/// @notice ERC-4337 paymaster for username NFT holders with modular action policy
interface IPactoGlobalPaymaster {
  /// @notice Paymaster payload version
  function PAYMASTER_DATA_VERSION() external view returns (uint8 version);

  /// @notice Protocol registry used to resolve live NFT, pools, and policies
  function REGISTRY() external view returns (IPactoProtocolRegistry registry);

  /// @notice Allowlisted EIP-7702 account implementation from the protocol registry
  function ALLOWED_7702_IMPLEMENTATION() external view returns (address implementation);

  /// @notice Parsed global paymaster payload
  struct PaymasterData {
    bytes32 npubHash;
    address member;
    address policy;
  }

  /// @notice Thrown when paymaster payload version is invalid
  error GlobalPaymaster_InvalidVersion(uint8 version);

  /// @notice Thrown when member binding is invalid
  error GlobalPaymaster_InvalidMemberBinding(address sender, address member);

  /// @notice Thrown when EIP-7702 implementation is not allowlisted
  error GlobalPaymaster_Invalid7702Implementation(address implementation);

  /// @notice Thrown when UserOp calldata is not a supported execute call
  error GlobalPaymaster_InvalidCallData();

  /// @notice Thrown when a custom policy address is supplied on the member path
  error GlobalPaymaster_CustomPolicyNotAllowed();

  /// @notice Thrown when a required address is zero
  error GlobalPaymaster_ZeroAddress();
}
