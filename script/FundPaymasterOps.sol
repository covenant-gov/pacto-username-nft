// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {IUsernameSystemFactory} from 'interfaces/IUsernameSystemFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IStakeManager} from '@account-abstraction/interfaces/IStakeManager.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console2} from 'forge-std/console2.sol';

/// @notice Funds an already-deployed global paymaster EntryPoint deposit and FCFS stake
/// @dev Skip independently per side. A short side sends the env amount (not a deficit top-up).
///      Both skip → no broadcast. Do not unstake/re-stake just to re-log.
///      Uint amounts are logged via `vm.toString`: forge-std `log(string,uint)` is selector
///      `0x9710a9d0`; Foundry's tracer expects Hardhat `log(string,uint256)`.
contract FundPaymasterOps is DeploymentArtifacts {
  using stdJson for string;

  uint256 internal constant _DEFAULT_DEPOSIT_WEI = 0.1 ether;
  uint256 internal constant _DEFAULT_STAKE_WEI = 0.1 ether;
  uint256 internal constant _DEFAULT_UNSTAKE_DELAY_SEC = 172_800;

  function run() external {
    string memory _path = _deploymentJsonPath('full-system.json');
    string memory _json;
    try vm.readFile(_path) returns (string memory raw) {
      _json = raw;
    } catch {
      revert MissingDeploymentArtifact(_path);
    }
    address _entryPointAddr = _json.readAddress('.entryPoint');
    IUsernameSystemFactory _factory = IUsernameSystemFactory(_json.readAddress('.usernameSystemFactory'));
    PactoGlobalPaymaster _paymaster = PactoGlobalPaymaster(payable(_json.readAddress('.pactoGlobalPaymaster')));

    require(_factory.PAYMASTER() == address(_paymaster), 'fund: factory PAYMASTER mismatch');
    require(address(_paymaster.entryPoint()) == _entryPointAddr, 'fund: paymaster EP mismatch');

    uint256 _depositWei = vm.envOr('PAYMASTER_EP_DEPOSIT_WEI', _DEFAULT_DEPOSIT_WEI);
    uint256 _stakeWei = vm.envOr('PAYMASTER_STAKE_WEI', _DEFAULT_STAKE_WEI);
    uint256 _unstakeDelaySec = vm.envOr('PAYMASTER_UNSTAKE_DELAY_SEC', _DEFAULT_UNSTAKE_DELAY_SEC);
    require(_depositWei > 0, 'fund: zero deposit');
    require(_stakeWei > 0, 'fund: zero stake');
    require(_unstakeDelaySec <= type(uint32).max, 'fund: unstake delay overflow');

    _fund(_factory, _paymaster, IEntryPoint(_entryPointAddr), _depositWei, _stakeWei, uint32(_unstakeDelaySec), true);
  }

  /// @notice Returns true when the EntryPoint deposit is already at or above the target
  /// @param currentDeposit The live `balanceOf(paymaster)`
  /// @param targetDeposit The env/default deposit target
  /// @return skip True when the deposit transfer should be skipped
  function _shouldSkipDeposit(uint256 currentDeposit, uint256 targetDeposit) internal pure returns (bool skip) {
    skip = currentDeposit >= targetDeposit;
  }

  /// @notice Returns true when stake is locked at least at the requested unstake delay
  /// @param info The EntryPoint deposit info for the paymaster
  /// @param requestedDelay The env/default unstake delay
  /// @return skip True when `addPaymasterStake` should be skipped
  function _shouldSkipStake(
    IStakeManager.DepositInfo memory info,
    uint32 requestedDelay
  ) internal pure returns (bool skip) {
    skip = info.staked && info.unstakeDelaySec >= requestedDelay && info.withdrawTime == 0;
  }

  /// @notice Deposits and/or stakes, skipping sides already at target
  /// @param factory The username system factory
  /// @param paymaster The live global paymaster
  /// @param ep The EntryPoint used by the paymaster
  /// @param depositWei The deposit target (and amount sent when short)
  /// @param stakeWei The stake amount sent when not locked
  /// @param unstakeDelaySec The requested unstake delay
  /// @param withBroadcast True for forge-script broadcast; false for unit tests
  function _fund(
    IUsernameSystemFactory factory,
    PactoGlobalPaymaster paymaster,
    IEntryPoint ep,
    uint256 depositWei,
    uint256 stakeWei,
    uint32 unstakeDelaySec,
    bool withBroadcast
  ) internal {
    bool _skipDeposit = _shouldSkipDeposit(ep.balanceOf(address(paymaster)), depositWei);
    bool _skipStake = _shouldSkipStake(ep.getDepositInfo(address(paymaster)), unstakeDelaySec);

    uint256 _depositAdded;
    uint256 _stakeAdded;
    if (!_skipDeposit || !_skipStake) {
      address _expectedStaker;
      if (withBroadcast) {
        vm.startBroadcast();
        _expectedStaker = _broadcastDeployer();
      } else {
        _expectedStaker = address(this);
      }

      if (!_skipDeposit) {
        paymaster.deposit{value: depositWei}();
        _depositAdded = depositWei;
      }
      if (!_skipStake) {
        factory.addPaymasterStake{value: stakeWei}(unstakeDelaySec);
        _stakeAdded = stakeWei;
      }

      if (withBroadcast) {
        vm.stopBroadcast();
      }
      if (!_skipStake) {
        require(factory.paymasterStaker() == _expectedStaker, 'fund: paymasterStaker mismatch');
      }
    }

    require(ep.balanceOf(address(paymaster)) >= depositWei, 'fund: EP deposit too low');
    if (_skipStake) {
      IStakeManager.DepositInfo memory _info = ep.getDepositInfo(address(paymaster));
      require(
        _info.staked && _info.unstakeDelaySec >= unstakeDelaySec && _info.withdrawTime == 0, 'fund: stake not locked'
      );
    }

    if (_skipDeposit) {
      console2.log('EP deposit skipped (already >= target)');
    }
    if (_skipStake) {
      console2.log('Stake skipped (already locked at requested delay)');
    }
    console2.log('UsernameSystemFactory:', address(factory));
    console2.log('PactoGlobalPaymaster:', address(paymaster));
    console2.log('EntryPoint:', address(ep));
    console2.log(string.concat('EP deposit added (wei): ', vm.toString(_depositAdded)));
    console2.log(string.concat('EP deposit total (wei): ', vm.toString(ep.balanceOf(address(paymaster)))));
    console2.log(string.concat('Stake added (wei): ', vm.toString(_stakeAdded)));
    console2.log(string.concat('Unstake delay (sec): ', vm.toString(unstakeDelaySec)));
    console2.log('paymasterStaker:', factory.paymasterStaker());
  }

  /// @notice Returns the forge script broadcaster address
  /// @return deployer The broadcaster address
  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing (run pnpm deploy:sepolia first)
  error MissingDeploymentArtifact(string path);
}
