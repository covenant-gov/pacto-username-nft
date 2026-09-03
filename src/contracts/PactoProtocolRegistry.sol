// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

/// @title PactoProtocolRegistry
/// @notice Owner-gated protocol address book with a one-time installer initialize
contract PactoProtocolRegistry is IPactoProtocolRegistry, Ownable {
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

    initialized = true;
    usernameNft = addresses.usernameNft;
    paymaster = addresses.paymaster;
    pool = addresses.pool;
    bootstrapPool = addresses.bootstrapPool;
    policy = addresses.policy;
    bootstrapPolicy = addresses.bootstrapPolicy;
    entryPoint = addresses.entryPoint;
    allowed7702Implementation = addresses.allowed7702Implementation;

    emit ProtocolInitialized(addresses);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function setUsernameNft(address usernameNftAddress) external onlyOwner {
    if (usernameNftAddress == address(0)) revert ProtocolRegistry_ZeroAddress();
    usernameNft = usernameNftAddress;
    emit UsernameNftUpdated(usernameNftAddress);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function setPaymaster(address paymasterAddress) external onlyOwner {
    if (paymasterAddress == address(0)) revert ProtocolRegistry_ZeroAddress();
    paymaster = paymasterAddress;
    emit PaymasterUpdated(paymasterAddress);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function setPool(address poolAddress) external onlyOwner {
    if (poolAddress == address(0)) revert ProtocolRegistry_ZeroAddress();
    pool = poolAddress;
    emit PoolUpdated(poolAddress);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function setBootstrapPool(address bootstrapPoolAddress) external onlyOwner {
    if (bootstrapPoolAddress == address(0)) revert ProtocolRegistry_ZeroAddress();
    bootstrapPool = bootstrapPoolAddress;
    emit BootstrapPoolUpdated(bootstrapPoolAddress);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function setPolicy(address policyAddress) external onlyOwner {
    if (policyAddress == address(0)) revert ProtocolRegistry_ZeroAddress();
    policy = policyAddress;
    emit PolicyUpdated(policyAddress);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function setBootstrapPolicy(address bootstrapPolicyAddress) external onlyOwner {
    if (bootstrapPolicyAddress == address(0)) revert ProtocolRegistry_ZeroAddress();
    bootstrapPolicy = bootstrapPolicyAddress;
    emit BootstrapPolicyUpdated(bootstrapPolicyAddress);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function setEntryPoint(address entryPointAddress) external onlyOwner {
    if (entryPointAddress == address(0)) revert ProtocolRegistry_ZeroAddress();
    entryPoint = entryPointAddress;
    emit EntryPointUpdated(entryPointAddress);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function setAllowed7702Implementation(address allowed7702) external onlyOwner {
    allowed7702Implementation = allowed7702;
    emit Allowed7702ImplementationUpdated(allowed7702);
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
}
