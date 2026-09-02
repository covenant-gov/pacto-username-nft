// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ETHTransfer} from 'contracts/utils/ETHTransfer.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {ISponsorCommon} from 'interfaces/ISponsorCommon.sol';

/// @title GlobalSponsorPool
/// @notice Protocol-wide ETH vault with pro-rata shares for global sponsorship
contract GlobalSponsorPool is IGlobalSponsorPool {
  /// @inheritdoc IGlobalSponsorPool
  address public paymaster;

  /// @notice Factory allowed to wire the paymaster once
  address public immutable factory;

  /// @inheritdoc IGlobalSponsorPool
  uint256 public totalShares;

  /// @inheritdoc IGlobalSponsorPool
  mapping(address sponsor => uint256 shares) public sponsorShares;

  /// @notice Storage-backed pool wei available for sponsorship
  uint256 internal _spendablePoolWei;

  /// @notice Initializes the global sponsor pool
  /// @param _factory The username system factory address
  constructor(address _factory) {
    if (_factory == address(0)) revert ISponsorCommon.Sponsor_ZeroAddress();
    factory = _factory;
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
  function spendablePoolWei() external view returns (uint256 amount) {
    amount = _spendablePoolWei;
  }

  /// @inheritdoc IGlobalSponsorPool
  function withdrawable(address sponsor) external view returns (uint256 amount) {
    uint256 _shares = sponsorShares[sponsor];
    if (_shares == 0 || totalShares == 0) return 0;
    amount = (_shares * _spendablePoolWei) / totalShares;
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

    uint256 _pool = _spendablePoolWei;
    uint256 _amount = (_shares * _pool) / totalShares;

    sponsorShares[msg.sender] = 0;
    totalShares -= _shares;
    _spendablePoolWei = _pool - _amount;

    ETHTransfer.sendEth(msg.sender, _amount);

    emit Withdrawn(msg.sender, _amount, _shares);
  }

  /// @inheritdoc IGlobalSponsorPool
  function spendGas(uint256 amount) external {
    if (msg.sender != paymaster) revert ISponsorCommon.Sponsor_NotPaymaster();
    if (amount > _spendablePoolWei) revert ISponsorCommon.Sponsor_InsufficientBalance();

    _spendablePoolWei -= amount;
    ETHTransfer.sendEth(paymaster, amount);

    emit GasSpent(msg.sender, amount);
  }

  /// @inheritdoc IGlobalSponsorPool
  function wirePaymaster(address paymasterAddress) external {
    if (msg.sender != factory) revert ISponsorCommon.Sponsor_NotFactory();
    if (paymasterAddress == address(0)) revert ISponsorCommon.Sponsor_ZeroAddress();
    if (paymaster != address(0)) revert ISponsorCommon.Sponsor_AlreadyInitialized();

    paymaster = paymasterAddress;
    emit PaymasterWired(paymasterAddress);
  }

  /// @notice Credits pro-rata sponsor shares for a depositor
  /// @param sponsor The account receiving shares
  function _deposit(address sponsor) internal {
    if (msg.value == 0) revert ISponsorCommon.Sponsor_ZeroAmount();

    uint256 _shares;
    uint256 _balanceBefore = _spendablePoolWei;

    if (totalShares != 0 && _balanceBefore != 0) {
      _shares = (msg.value * totalShares) / _balanceBefore;
    } else {
      _shares = msg.value;
    }

    sponsorShares[sponsor] += _shares;
    totalShares += _shares;
    _spendablePoolWei = _balanceBefore + msg.value;

    emit Deposited(sponsor, msg.value, _shares);
  }
}
