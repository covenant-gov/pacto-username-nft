// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BootstrapClaimPolicy} from 'contracts/BootstrapClaimPolicy.sol';
import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';
import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';

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
  address public immutable USERNAME_NFT;

  /// @inheritdoc IUsernameSystemFactory
  address public immutable POOL;

  /// @inheritdoc IUsernameSystemFactory
  address public immutable POLICY;

  /// @inheritdoc IUsernameSystemFactory
  address public immutable PAYMASTER;

  /// @inheritdoc IUsernameSystemFactory
  address public paymasterStaker;

  /// @notice Initializes and wires the username sponsorship system
  /// @param entryPoint The ERC-4337 EntryPoint v0.7
  /// @param owner The protocol owner for admin functions
  /// @param allowed7702Implementation The allowlisted EIP-7702 account implementation
  constructor(IEntryPoint entryPoint, address owner, address allowed7702Implementation) {
    if (entryPoint == IEntryPoint(address(0)) || owner == address(0)) revert Factory_ZeroAddress();

    POOL = address(new GlobalSponsorPool(address(this)));
    USERNAME_NFT = address(new PactoUsernameNFT(owner));
    POLICY = address(new SponsorPolicyRegistry(owner));

    address payable _bootstrapPool = payable(address(new BootstrapMintPool(address(this))));
    address _bootstrapPolicy = address(new BootstrapClaimPolicy(PactoUsernameNFT(USERNAME_NFT)));

    PAYMASTER = address(
      new PactoGlobalPaymaster(
        entryPoint,
        PactoUsernameNFT(USERNAME_NFT),
        GlobalSponsorPool(payable(POOL)),
        BootstrapMintPool(_bootstrapPool),
        SponsorPolicyRegistry(POLICY),
        BootstrapClaimPolicy(_bootstrapPolicy),
        allowed7702Implementation
      )
    );

    GlobalSponsorPool(payable(POOL)).wirePaymaster(PAYMASTER);
    BootstrapMintPool(_bootstrapPool).wirePaymaster(PAYMASTER);
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

    PactoGlobalPaymaster(payable(PAYMASTER)).addStake{value: msg.value}(unstakeDelaySec);
    emit PaymasterStakeAdded(_staker, msg.value, unstakeDelaySec);
  }

  /// @inheritdoc IUsernameSystemFactory
  function unlockPaymasterStake() external {
    _onlyPaymasterStaker();
    PactoGlobalPaymaster(payable(PAYMASTER)).unlockStake();
    emit PaymasterStakeUnlocked(msg.sender);
  }

  /// @inheritdoc IUsernameSystemFactory
  function withdrawPaymasterStake(address payable to) external {
    _onlyPaymasterStaker();
    if (to == address(0)) revert Factory_ZeroAddress();

    address _staker = msg.sender;
    PactoGlobalPaymaster(payable(PAYMASTER)).withdrawStake(to);
    paymasterStaker = address(0);
    emit PaymasterStakeWithdrawn(_staker, to);
  }

  /// @inheritdoc IUsernameSystemFactory
  function withdrawPaymasterDeposit(address payable to, uint256 amount) external {
    _onlyPaymasterStaker();
    if (to == address(0)) revert Factory_ZeroAddress();
    if (amount == 0) revert Factory_StakeTooSmall(0, 1);

    PactoGlobalPaymaster(payable(PAYMASTER)).withdrawTo(to, amount);
    emit PaymasterDepositWithdrawn(msg.sender, to, amount);
  }

  /// @notice Reverts unless the caller holds the FCFS paymaster stake slot
  function _onlyPaymasterStaker() internal view {
    if (msg.sender != paymasterStaker) revert Factory_NotPaymasterStaker();
  }
}
