// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import { TokenCalculations } from "../core/calculations/TokenCalculations.sol";
import { FeeEvents } from "./FeeEvents.sol";

/**
 * @title FeeCalculations
 * @dev Provides utility functions for calculating various types of fees
 *      for financial operations, such as entry/exit fees, streaming fees,
 *      and performance fees. Designed for use by other contracts to ensure
 *      consistent and accurate fee calculations.
 */
contract FeeCalculations is TokenCalculations, FeeEvents {
  uint256 public constant TOTAL_WEIGHT = 10_000; // Represents 100% in basis points.
  uint256 public constant ONE_YEAR_IN_SECONDS = 365 days; // Used for annualized fee calculations.

  /**
   * @notice Calculates the current price per token.
   * @param _vaultBalance Total value in the vault.
   * @param _totalSupply Total supply of tokens.
   * @return currentPrice The price of each token.
   */
  function _getCurrentPrice(
    uint256 _vaultBalance,
    uint256 _totalSupply
  ) internal pure returns (uint256 currentPrice) {
    currentPrice = _totalSupply == 0
      ? 0
      : (_vaultBalance * ONE_ETH_IN_WEI) / _totalSupply;
  }

  /**
   * @notice Calculates entry or exit fees for a given token amount.
   * @param _feePercentage Fee rate in basis points.
   * @param _tokenAmount Amount of tokens to calculate the fee for.
   * @return Calculated fee amount in tokens.
   */
  function _calculateEntryOrExitFee(
    uint256 _feePercentage,
    uint256 _tokenAmount
  ) internal pure returns (uint256) {
    return (_tokenAmount * _feePercentage) / TOTAL_WEIGHT;
  }

  /**
   * @notice Splits a fee between the protocol and the asset manager.
   * @param _feeAmount Total fee amount to be split.
   * @param _protocolFeePercentage Portion of the fee allocated to the protocol in basis points.
   * @return protocolFeeAmount Amount of fee allocated to the protocol.
   * @return assetManagerFee Amount of fee allocated to the asset manager.
   */
  function _splitFee(
    uint256 _feeAmount,
    uint256 _protocolFeePercentage
  ) internal pure returns (uint256 protocolFeeAmount, uint256 assetManagerFee) {
    if (_feeAmount == 0) {
      return (0, 0);
    }
    protocolFeeAmount = (_feeAmount * _protocolFeePercentage) / TOTAL_WEIGHT;
    assetManagerFee = _feeAmount - protocolFeeAmount;
  }

  /**
   * @notice Calculates the streaming fee over a specified period.
   * @param _totalSupply Total supply of tokens.
   * @param _lastChargedTime Timestamp of the last fee charge.
   * @param _feePercentage Annual fee rate in basis points.
   * @param _currentTime Current timestamp.
   * @return streamingFee The calculated streaming fee in tokens.
   */
  function _calculateStreamingFee(
    uint256 _totalSupply,
    uint256 _lastChargedTime,
    uint256 _feePercentage,
    uint256 _currentTime
  ) internal pure returns (uint256 streamingFee) {
    uint256 timeElapsed = _currentTime - _lastChargedTime;
    streamingFee =
      (_totalSupply * _feePercentage * timeElapsed) /
      ONE_YEAR_IN_SECONDS /
      TOTAL_WEIGHT;
  }

  /**
   * @notice Calculates the amount of tokens to mint for streaming fees.
   * @param _totalSupply Total supply of tokens.
   * @param _lastChargedTime Timestamp of the last fee charge.
   * @param _feePercentage Annual fee rate in basis points.
   * @param _currentTime Current timestamp.
   * @return tokensToMint Amount of tokens to mint as fees.
   */
  function _calculateMintAmountForStreamingFees(
    uint256 _totalSupply,
    uint256 _lastChargedTime,
    uint256 _feePercentage,
    uint256 _currentTime
  ) internal pure returns (uint256 tokensToMint) {
    if (_lastChargedTime >= _currentTime) {
      return 0;
    }

    uint256 streamingFees = _calculateStreamingFee(
      _totalSupply,
      _lastChargedTime,
      _feePercentage,
      _currentTime
    );

    // Calculates the share of the asset manager after minting
    uint256 feeReceiverShare = (streamingFees * ONE_ETH_IN_WEI) / _totalSupply;

    tokensToMint = _calculateMintAmount(feeReceiverShare, _totalSupply);
  }

  /**
   * @notice Calculates the management and protocol fees to be minted based on current settings.
   * @param _managementFeePercentage The management (asset manager) fee percentage in basis points.
   * @param _protocolFeePercentage The protocol fee percentage from the management fee in basis points.
   * @param _protocolStreamingFeePercentage The protocol streaming fee percentage in basis points.
   * @param _totalSupply The total supply of tokens.
   * @param _lastChargedManagementFee Timestamp of the last management fee charge.
   * @param _lastChargedProtocolFee Timestamp of the last protocol fee charge.
   * @param _currentTime Current block timestamp.
   * @return managementFeeToMint The amount of management fee to be minted for the asset manager.
   * @return protocolFeeToMint The total amount of protocol fee to be minted, including both streaming and management cut.
   */
  function _calculateProtocolAndManagementFeesToMint(
    uint256 _managementFeePercentage,
    uint256 _protocolFeePercentage,
    uint256 _protocolStreamingFeePercentage,
    uint256 _totalSupply,
    uint256 _lastChargedManagementFee,
    uint256 _lastChargedProtocolFee,
    uint256 _currentTime
  ) internal returns (uint256 managementFeeToMint, uint256 protocolFeeToMint) {
    // Calculate the mint amount for asset management streaming fees
    uint256 managementStreamingFeeToMint = _calculateMintAmountForStreamingFees(
      _totalSupply,
      _lastChargedManagementFee,
      _managementFeePercentage,
      _currentTime
    );

    // Calculate the mint amount for protocol streaming fees
    uint256 protocolStreamingFeeToMint = _calculateMintAmountForStreamingFees(
      _totalSupply,
      _lastChargedProtocolFee,
      _protocolStreamingFeePercentage,
      _currentTime
    );

    // Calculate the protocol's cut from the management streaming fee
    uint256 protocolCut;
    (protocolCut, managementFeeToMint) = _splitFee(
      managementStreamingFeeToMint,
      _protocolFeePercentage
    );

    // The total protocol fee to mint is the sum of the protocol's cut from the management fee plus the protocol streaming fee
    protocolFeeToMint = protocolCut + protocolStreamingFeeToMint;

    emit ManagementFeeCalculated(
      protocolStreamingFeeToMint,
      managementFeeToMint,
      protocolCut
    );
  }

  /**
   * @notice Calculates performance fee to mint based on the high watermark principle.
   * @param _currentPrice Current price per token.
   * @param _highWaterMark High watermark, representing the peak value reached by the token.
   * @param _totalSupply Total supply of tokens.
   * @param _vaultBalance Current vault balance.
   * @param _feePercentage Performance fee rate in basis points.
   * @return tokensToMint Amount of tokens to mint as performance fees.
   */
  function _calculatePerformanceFeeToMint(
    uint256 _currentPrice,
    uint256 _highWaterMark,
    uint256 _totalSupply,
    uint256 _vaultBalance,
    uint256 _feePercentage
  ) internal pure returns (uint256 tokensToMint) {
    if (_currentPrice <= _highWaterMark) {
      return 0; // No fee if current price is below or equal to high watermark
    }

    uint256 performanceIncrease = _currentPrice - _highWaterMark;
    uint256 performanceFee = (performanceIncrease *
      _totalSupply *
      _feePercentage) /
      ONE_ETH_IN_WEI /
      TOTAL_WEIGHT;

    tokensToMint =
      (performanceFee * _totalSupply) /
      (_vaultBalance - performanceFee);
  }
}
