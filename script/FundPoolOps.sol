// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {IUsernameSystemFactory} from 'interfaces/IUsernameSystemFactory.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console2} from 'forge-std/console2.sol';

/// @notice Deposits ETH into an already-deployed global pool and bootstrap mint pool
/// @dev Skip independently per pool when `spendablePoolWei >=` the env amount (or env is 0).
///      A short pool sends the env amount (not a deficit top-up). Both skip → no broadcast.
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

    _fund(_factory, _global, _bootstrap, _globalWei, _bootstrapWei, true);
  }

  /// @notice Returns true when this pool should not receive a deposit
  /// @param spendable The live `spendablePoolWei`
  /// @param target The env/default deposit amount; 0 means leave this pool alone
  /// @return skip True when the deposit transfer should be skipped
  function _shouldSkipPoolDeposit(uint256 spendable, uint256 target) internal pure returns (bool skip) {
    skip = target == 0 || spendable >= target;
  }

  /// @notice Deposits into each pool that is below its env target
  /// @param factory The username system factory (logged only)
  /// @param global The live global sponsor pool
  /// @param bootstrap The live bootstrap mint pool
  /// @param globalWei The global pool target (and amount sent when short)
  /// @param bootstrapWei The bootstrap pool target (and amount sent when short)
  /// @param withBroadcast True for forge-script broadcast; false for unit tests
  function _fund(
    IUsernameSystemFactory factory,
    GlobalSponsorPool global,
    BootstrapMintPool bootstrap,
    uint256 globalWei,
    uint256 bootstrapWei,
    bool withBroadcast
  ) internal {
    uint256 _globalBefore = global.spendablePoolWei();
    uint256 _bootstrapBefore = bootstrap.spendablePoolWei();
    bool _skipGlobal = _shouldSkipPoolDeposit(_globalBefore, globalWei);
    bool _skipBootstrap = _shouldSkipPoolDeposit(_bootstrapBefore, bootstrapWei);

    uint256 _globalAdded;
    uint256 _bootstrapAdded;
    if (!_skipGlobal || !_skipBootstrap) {
      if (withBroadcast) vm.startBroadcast();
      if (!_skipGlobal) {
        global.deposit{value: globalWei}();
        _globalAdded = globalWei;
      }
      if (!_skipBootstrap) {
        bootstrap.deposit{value: bootstrapWei}();
        _bootstrapAdded = bootstrapWei;
      }
      if (withBroadcast) vm.stopBroadcast();
    }

    uint256 _globalAfter = global.spendablePoolWei();
    uint256 _bootstrapAfter = bootstrap.spendablePoolWei();
    if (globalWei > 0) {
      require(_globalAfter >= globalWei, 'fund: global pool too low');
    }
    if (bootstrapWei > 0) {
      require(_bootstrapAfter >= bootstrapWei, 'fund: bootstrap pool too low');
    }

    if (_skipGlobal && globalWei > 0) {
      console2.log('Global pool skipped (already >= target)');
    }
    if (_skipBootstrap && bootstrapWei > 0) {
      console2.log('Bootstrap pool skipped (already >= target)');
    }
    console2.log('UsernameSystemFactory:', address(factory));
    console2.log('GlobalSponsorPool:', address(global));
    console2.log('BootstrapMintPool:', address(bootstrap));
    console2.log(string.concat('Global deposit added (wei): ', vm.toString(_globalAdded)));
    console2.log(string.concat('Bootstrap deposit added (wei): ', vm.toString(_bootstrapAdded)));
    console2.log(string.concat('Global spendable before (wei): ', vm.toString(_globalBefore)));
    console2.log(string.concat('Bootstrap spendable before (wei): ', vm.toString(_bootstrapBefore)));
    console2.log(string.concat('Global spendable after (wei): ', vm.toString(_globalAfter)));
    console2.log(string.concat('Bootstrap spendable after (wei): ', vm.toString(_bootstrapAfter)));
  }

  /// @notice Thrown when deployments/<chainId>/full-system.json is missing (run pnpm deploy:sepolia first)
  error MissingDeploymentArtifact(string path);

  /// @notice Thrown when both pool deposit amounts are zero
  error ZeroPoolDeposits();
}
