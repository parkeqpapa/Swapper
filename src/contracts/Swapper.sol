// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IUniswapV2Router02} from 'src/interfaces/IUniswap.sol';
import {IWETH9} from 'src/interfaces/IWETH.sol';

/**
 * @title Swapper
 * @notice A collective token swapping contract that pools user deposits and executes batch swaps
 * @dev This contract allows users to deposit WETH/ETH, pools the funds, and executes a single
 *      swap from WETH to DAI when triggered by the governor. Users receive proportional shares
 *      of the swapped tokens based on their deposits
 * @author parkeqpapa
 */
contract Swapper {
  /// @notice The governor address who can execute swaps and manage the contract
  address public governor;

  /// @notice Total amount of WETH deposited by all users
  uint256 public totalFromTokens;

  /// @notice Mapping of user addresses to their deposited WETH amounts
  mapping(address user => uint256 amount) public userBalance;

  /// @notice Flag indicating whether the swap has been executed
  bool public swapExecuted;

  /// @notice Uniswap V2 router for executing token swaps
  IUniswapV2Router02 public uniswap = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  /// @notice WETH contract (source token for swaps)
  IWETH9 public weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  /// @notice DAI contract (target token for swaps)
  IERC20 public dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  /// @notice Emitted when a user provides WETH to the pool
  /// @param user The address of the user who provided tokens
  /// @param amount The amount of WETH provided
  event Provided(address indexed user, uint256 amount);

  /// @notice Emitted when the swap is executed
  /// @param totalFromTokens The total amount of WETH swapped
  /// @param totalToTokens The total amount of DAI received
  event Swapped(uint256 totalFromTokens, uint256 totalToTokens);

  /// @notice Emitted when a user withdraws their share
  /// @param user The address of the user who withdrew
  /// @param amount The amount withdrawn (original deposit amount for tracking)
  event Withdrawn(address indexed user, uint256 amount);

  /// @notice Thrown when caller is not the governor
  error NotGovernor();

  /// @notice Thrown when trying to deposit after swap has been executed
  error SwapAlreadyExecuted();

  /// @notice Thrown when trying to deposit zero amount
  error AmountMustBeGreaterThanZero();

  /// @notice Thrown when user has no tokens to withdraw
  error NoTokensToWithdraw();

  /// @notice Thrown when caller is not authorized to perform the operation
  error NotAuthorized();

  /**
   * @notice Restricts function access to the governor only
   * @dev Reverts with NotGovernor error if caller is not the governor
   */
  modifier onlyGovernor() {
    if (msg.sender != governor) revert NotGovernor();
    _;
  }

  /**
   * @notice Constructs the Swapper contract
   * @dev Sets the governor and approves Uniswap router to spend WETH
   * @param _governor The address that will govern the contract and execute swaps
   */
  constructor(
    address _governor
  ) {
    governor = _governor;
    weth.approve(address(uniswap), type(uint256).max);
  }

  /**
   * @notice Allows users to deposit WETH tokens to the pool
   * @dev Users must approve this contract to transfer their WETH before calling
   * @param amount The amount of WETH to deposit
   */
  function provide(
    uint256 amount
  ) external {
    if (swapExecuted) revert SwapAlreadyExecuted();
    if (amount == 0) revert AmountMustBeGreaterThanZero();

    userBalance[msg.sender] += amount;
    totalFromTokens += amount;

    weth.transferFrom(msg.sender, address(this), amount);

    emit Provided(msg.sender, amount);
  }

  /**
   * @notice Allows users to deposit ETH which gets automatically wrapped to WETH
   * @dev ETH sent with this function is automatically converted to WETH
   */
  function provideWithEth() external payable {
    if (swapExecuted) revert SwapAlreadyExecuted();
    userBalance[msg.sender] += msg.value;
    totalFromTokens += msg.value;

    weth.deposit{value: msg.value}();

    emit Provided(msg.sender, msg.value);
  }

  /**
   * @notice Executes the batch swap from WETH to DAI for all pooled funds
   * @dev Only the governor can execute swaps. Includes 5% slippage protection
   * @param amount The amount of WETH to swap
   * @return The amount of DAI received from the swap
   */
  function swap(
    uint256 amount
  ) external onlyGovernor returns (uint256) {
    swapExecuted = true;

    uint256 amountDAIExpected = getRealPrice(amount);

    uint256 amountOutMin = amountDAIExpected * 95 / 100;

    address[] memory path = new address[](2);
    path[0] = address(weth);
    path[1] = address(dai);

    uint256[] memory amounts =
      IUniswapV2Router02(uniswap).swapExactTokensForTokens(amount, amountOutMin, path, address(this), block.timestamp);

    emit Swapped(amount, amounts[1]);
    return amounts[1];
  }

  /**
   * @notice Allows users to withdraw their proportional share of tokens
   * @dev If swap was executed, users receive DAI proportional to their WETH deposit
   *      If swap wasn't executed, users receive their original WETH deposit back
   */
  function withdraw() external {
    uint256 userDeposit = userBalance[msg.sender];
    if (userDeposit == 0) revert NoTokensToWithdraw();

    if (swapExecuted) {
      uint256 totalWETHDeposited = totalFromTokens;
      uint256 userShare = (userDeposit * dai.balanceOf(address(this))) / totalWETHDeposited;

      totalFromTokens -= userDeposit;
      userBalance[msg.sender] = 0;

      dai.transfer(msg.sender, userShare);
    } else {
      totalFromTokens -= userDeposit;
      userBalance[msg.sender] = 0;

      weth.transfer(msg.sender, userDeposit);
    }

    emit Withdrawn(msg.sender, userDeposit);
  }

  /**
   * @notice Resets the swap execution flag to allow new deposits
   * @dev Only the governor can reset the swap status for a new round
   */
  function setSwapExecuted() external onlyGovernor {
    if (msg.sender != governor) revert NotAuthorized();
    swapExecuted = false;
  }

  /**
   * @notice Gets the expected DAI amount for a given WETH amount
   * @dev Queries Uniswap for current exchange rates without executing a swap
   * @param amountWETH The amount of WETH to check the price for
   * @return The expected amount of DAI that would be received
   */
  function getRealPrice(
    uint256 amountWETH
  ) public view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = address(weth);
    path[1] = address(dai);

    uint256[] memory amounts = IUniswapV2Router02(uniswap).getAmountsOut(amountWETH, path);
    return amounts[1];
  }

  /**
   * @notice Returns the current governor address
   * @dev View function to check who the current governor is
   * @return The address of the current governor
   */
  function getGovernance() public view returns (address) {
    return governor;
  }
}
