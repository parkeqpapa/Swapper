// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.23;

// import {Swapper} from 'contracts/Swapper.sol';
// import {Test, console} from 'forge-std/Test.sol';

// // import {console} from 'forge-std/console.sol';
// import {IERC20} from 'forge-std/interfaces/IERC20.sol';
// import {WETH9} from 'interfaces/IWETH.sol';

// contract SwapperTest is Test {
//   uint256 internal constant _FORK_BLOCK = 18_920_905;

//   address internal _governor = makeAddr('governor');
//   address internal _user = makeAddr('user');
//   address internal _alice = makeAddr('alice');
//   address internal _bob = makeAddr('bob');
//   Swapper internal _swapper;
//   IERC20 internal _dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
//   WETH9 internal _weth = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

//   function setUp() public {
//     vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);

//     _swapper = new Swapper(_governor);

//     vm.prank(address(_swapper));
//     _weth.approve(address(_governor), type(uint256).max);

//     deal(address(_weth), _user, 10 ether);
//     vm.deal(_user, 10 ether);
//     vm.deal(_alice, 3 ether);
//     vm.deal(_bob, 1 ether);

//     vm.prank(_user);
//     _weth.approve(address(_swapper), type(uint256).max);
//   }

//   function test_provideWithWETH() public {
//     uint256 balBefore = _weth.balanceOf(_user);

//     vm.prank(_user);
//     _swapper.provide(1e18);

//     uint256 balAfter = _weth.balanceOf(_user);
//     assertNotEq(balBefore, balAfter);
//     assert(_weth.balanceOf(address(_swapper)) != 0);
//   }

//   function test_provideWithETH() public {
//     uint256 balBefore = address(_user).balance;
//     vm.prank(_user);
//     _swapper.provideWithEth{value: 100}();

//     uint256 balAfter = address(_user).balance;

//     assertNotEq(balBefore, balAfter);
//     assert(_weth.balanceOf(address(_swapper)) != 0);
//   }

//   function test_provideWithEthAndWithdraw() public {
//     vm.startPrank(_user);
//     _swapper.provideWithEth{value: 100}();
//     _swapper.withdraw();
//     vm.stopPrank();

//     assert(_dai.balanceOf(_user) == 0);
//   }

//   function test_provideAndWithdraw() public {
//     uint256 balBefore = address(_user).balance;
//     vm.startPrank(_user);
//     _swapper.provide(1e18);
//     _swapper.withdraw();
//     vm.stopPrank();

//     uint256 balAfter = _weth.balanceOf(_user);
//     assert(_dai.balanceOf(_user) == 0);
//     assertEq(balAfter, balBefore);
//   }

//   function testRevertZeroAmount() public {
//     vm.startPrank(_user);
//     vm.expectRevert();
//     _swapper.provide(0);
//     vm.stopPrank();
//   }

//   function test_ProvideSwapWithdraw() public {
//     vm.prank(_user);
//     _swapper.provide(1e18);

//     vm.startPrank(_governor);
//     uint256 amountDAIReceived = _swapper.swap(_weth.balanceOf(address(_swapper)));
//     vm.stopPrank();

//     vm.prank(_user);
//     _swapper.withdraw();

//     assert(_dai.balanceOf(_user) != 0);
//     uint256 expectedDAI = amountDAIReceived;
//     assertEq(_dai.balanceOf(_user), expectedDAI);

//     console.log(_dai.balanceOf(_user));
//     console.log(_swapper.totalFromTokens());
//   }

//   function test_MultipleUsers() public {
//     vm.startPrank(_user);
//     _swapper.provide(1e18);
//     vm.stopPrank();

//     vm.startPrank(_alice);
//     _swapper.provideWithEth{value: 2 ether}();
//     vm.stopPrank();

//     vm.startPrank(_bob);
//     _swapper.provideWithEth{value: 100}();
//     vm.stopPrank();

//     vm.startPrank(_governor);
//     _swapper.swap(_weth.balanceOf(address(_swapper)));
//     vm.stopPrank();

//     vm.startPrank(_user);
//     _swapper.withdraw();
//     vm.stopPrank();

//     vm.startPrank(_alice);
//     _swapper.withdraw();
//     vm.stopPrank();

//     vm.startPrank(_bob);
//     _swapper.withdraw();
//     vm.stopPrank();

//     assert(_dai.balanceOf(_user) != 0);
//     assert(_dai.balanceOf(_alice) != 0);
//     assert(_dai.balanceOf(_bob) != 0);
//   }

//   function testRevert_CannotWithdrawMultipleUsers() public {
//     vm.startPrank(_user);
//     _swapper.provide(1e18);
//     vm.stopPrank();

//     vm.startPrank(_alice);
//     _swapper.provideWithEth{value: 2 ether}();
//     vm.stopPrank();

//     vm.startPrank(_governor);
//     _swapper.swap(_weth.balanceOf(address(_swapper)));
//     vm.stopPrank();

//     vm.startPrank(_bob);
//     vm.expectRevert();
//     _swapper.withdraw();
//     vm.stopPrank();
//   }

//   function test_getPrice() public {
//     vm.startPrank(_user);
//     _swapper.getRealPrice(1e18);
//     console.log('Price?', _swapper.getRealPrice(1e18));
//     vm.stopPrank();
//   }

//   function testRevert_SwapExecuted() public {
//     vm.startPrank(_user);
//     _swapper.provide(1e18);
//     vm.stopPrank();

//     vm.startPrank(_governor);
//     _swapper.swap(_weth.balanceOf(address(_swapper)));
//     vm.stopPrank();

//     vm.startPrank(_user);
//     vm.expectRevert();
//     _swapper.provide(1e18);
//     vm.stopPrank();
//   }

//   function test_SwapExecuted() public {
//     vm.startPrank(_user);
//     _swapper.provide(1e18);
//     vm.stopPrank();

//     vm.startPrank(_governor);
//     _swapper.swap(_weth.balanceOf(address(_swapper)));
//     _swapper.setSwapExecuted();
//     vm.stopPrank();

//     vm.startPrank(_user);
//     _swapper.provide(1e18);
//     vm.stopPrank();
//   }

//   function test_OnlyGovernorCanSetSwapExecuted() public {
//     vm.startPrank(_user);
//     vm.expectRevert();
//     _swapper.setSwapExecuted();
//     vm.stopPrank();
//   }
// }
