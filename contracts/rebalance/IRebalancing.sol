// SPDX-License-Identifier: BUSL-1.1

/**
 * @title IRebalancing for a particular Portfolio
 * @author Velvet.Capital
 * @notice This contract is used by asset manager to update weights, update tokens and call pause function. It also
 *         includes the feeModule logic.
 * @dev This contract includes functionalities:
 *      1. Pause the Portfolio contract
 *      2. Update the token list
 *      3. Update the token weight
 *      4. Update the treasury address
 */

pragma solidity 0.8.17;

import {IPortfolio} from "../core/interfaces/IPortfolio.sol";
import {FunctionParameters} from "../FunctionParameters.sol";

interface IRebalancing {
  event UpdatedWeights();
  event UpdatedTokens(address[] newTokens);

  function init(IPortfolio _portfolio, address _accessController) external;

  /**
   * @notice The function updates the token weights and rebalances the portfolio to the new weights
   * @param denorms The new token weights of the portfolio
   */
  function updateWeights(uint96[] calldata denorms, uint256 _slippage) external;

  /**
   * @notice Updates the token list and adjusts weights based on provided rebalance data.
   * @dev This function is called by the asset manager to rebalance the portfolio.
   * @param rebalanceData The data required for rebalancing, including tokens to sell, new tokens, sell amounts, handler, and call data.
   */
  function updateTokens(
    FunctionParameters.RebalanceIntent calldata rebalanceData
  ) external;

  function removePortfolioToken(address _token) external;

  function allowToken(address _token) external;

  function removeNonPortfolioToken(address _token) external;
}
