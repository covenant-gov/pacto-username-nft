// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IPactoGlobalPaymaster} from 'interfaces/IPactoGlobalPaymaster.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

/// @notice EntryPoint getter shared by BasePaymaster and test mocks
interface IPaymasterEntryPoint {
  /// @notice Returns the EntryPoint this paymaster is bound to
  function entryPoint() external view returns (IEntryPoint entryPoint);
}

/// @title PactoProtocolRegistry
/// @notice Owner-gated protocol address book with a one-time installer initialize
contract PactoProtocolRegistry is IPactoProtocolRegistry, Ownable2Step {
  /// @inheritdoc IPactoProtocolRegistry
  address public immutable INSTALLER;

  /// @inheritdoc IPactoProtocolRegistry
  bool public initialized;

  /// @inheritdoc IPactoProtocolRegistry
  address public usernameNft;

  /// @inheritdoc IPactoProtocolRegistry
  address public paymaster;

  /// @inheritdoc IPactoProtocolRegistry
  address public pool;

  /// @inheritdoc IPactoProtocolRegistry
  address public bootstrapPool;

  /// @inheritdoc IPactoProtocolRegistry
  address public policy;

  /// @inheritdoc IPactoProtocolRegistry
  address public bootstrapPolicy;

  /// @inheritdoc IPactoProtocolRegistry
  address public entryPoint;

  /// @inheritdoc IPactoProtocolRegistry
  address public allowed7702Implementation;

  /// @inheritdoc IPactoProtocolRegistry
  bool public eip7702Enabled;

  /// @notice Sets the protocol owner and one-time installer
  /// @param owner The protocol owner for later address updates
  /// @param installer_ The factory allowed to call initialize once
  constructor(address owner, address installer_) Ownable(owner) {
    if (installer_ == address(0)) revert ProtocolRegistry_ZeroAddress();
    INSTALLER = installer_;
  }

  /// @inheritdoc IPactoProtocolRegistry
  function initialize(ProtocolAddresses calldata addresses) external {
    if (msg.sender != INSTALLER) revert ProtocolRegistry_NotInstaller();
    if (initialized) revert ProtocolRegistry_AlreadyInitialized();
    _requireCoreAddresses(addresses);
    _requireEip7702Config(addresses);
    _requireBundleCoherent(addresses);

    initialized = true;
    _writeAddresses(addresses);
    emit ProtocolInitialized(addresses);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function migrate(ProtocolAddresses calldata addresses) external onlyOwner {
    if (!initialized) revert ProtocolRegistry_NotInitialized();
    _requireCoreAddresses(addresses);
    _requireEip7702Config(addresses);
    _requireBundleCoherent(addresses);

    _writeAddresses(addresses);
    emit ProtocolMigrated(addresses);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function disableEip7702() external onlyOwner {
    if (!initialized) revert ProtocolRegistry_NotInitialized();
    if (!eip7702Enabled) revert ProtocolRegistry_Eip7702AlreadyDisabled();

    eip7702Enabled = false;
    emit Eip7702Disabled();
  }

  /// @notice Reverts when a required protocol address is zero
  /// @param addresses The candidate protocol addresses
  function _requireCoreAddresses(ProtocolAddresses calldata addresses) internal pure {
    if (
      addresses.usernameNft == address(0) || addresses.paymaster == address(0) || addresses.pool == address(0)
        || addresses.bootstrapPool == address(0) || addresses.policy == address(0)
        || addresses.bootstrapPolicy == address(0) || addresses.entryPoint == address(0)
    ) revert ProtocolRegistry_ZeroAddress();
  }

  /// @notice Reverts when EIP-7702 is enabled without an implementation
  /// @param addresses The candidate protocol addresses
  function _requireEip7702Config(ProtocolAddresses calldata addresses) internal pure {
    if (addresses.eip7702Enabled && addresses.allowed7702Implementation == address(0)) {
      revert ProtocolRegistry_Invalid7702Config();
    }
  }

  /// @notice Reverts when the paymaster immutables do not match the address book
  /// @param addresses The candidate protocol addresses
  function _requireBundleCoherent(ProtocolAddresses calldata addresses) internal view {
    IPactoGlobalPaymaster _paymaster = IPactoGlobalPaymaster(addresses.paymaster);
    if (
      address(_paymaster.REGISTRY()) != address(this) || address(_paymaster.USERNAME_NFT()) != addresses.usernameNft
        || address(_paymaster.POLICY()) != addresses.policy
        || address(_paymaster.BOOTSTRAP_POLICY()) != addresses.bootstrapPolicy
        || address(_paymaster.POOL()) != addresses.pool
        || address(_paymaster.BOOTSTRAP_POOL()) != addresses.bootstrapPool
        || address(IPaymasterEntryPoint(addresses.paymaster).entryPoint()) != addresses.entryPoint
        || _paymaster.ALLOWED_7702_IMPLEMENTATION() != addresses.allowed7702Implementation
    ) revert ProtocolRegistry_IncoherentBundle();
  }

  /// @notice Writes every address-book slot from a generation
  /// @param addresses The protocol addresses to store
  function _writeAddresses(ProtocolAddresses calldata addresses) internal {
    usernameNft = addresses.usernameNft;
    paymaster = addresses.paymaster;
    pool = addresses.pool;
    bootstrapPool = addresses.bootstrapPool;
    policy = addresses.policy;
    bootstrapPolicy = addresses.bootstrapPolicy;
    entryPoint = addresses.entryPoint;
    allowed7702Implementation = addresses.allowed7702Implementation;
    eip7702Enabled = addresses.eip7702Enabled;
  }
}
