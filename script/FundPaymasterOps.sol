// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {IUsernameSystemFactory} from 'interfaces/IUsernameSystemFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Funds an already-deployed global paymaster EntryPoint deposit and FCFS stake
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

    IEntryPoint _ep = IEntryPoint(_entryPointAddr);
    uint256 _depositBefore = _ep.balanceOf(address(_paymaster));

    vm.startBroadcast();
    address _broadcaster = _broadcastDeployer();
    _paymaster.deposit{value: _depositWei}();
    _factory.addPaymasterStake{value: _stakeWei}(uint32(_unstakeDelaySec));
    vm.stopBroadcast();

    require(_ep.balanceOf(address(_paymaster)) >= _depositBefore + _depositWei, 'fund: EP deposit too low');
    require(_factory.paymasterStaker() == _broadcaster, 'fund: paymasterStaker mismatch');

    console.log('UsernameSystemFactory:', address(_factory));
    console.log('PactoGlobalPaymaster:', address(_paymaster));
    console.log('EntryPoint:', _entryPointAddr);
    console.log('EP deposit added (wei):', _depositWei);
    console.log('EP deposit total (wei):', _ep.balanceOf(address(_paymaster)));
    console.log('Stake added (wei):', _stakeWei);
    console.log('Unstake delay (sec):', _unstakeDelaySec);
    console.log('paymasterStaker:', _factory.paymasterStaker());
  }

  /// @notice Returns the forge script broadcaster address
  /// @return deployer The broadcaster address
  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing (run pnpm deploy:sepolia first)
  error MissingDeploymentArtifact(string path);
}
