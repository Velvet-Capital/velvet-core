// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {AggregatorV2V3Interface, AggregatorInterface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import {Denominations} from "@chainlink/contracts/src/v0.8/Denominations.sol";
import {ErrorLibrary} from "../library/ErrorLibrary.sol";

/**
 * @title PriceOracle
 * @dev Abstract contract for integrating Chainlink price feeds.
 * Allows adding, updating, and fetching price feeds for various token pairs.
 */
abstract contract PriceOracleAbstract is Ownable {
  // Custom errors for contract-specific failure conditions.
  error AggregatorAlreadyExistsError();
  error InvalidAddressError();
  error FeedNotFoundError();
  error NonExistingFeed();

  // Stores aggregator information for each token pair.
  struct TokenPairAggregator {
    mapping(address => AggregatorV2V3Interface) aggregators;
  }

  // WETH token address for price conversions.
  address public immutable WETH;

  // Maps base token to its quote token and corresponding Chainlink aggregator.
  mapping(address => TokenPairAggregator) internal tokenPairToAggregator;

  // Threshold for how old oracle data can be before considered expired.
  uint256 public oracleExpirationThreshold;

  // Events for logging contract activities.
  event FeedAdded(
    address indexed base,
    address indexed quote,
    address indexed aggregator
  );
  event FeedUpdated(
    address indexed base,
    address indexed quote,
    address indexed aggregator
  );
  event OracleExpirationThresholdUpdated(
    uint256 indexed oracleExpirationThreshold
  );

  /**
   * @param _WETH Address of the Wrapped Ether (WETH) token.
   */
  constructor(address _WETH) {
    if (_WETH == address(0)) revert InvalidAddressError();
    WETH = _WETH;
    oracleExpirationThreshold = 25 hours; // Default threshold.
  }

  /**
   * @dev Adds or updates Chainlink price feeds for token pairs.
   * @param bases Array of base token addresses.
   * @param quotes Array of quote token addresses corresponding to each base token.
   * @param aggregators Array of Chainlink aggregator contracts for each token pair.
   */
  function setFeeds(
    address[] memory bases,
    address[] memory quotes,
    AggregatorV2V3Interface[] memory aggregators
  ) external onlyOwner {
    if (!(bases.length == quotes.length && quotes.length == aggregators.length))
      revert ErrorLibrary.IncorrectArrayLength();

    uint256 baseAddressesLength = bases.length;
    for (uint256 i; i < baseAddressesLength; i++) {
      if (
        bases[i] == address(0) ||
        quotes[i] == address(0) ||
        address(aggregators[i]) == address(0)
      ) {
        revert InvalidAddressError();
      }

      // Check if the aggregator already exists to avoid overwriting.
      if (
        address(tokenPairToAggregator[bases[i]].aggregators[quotes[i]]) !=
        address(0)
      ) {
        revert AggregatorAlreadyExistsError();
      }

      // Set the new aggregator.
      tokenPairToAggregator[bases[i]].aggregators[quotes[i]] = aggregators[i];
      emit FeedAdded(bases[i], quotes[i], address(aggregators[i]));
    }
  }

  /**
   * @dev Updates an existing Chainlink price feed for a token pair.
   * @param base The address of the base token.
   * @param quote The address of the quote token.
   * @param aggregator The new Chainlink aggregator contract for the token pair.
   */
  function updateFeed(
    address base,
    address quote,
    AggregatorV2V3Interface aggregator
  ) external onlyOwner {
    if (
      base == address(0) ||
      quote == address(0) ||
      address(aggregator) == address(0)
    ) {
      revert InvalidAddressError();
    }

    tokenPairToAggregator[base].aggregators[quote] = aggregator;
    emit FeedUpdated(base, quote, address(aggregator));
  }

  /**
   * @notice Updates the oracle timeout threshold
   * @param _newTimeout New timeout threshold set by owner
   */
  function updateOracleExpirationThreshold(
    uint256 _newTimeout
  ) external onlyOwner {
    oracleExpirationThreshold = _newTimeout;
    emit OracleExpirationThresholdUpdated(oracleExpirationThreshold);
  }

  /**
   * @notice Returns the decimals of a token pair price feed
   * @param base base asset address
   * @param quote quote asset address
   * @return Decimals of the token pair
   */
  function decimals(address base, address quote) public view returns (uint8) {
    AggregatorV2V3Interface aggregator = tokenPairToAggregator[base]
      .aggregators[quote];
    if (address(aggregator) == address(0)) {
      revert NonExistingFeed();
    }
    return aggregator.decimals();
  }

  /**
   * @notice Returns the latest USD price for a specific token and amount
   * @param _base base asset address
   * @param amountIn The amount of base tokens to be converted to USD
   * @return amountOut The latest USD token price of the base token
   */
  function convertToUSD18Decimals(
    address _base,
    uint256 amountIn
  ) external view returns (uint256 amountOut) {
    uint256 output = uint256(_latestRoundData(_base, Denominations.USD));
    uint256 decimalChainlink = decimals(_base, Denominations.USD);
    IERC20MetadataUpgradeable token = IERC20MetadataUpgradeable(_base);
    uint8 decimal = token.decimals();

    uint256 diff = 18 - decimal;

    amountOut = (output * amountIn * (10 ** diff)) / (10 ** decimalChainlink);
  }

  /**
   * @dev Abstract function to fetch the latest round data from Chainlink.
   * Must be implemented in derived contracts.
   * @param base The address of the base token.
   * @param quote The address of the quote token.
   * @return The latest price data.
   */
  function _latestRoundData(
    address base,
    address quote
  ) internal view virtual returns (int256);
}
