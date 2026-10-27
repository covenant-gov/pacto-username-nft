// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {IUsernameSystemFactory} from 'interfaces/IUsernameSystemFactory.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/// @notice Deposits ETH into an already-deployed global pool and bootstrap mint pool
contract FundPoolOps is DeploymentArtifacts {
  using stdJson for string;

  uint256 internal constant _DEFAULT_DEPOSIT_WEI = 0.1 ether;

  function run() external {
    string memory _path = _deploymentJsonPath('full-system.json');
    string memory _json;
    try vm.readFile(_path) returns (string memory raw) {
      _json = raw;
    } catch {
      revert MissingDeploymentArtifact(_path);
    }

    IUsernameSystemFactory _factory = IUsernameSystemFactory(_json.readAddress('.usernameSystemFactory'));
    GlobalSponsorPool _global = GlobalSponsorPool(payable(_json.readAddress('.globalSponsorPool')));
    BootstrapMintPool _bootstrap = BootstrapMintPool(payable(_json.readAddress('.bootstrapMintPool')));

    require(_factory.POOL() == address(_global), 'fund: factory POOL mismatch');
    require(_factory.BOOTSTRAP_POOL() == address(_bootstrap), 'fund: factory BOOTSTRAP_POOL mismatch');

    uint256 _globalWei = vm.envOr('GLOBAL_POOL_DEPOSIT_WEI', _DEFAULT_DEPOSIT_WEI);
    uint256 _bootstrapWei = vm.envOr('BOOTSTRAP_POOL_DEPOSIT_WEI', _DEFAULT_DEPOSIT_WEI);
    if (_globalWei == 0 && _bootstrapWei == 0) revert ZeroPoolDeposits();

    uint256 _globalBefore = _global.spendablePoolWei();
    uint256 _bootstrapBefore = _bootstrap.spendablePoolWei();

    console.log('UsernameSystemFactory:', address(_factory));
    console.log('GlobalSponsorPool:', address(_global));
    console.log('BootstrapMintPool:', address(_bootstrap));
    console.log('Global deposit (wei):', _globalWei);
    console.log('Bootstrap deposit (wei):', _bootstrapWei);
    console.log('Global spendable before (wei):', _globalBefore);
    console.log('Bootstrap spendable before (wei):', _bootstrapBefore);

    vm.startBroadcast();
    if (_globalWei > 0) _global.deposit{value: _globalWei}();
    if (_bootstrapWei > 0) _bootstrap.deposit{value: _bootstrapWei}();
    vm.stopBroadcast();

    uint256 _globalAfter = _global.spendablePoolWei();
    uint256 _bootstrapAfter = _bootstrap.spendablePoolWei();
    if (_globalWei > 0) {
      require(_globalAfter >= _globalBefore + _globalWei, 'fund: global pool too low');
    }
    if (_bootstrapWei > 0) {
      require(_bootstrapAfter >= _bootstrapBefore + _bootstrapWei, 'fund: bootstrap pool too low');
    }

    console.log('Global spendable after (wei):', _globalAfter);
    console.log('Bootstrap spendable after (wei):', _bootstrapAfter);
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing (run pnpm deploy:sepolia first)
  error MissingDeploymentArtifact(string path);

  /// @notice Thrown when both pool deposit amounts are zero
  error ZeroPoolDeposits();
}
