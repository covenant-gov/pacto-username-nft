// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ShareVault} from 'contracts/abstracts/ShareVault.sol';
import {ETHTransfer} from 'contracts/utils/ETHTransfer.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {ISponsorCommon} from 'interfaces/ISponsorCommon.sol';

/// @title GlobalSponsorPool
/// @notice Protocol-wide ETH vault with pro-rata shares for global sponsorship
contract GlobalSponsorPool is IGlobalSponsorPool, ShareVault {
  /// @notice Protocol registry used to resolve the live paymaster
  IPactoProtocolRegistry public immutable REGISTRY;

  /// @notice Initializes the global sponsor pool
  /// @param registry The protocol registry
  constructor(IPactoProtocolRegistry registry) {
    if (registry == IPactoProtocolRegistry(address(0))) revert ISponsorCommon.Sponsor_ZeroAddress();
    REGISTRY = registry;
  }

  /// @notice Credits plain ETH sends to the depositor
  receive() external payable {
    _deposit(msg.sender);
  }

  /// @notice Credits ETH sent with calldata to the depositor
  fallback() external payable {
    _deposit(msg.sender);
  }

  /// @inheritdoc IGlobalSponsorPool
  function paymaster() public view returns (address paymasterAddress) {
    paymasterAddress = REGISTRY.paymaster();
  }

  /// @inheritdoc IGlobalSponsorPool
  function withdrawable(address sponsor) external view returns (uint256 amount) {
    uint256 _shares = sponsorShares[sponsor];
    if (_shares == 0 || totalShares == 0) return 0;
    amount = (_shares * spendablePoolWei) / totalShares;
  }

  /// @inheritdoc IGlobalSponsorPool
  function deposit() external payable {
    _deposit(msg.sender);
  }

  /// @inheritdoc IGlobalSponsorPool
  function depositFor(address sponsor) external payable {
    if (sponsor == address(0)) revert ISponsorCommon.Sponsor_ZeroAddress();
    _deposit(sponsor);
  }

  /// @inheritdoc IGlobalSponsorPool
  function withdraw() external {
    uint256 _shares = sponsorShares[msg.sender];
    if (_shares == 0) revert ISponsorCommon.Sponsor_NoShares();

    uint256 _pool = spendablePoolWei;
    uint256 _amount = (_shares * _pool) / totalShares;

    sponsorShares[msg.sender] = 0;
    totalShares -= _shares;
    spendablePoolWei = _pool - _amount;

    ETHTransfer.sendEth(msg.sender, _amount);

    emit Withdrawn(msg.sender, _amount, _shares);
  }

  /// @inheritdoc IGlobalSponsorPool
  function spendGas(uint256 amount) external {
    address _paymaster = paymaster();
    if (msg.sender != _paymaster) revert ISponsorCommon.Sponsor_NotPaymaster();
    _debitSpendable(amount);
    ETHTransfer.sendEth(_paymaster, amount);

    emit GasSpent(msg.sender, amount);
  }

  /// @notice Credits pro-rata sponsor shares for a depositor
  /// @param sponsor The account receiving shares
  function _deposit(address sponsor) internal {
    uint256 _shares = _mintDepositShares(sponsor, msg.value);
    emit Deposited(sponsor, msg.value, _shares);
  }
}
