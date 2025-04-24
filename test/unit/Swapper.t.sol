// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Swapper} from 'contracts/Swapper.sol';
import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {IWETH9} from 'interfaces/IWETH.sol';
import {IUniswapV2Router02} from 'src/interfaces/IUniswap.sol';

contract SwapperTest is Test {
  uint256 internal constant _FORK_BLOCK = 18_920_905;

  address internal _governor = makeAddr('governor');
  address internal _user = makeAddr('user');
  address internal _alice = makeAddr('alice');
  address internal _bob = makeAddr('bob');
  Swapper internal _swapper;
  IERC20 internal _dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  IWETH9 internal _weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  IUniswapV2Router02 public uniswap = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);

    _swapper = new Swapper(_governor);

    vm.prank(address(_swapper));
    _weth.approve(address(_governor), type(uint256).max);

    deal(address(_weth), _user, 10 ether);
    vm.deal(_user, 10 ether);
    vm.deal(_alice, 3 ether);
    vm.deal(_bob, 1 ether);

    vm.prank(_user);
    _weth.approve(address(_swapper), type(uint256).max);
  }

  function test_ConstructorWhenCalledWithAddressIsPassed() external {
    // it deploys
    vm.prank(_governor);
    _swapper = new Swapper(_governor);
    // it sets the approval to uniswap
    assertEq(_weth.allowance(address(_swapper), address(uniswap)), type(uint256).max);
    // it sets the governor
    assertEq(_swapper.governor(), _governor);
  }

  function test_ConstructorWhenPassingAnInvalidAddress() external {
    // it reverts
  }

  modifier whenCalledByAUser() {
    vm.startPrank(_user);
    _;
    vm.stopPrank();
  }

  function test_ProvideWhenPassingAValidAmount() external whenCalledByAUser {
    // it updates the user's balance
    // it updates the total balance
    // it transfers the fromToken to the contract
    // it emits Provided
    uint256 balBefore = _weth.balanceOf(_user);
    _swapper.provide(1e18);

    uint256 balAfter = _weth.balanceOf(_user);
    assertNotEq(balBefore, balAfter);
    assert(_weth.balanceOf(address(_swapper)) != 0);
  }

  function test_ProvideWhenPassingAnInvalidAmount() external whenCalledByAUser {
    // it reverts
    vm.expectRevert();
    _swapper.provide(0);
  }

  function test_ProvideWhenCalledAfterTheSwapHasBeenExecuted() external {
    // it reverts
    vm.prank(_user);
    _swapper.provide(1e18);

    vm.startPrank(_governor);
    _swapper.swap(1e18);
    vm.stopPrank();

    vm.startPrank(_user);
    vm.expectRevert();
    _swapper.provide(1e18);
    vm.stopPrank();
  }

  function test_ProvideWithEthWhenPassingAValidAmount() external whenCalledByAUser {
    // it updates the user's balance
    // it updates the total balance
    // it deposits the ETH to WETH
    // it emits Provided
    uint256 balBefore = address(_user).balance;
    _swapper.provideWithEth{value: 100}();

    uint256 balAfter = address(_user).balance;

    assertNotEq(balBefore, balAfter);
    assert(_weth.balanceOf(address(_swapper)) != 0);
  }

  function test_ProvideWithEthWhenPassingAnInvalidAmount() external whenCalledByAUser {
    // it reverts vm.expectRevert();
    _swapper.provideWithEth{value: 0}();
  }

  function test_ProvideWithEthWhenCalledAfterTheSwapHasBeenExecuted() external {
    // it reverts
    vm.prank(_user);
    _swapper.provideWithEth{value: 1 ether}();

    vm.startPrank(_governor);
    _swapper.swap(1e18);
    vm.stopPrank();

    vm.startPrank(_user);
    vm.expectRevert();
    _swapper.provideWithEth{value: 1 ether}();
    vm.stopPrank();
  }

  modifier whenCalledByTheGovernor() {
    vm.startPrank(_governor);
    _;
    vm.stopPrank();
  }

  function test_SwapWhenPassingAValidAmount() external {
    // it sets swapExecuted to true
    // it gets the real price
    // it sets the amountOutMin
    // it sets the path
    // it swaps the tokens
    // it returns the amount of DAI received
    vm.prank(_user);
    _swapper.provide(1e18);

    vm.startPrank(_governor);
    _swapper.swap(1e18);
    vm.stopPrank();
  }

  function test_SwapWhenCalledByANon_governor() external {
    // it reverts
    vm.prank(_user);
    _swapper.provide(1e18);

    vm.startPrank(_user);
    vm.expectRevert();
    _swapper.swap(1e18);
    vm.stopPrank();
  }

  function test_WithdrawWhenSwapHasBeenExecuted() external {
    // it updates the user's balance
    // it updates the total balance
    // it transfers the toToken to the user
    // it emits Withdrawn
    vm.prank(_user);
    _swapper.provide(1e18);

    vm.startPrank(_governor);
    uint256 amountDAIReceived = _swapper.swap(_weth.balanceOf(address(_swapper)));
    vm.stopPrank();
    vm.prank(_user);
    _swapper.withdraw();

    assert(_dai.balanceOf(_user) != 0);
    uint256 expectedDAI = amountDAIReceived;
    assertEq(_dai.balanceOf(_user), expectedDAI);
  }

  function test_WithdrawWhenSwapHasNotBeenExecuted() external whenCalledByAUser {
    // it updates the user's balance
    // it updates the total balance
    // it transfers the fromToken to the user
    // it emits Withdrawn
    uint256 balBefore = address(_user).balance;
    _swapper.provide(1e18);
    _swapper.withdraw();

    uint256 balAfter = _weth.balanceOf(_user);
    assert(_dai.balanceOf(_user) == 0);
    assertEq(balAfter, balBefore);
  }

  function test_WithdrawWhenCalledByANon_user() external {
    // it reverts
    vm.prank(_user);
    _swapper.provide(1e18);

    vm.startPrank(_governor);
    _swapper.swap(_weth.balanceOf(address(_swapper)));
    vm.stopPrank();

    vm.expectRevert();
    _swapper.withdraw();
  }

  function test_SetSwapExecutedWhenCalledByTheGovernor() external {
    // it sets swapExecuted to false
    // it emits SetSwapExecuted
    vm.startPrank(_user);
    _swapper.provide(1e18);
    vm.stopPrank();

    vm.startPrank(_governor);
    _swapper.swap(_weth.balanceOf(address(_swapper)));
    _swapper.setSwapExecuted();
    vm.stopPrank();

    vm.startPrank(_user);
    _swapper.provide(1e18);
    vm.stopPrank();
  }

  function test_SetSwapExecutedWhenCalledByANon_governor() external {
    // it reverts
    vm.prank(_user);
    vm.expectRevert();
    _swapper.setSwapExecuted();
  }
}
