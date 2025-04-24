// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Greeter, IGreeter} from 'contracts/Greeter.sol';
import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {IWETH9} from 'src/interfaces/IWETH.sol';

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 18_920_905;

  string internal _initialGreeting = 'hola';
  address internal _user = makeAddr('user');
  address internal _owner = makeAddr('owner');
  address internal _daiWhale = 0x42f8CA49E88A8fd8F0bfA2C739e648468b8f9dec;
  IERC20 internal _dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IWETH9 public weth;

  IGreeter internal _greeter;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    vm.prank(_owner);
    weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  }
}
