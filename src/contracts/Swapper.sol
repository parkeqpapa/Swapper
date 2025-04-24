// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IUniswapV2Router02} from 'src/interfaces/IUniswap.sol';
import {IWETH9} from 'src/interfaces/IWETH.sol';

contract Swapper {
  error NotGovernor();
  error SwapAlreadyExecuted();
  error AmountMustBeGreaterThanZero();
  error NoTokensToWithdraw();
  error NotAuthorized();

  address public governor;

  uint256 public totalFromTokens;
  mapping(address => uint256) public userBalance;

  bool public swapExecuted;
  IUniswapV2Router02 public uniswap = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  IWETH9 public weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // fromToken
  IERC20 public dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); // toToken

  event Provided(address indexed user, uint256 amount);
  event Swapped(uint256 totalFromTokens, uint256 totalToTokens);
  event Withdrawn(address indexed user, uint256 amount);

  constructor(
    address _governor
  ) {
    governor = _governor;
    weth.approve(address(uniswap), type(uint256).max);
  }

  modifier onlyGovernor() {
    if (msg.sender != governor) revert NotGovernor();
    _;
  }

  // Users deposit `fromToken`
  function provide(
    uint256 amount
  ) external {
    if (swapExecuted) revert SwapAlreadyExecuted();
    if (amount == 0) revert AmountMustBeGreaterThanZero();

    // Update user's deposit and total deposits
    userBalance[msg.sender] += amount;
    totalFromTokens += amount;

    // Transfer `fromToken` from the user to the contract
    weth.transferFrom(msg.sender, address(this), amount);

    emit Provided(msg.sender, amount);
  }

  function provideWithEth() external payable {
    if (swapExecuted) revert SwapAlreadyExecuted();
    userBalance[msg.sender] += msg.value;
    totalFromTokens += msg.value;

    // send Msg.value to WETH
    weth.deposit{value: msg.value}();

    emit Provided(msg.sender, msg.value);
  }

  function swap(
    uint256 amount
  ) external onlyGovernor returns (uint256) {
    swapExecuted = true;

    uint256 amountDAIExpected = getRealPrice(amount);

    // Permitir un 5% de slippage
    uint256 amountOutMin = amountDAIExpected * 95 / 100;

    address[] memory path = new address[](2);
    path[0] = address(weth);
    path[1] = address(dai);

    uint256[] memory amounts =
      IUniswapV2Router02(uniswap).swapExactTokensForTokens(amount, amountOutMin, path, address(this), block.timestamp);
    return amounts[1];
  }

  function getRealPrice(
    uint256 amountWETH
  ) public view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = address(weth);
    path[1] = address(dai);

    uint256[] memory amounts = IUniswapV2Router02(uniswap).getAmountsOut(amountWETH, path);
    return amounts[1]; // Cantidad de DAI que recibirás
  }

  // Users withdraw their share of `toToken` (or `fromToken` if swap hasn't occurred)
  function withdraw() external {
    uint256 userDeposit = userBalance[msg.sender];
    if (userDeposit == 0) revert NoTokensToWithdraw();

    // Reset user's deposit
    if (swapExecuted) {
      // Withdraw `toToken`
      uint256 totalWETHDeposited = totalFromTokens;
      uint256 userShare = (userDeposit * dai.balanceOf(address(this))) / totalWETHDeposited;

      totalFromTokens -= userDeposit;
      userBalance[msg.sender] = 0;

      dai.transfer(msg.sender, userShare);
    } else {
      // Withdraw `fromToken`
      totalFromTokens -= userDeposit;
      userBalance[msg.sender] = 0;

      weth.transfer(msg.sender, userDeposit);
    }

    emit Withdrawn(msg.sender, userDeposit);
  }

  function setSwapExecuted() external onlyGovernor {
    if (msg.sender != governor) revert NotAuthorized();
    swapExecuted = false;
  }

  function getGovernance() external view returns (address) {
    return governor;
  }
}
