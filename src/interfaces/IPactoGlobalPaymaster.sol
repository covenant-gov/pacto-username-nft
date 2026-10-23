// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IBootstrapMintPool} from 'interfaces/IBootstrapMintPool.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @notice ERC-4337 paymaster for username NFT holders with modular action policy
interface IPactoGlobalPaymaster {
  /// @notice Paymaster payload version
  function PAYMASTER_DATA_VERSION() external view returns (uint8 version);

  /// @notice Protocol registry that records this paymaster generation
  /// @return registry The protocol registry
  function REGISTRY() external view returns (IPactoProtocolRegistry registry);

  /// @notice Username NFT used for membership checks
  /// @return usernameNft The username NFT
  function USERNAME_NFT() external view returns (IPactoUsernameNFT usernameNft);

  /// @notice Member-path sponsor policy
  /// @return policy The member-path sponsor policy
  function POLICY() external view returns (ISponsorPolicy policy);

  /// @notice Bootstrap-claim sponsor policy
  /// @return bootstrapPolicy The bootstrap-claim sponsor policy
  function BOOTSTRAP_POLICY() external view returns (ISponsorPolicy bootstrapPolicy);

  /// @notice Member-path sponsor pool
  /// @return pool The member-path sponsor pool
  function POOL() external view returns (IGlobalSponsorPool pool);

  /// @notice Bootstrap-claim sponsor pool
  /// @return bootstrapPool The bootstrap-claim sponsor pool
  function BOOTSTRAP_POOL() external view returns (IBootstrapMintPool bootstrapPool);

  /// @notice Allowlisted EIP-7702 account implementation
  /// @return implementation The allowlisted EIP-7702 account implementation
  function ALLOWED_7702_IMPLEMENTATION() external view returns (address implementation);

  /// @notice Parsed global paymaster payload
  /// @param npubHash Bound npub hash for the sponsored member
  /// @param member Username NFT holder address expected to match the UserOp sender
  /// @param policy Optional custom policy address (member path; zero uses default)
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

  /// @notice Thrown when paymaster payload member is the zero address
  error GlobalPaymaster_ZeroMember();

  /// @notice Thrown when BootstrapMintPool cannot cover maxCost headroom
  /// @param spendable Current spendable pool balance
  /// @param required Required balance including headroom
  error GlobalPaymaster_InsufficientBootstrapPool(uint256 spendable, uint256 required);

  /// @notice Thrown when GlobalSponsorPool cannot cover maxCost headroom
  /// @param spendable Current spendable pool balance
  /// @param required Required balance including headroom
  error GlobalPaymaster_InsufficientMemberPool(uint256 spendable, uint256 required);

  /// @notice Thrown when bootstrap execute value is non-zero
  error GlobalPaymaster_NonZeroValue();

  /// @notice Thrown when inner calldata is not a valid claim with matching npubHash
  error GlobalPaymaster_InvalidClaimPayload();

  /// @notice Thrown when BootstrapClaimPolicy rejects the call
  error GlobalPaymaster_BootstrapNotSponsorable();

  /// @notice Thrown when the membership npub does not match paymaster data
  error GlobalPaymaster_IneligibleMember();

  /// @notice Thrown when SponsorPolicyRegistry rejects the call
  error GlobalPaymaster_MemberNotSponsorable();
}
