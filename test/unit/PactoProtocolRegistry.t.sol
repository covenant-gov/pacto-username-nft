// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {ProtocolRegistryTestBase} from 'test/helpers/ProtocolRegistryTestBase.sol';
import {MockProtocolPaymaster} from 'test/mocks/MockProtocolPaymaster.sol';

contract UnitPactoProtocolRegistry is ProtocolRegistryTestBase {
  address internal _owner = makeAddr('owner');
  address internal _installer;
  address internal _other = makeAddr('other');

  PactoProtocolRegistry internal _registry;

  function setUp() external {
    _installer = address(this);
    _registry = new PactoProtocolRegistry(_owner, _installer);
  }

  function test_Constructor_SetsOwnerAndInstaller() external view {
    assertEq(_registry.owner(), _owner);
    assertEq(_registry.INSTALLER(), _installer);
    assertFalse(_registry.initialized());
  }

  function test_Constructor_WhenOwnerIsZero() external {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new PactoProtocolRegistry(address(0), _installer);
  }

  function test_Constructor_WhenInstallerIsZero() external {
    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_ZeroAddress.selector);
    new PactoProtocolRegistry(_owner, address(0));
  }

  function test_Initialize_WhenCalledByInstaller() external {
    IPactoProtocolRegistry.ProtocolAddresses memory _addresses = _sampleAddresses();

    vm.expectEmit(true, true, true, true, address(_registry));
    emit IPactoProtocolRegistry.ProtocolInitialized(_addresses);

    _registry.initialize(_addresses);

    assertTrue(_registry.initialized());
    assertEq(_registry.usernameNft(), _addresses.usernameNft);
    assertEq(_registry.paymaster(), _addresses.paymaster);
    assertEq(_registry.pool(), _addresses.pool);
    assertEq(_registry.bootstrapPool(), _addresses.bootstrapPool);
    assertEq(_registry.policy(), _addresses.policy);
    assertEq(_registry.bootstrapPolicy(), _addresses.bootstrapPolicy);
    assertEq(_registry.entryPoint(), _addresses.entryPoint);
    assertEq(_registry.allowed7702Implementation(), _addresses.allowed7702Implementation);
  }

  function test_Initialize_WhenCalledTwice() external {
    _registry.initialize(_sampleAddresses());
    IPactoProtocolRegistry.ProtocolAddresses memory _addresses = _sampleAddresses();

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_AlreadyInitialized.selector);
    _registry.initialize(_addresses);
  }

  function test_Initialize_WhenCalledByNonInstaller() external {
    IPactoProtocolRegistry.ProtocolAddresses memory _addresses = _sampleAddresses();

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_NotInstaller.selector);
    vm.prank(_other);
    _registry.initialize(_addresses);
  }

  function test_Initialize_WhenACoreAddressIsZero() external {
    IPactoProtocolRegistry.ProtocolAddresses memory _addresses = _sampleAddresses();
    _addresses.paymaster = address(0);

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_ZeroAddress.selector);
    _registry.initialize(_addresses);
  }

  function test_Initialize_WhenBundleIsIncoherent() external {
    IPactoProtocolRegistry.ProtocolAddresses memory _addresses = _sampleAddresses();
    _addresses.usernameNft = makeAddr('otherNft');

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_IncoherentBundle.selector);
    _registry.initialize(_addresses);
  }

  function test_Migrate_WhenCalledByOwner() external {
    _registry.initialize(_sampleAddresses());
    IPactoProtocolRegistry.ProtocolAddresses memory _next = _sampleAddresses();

    vm.expectEmit(true, true, true, true, address(_registry));
    emit IPactoProtocolRegistry.ProtocolMigrated(_next);

    vm.prank(_owner);
    _registry.migrate(_next);

    assertEq(_registry.paymaster(), _next.paymaster);
    assertEq(_registry.usernameNft(), _next.usernameNft);
  }

  function test_Migrate_WhenCalledByNonOwner() external {
    _registry.initialize(_sampleAddresses());
    IPactoProtocolRegistry.ProtocolAddresses memory _next = _sampleAddresses();

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _other));
    vm.prank(_other);
    _registry.migrate(_next);
  }

  function test_Migrate_WhenNotInitialized() external {
    IPactoProtocolRegistry.ProtocolAddresses memory _next = _sampleAddresses();

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_NotInitialized.selector);
    vm.prank(_owner);
    _registry.migrate(_next);
  }

  function test_Migrate_WhenBundleIsIncoherent() external {
    _registry.initialize(_sampleAddresses());
    IPactoProtocolRegistry.ProtocolAddresses memory _next = _sampleAddresses();
    _next.pool = makeAddr('otherPool');

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_IncoherentBundle.selector);
    vm.prank(_owner);
    _registry.migrate(_next);
  }

  function test_TransferOwnership_TwoStep() external {
    address _newOwner = makeAddr('newOwner');

    vm.prank(_owner);
    _registry.transferOwnership(_newOwner);

    assertEq(_registry.owner(), _owner);
    assertEq(_registry.pendingOwner(), _newOwner);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _other));
    vm.prank(_other);
    _registry.acceptOwnership();

    vm.prank(_newOwner);
    _registry.acceptOwnership();

    assertEq(_registry.owner(), _newOwner);
    assertEq(_registry.pendingOwner(), address(0));
  }

  function _sampleAddresses() internal returns (IPactoProtocolRegistry.ProtocolAddresses memory addresses) {
    addresses.usernameNft = makeAddr('nft');
    addresses.pool = makeAddr('pool');
    addresses.bootstrapPool = makeAddr('bootstrapPool');
    addresses.policy = makeAddr('policy');
    addresses.bootstrapPolicy = makeAddr('bootstrapPolicy');
    addresses.entryPoint = makeAddr('entryPoint');
    addresses.allowed7702Implementation = makeAddr('allowed7702');
    MockProtocolPaymaster _paymaster = _deployMockPaymaster(
      _registry,
      addresses.usernameNft,
      addresses.pool,
      addresses.bootstrapPool,
      addresses.policy,
      addresses.bootstrapPolicy,
      addresses.entryPoint,
      addresses.allowed7702Implementation
    );
    addresses.paymaster = address(_paymaster);
  }
}
