// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @title IUniswapV2Router02
 * @notice Interface for the Uniswap V2 Router with additional functionalities for adding/removing liquidity and token swaps.
 */
interface IUniswapV2Router02 {
  /**
   * @notice Returns the address of the Uniswap V2 factory.
   * @return The address of the factory.
   */
  function factory() external view returns (address);

  /**
   * @notice Returns the address of the Wrapped Ether (WETH) token.
   * @return The address of the WETH token.
   */
  function WETH() external view returns (address);

  /**
   * @notice Adds liquidity to an ERC-20 token pair.
   * @param tokenA The address of the first token.
   * @param tokenB The address of the second token.
   * @param amountADesired The desired amount of tokenA.
   * @param amountBDesired The desired amount of tokenB.
   * @param amountAMin The minimum amount of tokenA.
   * @param amountBMin The minimum amount of tokenB.
   * @param to The address to receive the liquidity tokens.
   * @param deadline The transaction deadline.
   * @return amountA The actual amount of tokenA added.
   * @return amountB The actual amount of tokenB added.
   * @return liquidity The amount of liquidity tokens minted.
   */
  function addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

  /**
   * @notice Adds liquidity to an ERC-20/ETH pair.
   * @param token The address of the ERC-20 token.
   * @param amountTokenDesired The desired amount of the ERC-20 token.
   * @param amountTokenMin The minimum amount of the ERC-20 token.
   * @param amountETHMin The minimum amount of ETH.
   * @param to The address to receive the liquidity tokens.
   * @param deadline The transaction deadline.
   * @return amountToken The actual amount of the ERC-20 token added.
   * @return amountETH The actual amount of ETH added.
   * @return liquidity The amount of liquidity tokens minted.
   */
  function addLiquidityETH(
    address token,
    uint256 amountTokenDesired,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  )
    external
    payable
    returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

  /**
   * @notice Removes liquidity from an ERC-20 token pair.
   * @param tokenA The address of the first token.
   * @param tokenB The address of the second token.
   * @param liquidity The amount of liquidity tokens to burn.
   * @param amountAMin The minimum amount of tokenA.
   * @param amountBMin The minimum amount of tokenB.
   * @param to The address to receive the underlying assets.
   * @param deadline The transaction deadline.
   * @return amountA The amount of tokenA received.
   * @return amountB The amount of tokenB received.
   */
  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountA, uint256 amountB);

  /**
   * @notice Removes liquidity from an ERC-20/ETH pair.
   * @param token The address of the ERC-20 token.
   * @param liquidity The amount of liquidity tokens to burn.
   * @param amountTokenMin The minimum amount of the ERC-20 token.
   * @param amountETHMin The minimum amount of ETH.
   * @param to The address to receive the underlying assets.
   * @param deadline The transaction deadline.
   * @return amountToken The amount of the ERC-20 token received.
   * @return amountETH The amount of ETH received.
   */
  function removeLiquidityETH(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountToken, uint256 amountETH);

  /**
   * @notice Removes liquidity from an ERC-20 token pair with permit.
   * @param tokenA The address of the first token.
   * @param tokenB The address of the second token.
   * @param liquidity The amount of liquidity tokens to burn.
   * @param amountAMin The minimum amount of tokenA.
   * @param amountBMin The minimum amount of tokenB.
   * @param to The address to receive the underlying assets.
   * @param deadline The transaction deadline.
   * @param approveMax Whether to approve the maximum amount.
   * @param v The v component of the permit signature.
   * @param r The r component of the permit signature.
   * @param s The s component of the permit signature.
   * @return amountA The amount of tokenA received.
   * @return amountB The amount of tokenB received.
   */
  function removeLiquidityWithPermit(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 amountA, uint256 amountB);

  /**
   * @notice Removes liquidity from an ERC-20/ETH pair with permit.
   * @param token The address of the ERC-20 token.
   * @param liquidity The amount of liquidity tokens to burn.
   * @param amountTokenMin The minimum amount of the ERC-20 token.
   * @param amountETHMin The minimum amount of ETH.
   * @param to The address to receive the underlying assets.
   * @param deadline The transaction deadline.
   * @param approveMax Whether to approve the maximum amount.
   * @param v The v component of the permit signature.
   * @param r The r component of the permit signature.
   * @param s The s component of the permit signature.
   * @return amountToken The amount of the ERC-20 token received.
   * @return amountETH The amount of ETH received.
   */
  function removeLiquidityETHWithPermit(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 amountToken, uint256 amountETH);

  /**
   * @notice Swaps an exact amount of input tokens for as many output tokens as possible.
   * @param amountIn The amount of input tokens to swap.
   * @param amountOutMin The minimum amount of output tokens.
   * @param path The swap path.
   * @param to The address to receive the output tokens.
   * @param deadline The transaction deadline.
   * @return amounts The amounts of each token involved in the swap.
   */
  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts);

  /**
   * @notice Swaps tokens for an exact amount of output tokens.
   * @param amountOut The desired amount of output tokens.
   * @param amountInMax The maximum amount of input tokens.
   * @param path The swap path.
   * @param to The address to receive the output tokens.
   * @param deadline The transaction deadline.
   * @return amounts The amounts of each token involved in the swap.
   */
  function swapTokensForExactTokens(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts);

  /**
   * @notice Swaps ETH for as many output tokens as possible.
   * @param amountOutMin The minimum amount of output tokens.
   * @param path The swap path.
   * @param to The address to receive the output tokens.
   * @param deadline The transaction deadline.
   * @return amounts The amounts of each token involved in the swap.
   */
  function swapExactETHForTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable returns (uint256[] memory amounts);

  /**
   * @notice Swaps tokens for an exact amount of ETH.
   * @param amountOut The desired amount of ETH.
   * @param amountInMax The maximum amount of input tokens.
   * @param path The swap path.
   * @param to The address to receive the ETH.
   * @param deadline The transaction deadline.
   * @return amounts The amounts of each token involved in the swap.
   */
  function swapTokensForExactETH(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts);

  /**
   * @notice Swaps an exact amount of tokens for as much ETH as possible.
   * @param amountIn The amount of input tokens to swap.
   * @param amountOutMin The minimum amount of ETH.
   * @param path The swap path.
   * @param to The address to receive the ETH.
   * @param deadline The transaction deadline.
   * @return amounts The amounts of each token involved in the swap.
   */
  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts);

  /**
   * @notice Swaps ETH for an exact amount of tokens.
   * @param amountOut The desired amount of output tokens.
   * @param path The swap path.
   * @param to The address to receive the output tokens.
   * @param deadline The transaction deadline.
   * @return amounts The amounts of each token involved in the swap.
   */
  function swapETHForExactTokens(
    uint256 amountOut,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable returns (uint256[] memory amounts);

  /**
   * @notice Returns the equivalent amount of tokenB for a given amount of tokenA.
   * @param amountA The amount of tokenA.
   * @param reserveA The reserve of tokenA.
   * @param reserveB The reserve of tokenB.
   * @return amountB The equivalent amount of tokenB.
   */
  function quote(
    uint256 amountA,
    uint256 reserveA,
    uint256 reserveB
  ) external pure returns (uint256 amountB);

  /**
   * @notice Returns the amount of output tokens for a given input amount.
   * @param amountIn The input amount.
   * @param reserveIn The reserve of the input token.
   * @param reserveOut The reserve of the output token.
   * @return amountOut The output amount.
   */
  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
  ) external pure returns (uint256 amountOut);

  /**
   * @notice Returns the amount of input tokens for a given output amount.
   * @param amountOut The output amount.
   * @param reserveIn The reserve of the input token.
   * @param reserveOut The reserve of the output token.
   * @return amountIn The input amount.
   */
  function getAmountIn(
    uint256 amountOut,
    uint256 reserveIn,
    uint256 reserveOut
  ) external pure returns (uint256 amountIn);

  /**
   * @notice Returns the amounts of tokens involved in a swap given an input amount.
   * @param amountIn The input amount.
   * @param path The swap path.
   * @return amounts The amounts of each token involved in the swap.
   */
  function getAmountsOut(
    uint256 amountIn,
    address[] calldata path
  ) external view returns (uint256[] memory amounts);

  /**
   * @notice Returns the amounts of tokens involved in a swap given an output amount.
   * @param amountOut The output amount.
   * @param path The swap path.
   * @return amounts The amounts of each token involved in the swap.
   */
  function getAmountsIn(
    uint256 amountOut,
    address[] calldata path
  ) external view returns (uint256[] memory amounts);

  /**
   * @notice Removes liquidity from an ERC-20/ETH pair, supporting fee-on-transfer tokens.
   * @param token The address of the ERC-20 token.
   * @param liquidity The amount of liquidity tokens to burn.
   * @param amountTokenMin The minimum amount of the ERC-20 token.
   * @param amountETHMin The minimum amount of ETH.
   * @param to The address to receive the underlying assets.
   * @param deadline The transaction deadline.
   * @return amountETH The amount of ETH received.
   */
  function removeLiquidityETHSupportingFeeOnTransferTokens(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountETH);

  /**
   * @notice Removes liquidity from an ERC-20/ETH pair with permit, supporting fee-on-transfer tokens.
   * @param token The address of the ERC-20 token.
   * @param liquidity The amount of liquidity tokens to burn.
   * @param amountTokenMin The minimum amount of the ERC-20 token.
   * @param amountETHMin The minimum amount of ETH.
   * @param to The address to receive the underlying assets.
   * @param deadline The transaction deadline.
   * @param approveMax Whether to approve the maximum amount.
   * @param v The v component of the permit signature.
   * @param r The r component of the permit signature.
   * @param s The s component of the permit signature.
   * @return amountETH The amount of ETH received.
   */
  function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 amountETH);

  /**
   * @notice Swaps an exact amount of input tokens for as many output tokens as possible, supporting fee-on-transfer tokens.
   * @param amountIn The amount of input tokens to swap.
   * @param amountOutMin The minimum amount of output tokens.
   * @param path The swap path.
   * @param to The address to receive the output tokens.
   * @param deadline The transaction deadline.
   */
  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;

  /**
   * @notice Swaps ETH for as many output tokens as possible, supporting fee-on-transfer tokens.
   * @param amountOutMin The minimum amount of output tokens.
   * @param path The swap path.
   * @param to The address to receive the output tokens.
   * @param deadline The transaction deadline.
   */
  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable;

  /**
   * @notice Swaps an exact amount of input tokens for as much ETH as possible, supporting fee-on-transfer tokens.
   * @param amountIn The amount of input tokens to swap.
   * @param amountOutMin The minimum amount of ETH.
   * @param path The swap path.
   * @param to The address to receive the ETH.
   * @param deadline The transaction deadline.
   */
  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;
}
