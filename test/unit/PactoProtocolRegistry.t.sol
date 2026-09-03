// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {ProtocolRegistryTestBase} from 'test/helpers/ProtocolRegistryTestBase.sol';

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

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_AlreadyInitialized.selector);
    _registry.initialize(_sampleAddresses());
  }

  function test_Initialize_WhenCalledByNonInstaller() external {
    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_NotInstaller.selector);
    vm.prank(_other);
    _registry.initialize(_sampleAddresses());
  }

  function test_Initialize_WhenACoreAddressIsZero() external {
    IPactoProtocolRegistry.ProtocolAddresses memory _addresses = _sampleAddresses();
    _addresses.paymaster = address(0);

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_ZeroAddress.selector);
    _registry.initialize(_addresses);
  }

  function test_SetUsernameNft_WhenCalledByOwner() external {
    _registry.initialize(_sampleAddresses());
    address _newNft = makeAddr('newNft');

    vm.expectEmit(true, true, true, true, address(_registry));
    emit IPactoProtocolRegistry.UsernameNftUpdated(_newNft);

    vm.prank(_owner);
    _registry.setUsernameNft(_newNft);

    assertEq(_registry.usernameNft(), _newNft);
  }

  function test_SetUsernameNft_WhenCalledByNonOwner() external {
    _registry.initialize(_sampleAddresses());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _other));
    vm.prank(_other);
    _registry.setUsernameNft(makeAddr('newNft'));
  }

  function test_SetUsernameNft_WhenAddressIsZero() external {
    _registry.initialize(_sampleAddresses());

    vm.expectRevert(IPactoProtocolRegistry.ProtocolRegistry_ZeroAddress.selector);
    vm.prank(_owner);
    _registry.setUsernameNft(address(0));
  }

  function test_SetPaymaster_WhenCalledByOwner() external {
    _registry.initialize(_sampleAddresses());
    address _newPaymaster = makeAddr('newPaymaster');

    vm.prank(_owner);
    _registry.setPaymaster(_newPaymaster);

    assertEq(_registry.paymaster(), _newPaymaster);
  }

  function test_SetAllowed7702Implementation_WhenCalledByOwner() external {
    _registry.initialize(_sampleAddresses());

    vm.prank(_owner);
    _registry.setAllowed7702Implementation(address(0));

    assertEq(_registry.allowed7702Implementation(), address(0));
  }

  function _sampleAddresses() internal pure returns (IPactoProtocolRegistry.ProtocolAddresses memory addresses) {
    addresses = IPactoProtocolRegistry.ProtocolAddresses({
      usernameNft: address(0xA11),
      paymaster: address(0xA12),
      pool: address(0xA13),
      bootstrapPool: address(0xA14),
      policy: address(0xA15),
      bootstrapPolicy: address(0xA16),
      entryPoint: address(0xA17),
      allowed7702Implementation: address(0xA18)
    });
  }
}
