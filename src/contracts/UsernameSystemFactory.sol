// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BootstrapClaimPolicy} from 'contracts/BootstrapClaimPolicy.sol';
import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IUsernameSystemFactory} from 'interfaces/IUsernameSystemFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

/// @title UsernameSystemFactory
/// @notice Chain singleton that deploys username NFT and global sponsorship infrastructure
contract UsernameSystemFactory is IUsernameSystemFactory {
  /// @inheritdoc IUsernameSystemFactory
  uint256 public constant MIN_PAYMASTER_STAKE_WEI = 0.1 ether;

  /// @inheritdoc IUsernameSystemFactory
  uint32 public constant MIN_UNSTAKE_DELAY_SEC = 1 days;

  /// @inheritdoc IUsernameSystemFactory
  address public immutable REGISTRY;

  /// @inheritdoc IUsernameSystemFactory
  address public paymasterStaker;

  /// @notice Initializes and wires the username sponsorship system
  /// @param entryPoint The ERC-4337 EntryPoint v0.7
  /// @param owner The protocol owner for admin functions
  /// @param allowed7702Implementation The allowlisted EIP-7702 account implementation
  constructor(IEntryPoint entryPoint, address owner, address allowed7702Implementation) {
    if (entryPoint == IEntryPoint(address(0)) || owner == address(0)) revert Factory_ZeroAddress();

    PactoProtocolRegistry _registry = new PactoProtocolRegistry(owner, address(this));
    REGISTRY = address(_registry);

    address _pool = address(new GlobalSponsorPool(_registry));
    address _nft = address(new PactoUsernameNFT(owner));
    address _policy = address(new SponsorPolicyRegistry(owner));
    address _bootstrapPool = address(new BootstrapMintPool(_registry));
    address _bootstrapPolicy = address(new BootstrapClaimPolicy(_registry));
    address _paymaster = address(new PactoGlobalPaymaster(entryPoint, _registry));

    _registry.initialize(
      IPactoProtocolRegistry.ProtocolAddresses({
        usernameNft: _nft,
        paymaster: _paymaster,
        pool: _pool,
        bootstrapPool: _bootstrapPool,
        policy: _policy,
        bootstrapPolicy: _bootstrapPolicy,
        entryPoint: address(entryPoint),
        allowed7702Implementation: allowed7702Implementation
      })
    );
  }

  /// @inheritdoc IUsernameSystemFactory
  function USERNAME_NFT() public view returns (address usernameNft) {
    usernameNft = IPactoProtocolRegistry(REGISTRY).usernameNft();
  }

  /// @inheritdoc IUsernameSystemFactory
  function POOL() public view returns (address pool) {
    pool = IPactoProtocolRegistry(REGISTRY).pool();
  }

  /// @inheritdoc IUsernameSystemFactory
  function BOOTSTRAP_POOL() public view returns (address bootstrapPool) {
    bootstrapPool = IPactoProtocolRegistry(REGISTRY).bootstrapPool();
  }

  /// @inheritdoc IUsernameSystemFactory
  function POLICY() public view returns (address policy) {
    policy = IPactoProtocolRegistry(REGISTRY).policy();
  }

  /// @inheritdoc IUsernameSystemFactory
  function BOOTSTRAP_POLICY() public view returns (address bootstrapPolicy) {
    bootstrapPolicy = IPactoProtocolRegistry(REGISTRY).bootstrapPolicy();
  }

  /// @inheritdoc IUsernameSystemFactory
  function PAYMASTER() public view returns (address paymaster) {
    paymaster = IPactoProtocolRegistry(REGISTRY).paymaster();
  }

  /// @inheritdoc IUsernameSystemFactory
  function addPaymasterStake(uint32 unstakeDelaySec) external payable {
    if (msg.value == 0) revert Factory_StakeTooSmall(0, 1);

    address _staker = paymasterStaker;
    if (_staker == address(0)) {
      if (msg.value < MIN_PAYMASTER_STAKE_WEI) {
        revert Factory_StakeTooSmall(msg.value, MIN_PAYMASTER_STAKE_WEI);
      }
      if (unstakeDelaySec < MIN_UNSTAKE_DELAY_SEC) {
        revert Factory_UnstakeDelayTooShort(unstakeDelaySec, MIN_UNSTAKE_DELAY_SEC);
      }
      paymasterStaker = msg.sender;
      _staker = msg.sender;
    } else if (msg.sender != _staker) {
      revert Factory_StakeSlotOccupied(_staker);
    }

    PactoGlobalPaymaster(payable(PAYMASTER())).addStake{value: msg.value}(unstakeDelaySec);
    emit PaymasterStakeAdded(_staker, msg.value, unstakeDelaySec);
  }

  /// @inheritdoc IUsernameSystemFactory
  function unlockPaymasterStake() external {
    _onlyPaymasterStaker();
    PactoGlobalPaymaster(payable(PAYMASTER())).unlockStake();
    emit PaymasterStakeUnlocked(msg.sender);
  }

  /// @inheritdoc IUsernameSystemFactory
  function withdrawPaymasterStake(address payable to) external {
    _onlyPaymasterStaker();
    if (to == address(0)) revert Factory_ZeroAddress();

    address _staker = msg.sender;
    PactoGlobalPaymaster(payable(PAYMASTER())).withdrawStake(to);
    paymasterStaker = address(0);
    emit PaymasterStakeWithdrawn(_staker, to);
  }

  /// @inheritdoc IUsernameSystemFactory
  function withdrawPaymasterDeposit(address payable to, uint256 amount) external {
    _onlyPaymasterStaker();
    if (to == address(0)) revert Factory_ZeroAddress();
    if (amount == 0) revert Factory_StakeTooSmall(0, 1);

    PactoGlobalPaymaster(payable(PAYMASTER())).withdrawTo(to, amount);
    emit PaymasterDepositWithdrawn(msg.sender, to, amount);
  }

  /// @notice Reverts unless the caller holds the FCFS paymaster stake slot
  function _onlyPaymasterStaker() internal view {
    if (msg.sender != paymasterStaker) revert Factory_NotPaymasterStaker();
  }
}
