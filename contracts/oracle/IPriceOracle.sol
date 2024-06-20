// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

interface IPriceOracle {
  function WETH() external returns (address);

  function _addFeed(
    address base,
    address quote,
    AggregatorV2V3Interface aggregator
  ) external;

  function convertToUSD18Decimals(
    address _base,
    uint256 amountIn
  ) external view returns (uint256 amountOut);
}
