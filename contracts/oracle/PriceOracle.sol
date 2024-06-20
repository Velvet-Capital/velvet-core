// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {PriceOracleAbstract} from "./PriceOracleAbstract.sol";
import {ErrorLibrary} from "../library/ErrorLibrary.sol";

/**
 * @title PriceOracle
 * @dev Inherits from PriceOracleAbstract to provide latest price data for token pairs.
 * This implementation focuses on a straightforward retrieval of price data without
 * additional infrastructure or sequencer uptime checks.
 */
contract PriceOracle is PriceOracleAbstract {
  /**
   * @dev Initializes the PriceOracle with the WETH token address.
   * @param _WETH Address of the Wrapped Ether (WETH) token, used as a reference for price queries.
   */
  constructor(address _WETH) PriceOracleAbstract(_WETH) {}

  /**
   * @notice Fetches the latest price data for a given token pair.
   * @param base The address of the base token for which price data is being queried.
   * @param quote The address of the quote token against which the base token's price is measured.
   * @return price The latest available price of the base token in terms of the quote token.
   */
  function _latestRoundData(
    address base,
    address quote
  ) internal view override returns (int256) {
    // Fetch the latest round data from the aggregator for the given token pair.
    (, int256 answer, , uint256 updatedAt, ) = tokenPairToAggregator[base]
      .aggregators[quote]
      .latestRoundData();

    // Validate that the retrieved price is a valid non-zero value.
    if (updatedAt + oracleExpirationThreshold < block.timestamp)
      revert ErrorLibrary.PriceOracleExpired();

    if (answer <= 0) revert ErrorLibrary.PriceOracleInvalid();

    return answer;
  }
}
