// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Chain singleton that deploys the username sponsorship system
interface IUsernameSystemFactory {
  /// @notice Minimum paymaster stake in wei
  function MIN_PAYMASTER_STAKE_WEI() external view returns (uint256 minStakeWei);

  /// @notice Minimum unstake delay in seconds
  function MIN_UNSTAKE_DELAY_SEC() external view returns (uint32 minUnstakeDelaySec);

  /// @notice Deployed username NFT contract
  function USERNAME_NFT() external view returns (address usernameNft);

  /// @notice Deployed global sponsor pool
  function POOL() external view returns (address pool);

  /// @notice Deployed bootstrap mint pool
  function BOOTSTRAP_POOL() external view returns (address bootstrapPool);

  /// @notice Deployed sponsor policy registry
  function POLICY() external view returns (address policy);

  /// @notice Deployed bootstrap claim policy
  function BOOTSTRAP_POLICY() external view returns (address bootstrapPolicy);

  /// @notice Deployed global paymaster
  function PAYMASTER() external view returns (address paymaster);

  /// @notice FCFS paymaster stake holder
  function paymasterStaker() external view returns (address staker);

  /// @notice Emitted when paymaster stake is added
  event PaymasterStakeAdded(address indexed staker, uint256 amount, uint32 unstakeDelaySec);

  /// @notice Emitted when paymaster stake is unlocked
  event PaymasterStakeUnlocked(address indexed staker);

  /// @notice Emitted when paymaster stake is withdrawn
  event PaymasterStakeWithdrawn(address indexed staker, address indexed to);

  /// @notice Emitted when paymaster deposit is withdrawn
  event PaymasterDepositWithdrawn(address indexed staker, address indexed to, uint256 amount);

  /// @notice Thrown when stake is below the minimum
  error Factory_StakeTooSmall(uint256 amount, uint256 minAmount);

  /// @notice Thrown when unstake delay is too short
  error Factory_UnstakeDelayTooShort(uint32 unstakeDelaySec, uint32 minUnstakeDelaySec);

  /// @notice Thrown when the stake slot is occupied by another staker
  error Factory_StakeSlotOccupied(address staker);

  /// @notice Thrown when the caller is not the paymaster staker
  error Factory_NotPaymasterStaker();

  /// @notice Thrown when a required address is zero
  error Factory_ZeroAddress();

  /// @notice Adds paymaster stake via the FCFS staker slot
  /// @param unstakeDelaySec The unstake delay in seconds
  function addPaymasterStake(uint32 unstakeDelaySec) external payable;

  /// @notice Unlocks paymaster stake for withdrawal
  function unlockPaymasterStake() external;

  /// @notice Withdraws paymaster stake to an address
  /// @param to The recipient address
  function withdrawPaymasterStake(address payable to) external;

  /// @notice Withdraws paymaster EntryPoint deposit
  /// @param to The recipient address
  /// @param amount The wei amount to withdraw
  function withdrawPaymasterDeposit(address payable to, uint256 amount) external;
}
