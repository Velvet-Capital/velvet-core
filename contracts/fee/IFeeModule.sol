// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface IFeeModule {
  /**
   * @dev Initializes the fee module, setting up the required configurations.
   * @param _portfolio The address of the Portfolio contract.
   * @param _assetManagementConfig The address of the AssetManagementConfig contract.
   * @param _protocolConfig The address of the ProtocolConfig contract.
   * @param _accessController The address of the AccessController contract.
   */
  function init(
    address _portfolio,
    address _assetManagementConfig,
    address _protocolConfig,
    address _accessController
  ) external;

  /**
   * @dev Charges and mints protocol and management fees based on current configurations and token supply.
   * Can only be called by the portfolio manager.
   */
  function chargeProtocolAndManagementFeesProtocol() external;

  /**
   * @dev Calculates and mints performance fees based on the vault's performance relative to a high watermark.
   * Can only be called by the asset manager when the protocol is not in emergency pause.
   */
  function chargeProtocolAndManagementFees() external;

  /**
   * @dev Charges entry or exit fees based on a specified percentage, adjusting the mint amount accordingly.
   * @param _mintAmount The amount being minted or burned, subject to entry/exit fees.
   * @param _fee The fee percentage to apply.
   * @return userAmount The amount after fees have been deducted.
   */
  function _chargeEntryOrExitFee(
    uint256 _mintAmount,
    uint256 _fee
  ) external returns (uint256);

  /**
   * @notice Returns the timestamp of the last protocol fee charged.
   * @return The timestamp of the last protocol fee charged.
   */
  function lastChargedProtocolFee() external view returns (uint256);

  /**
   * @notice Returns the timestamp of the last management fee charged.
   * @return The timestamp of the last management fee charged.
   */
  function lastChargedManagementFee() external view returns (uint256);

  /**
   * @dev Function to update the high watermark for performance fee calculation.
   * @param _currentPrice Current price of the portfolio token in USD.
   */
  function updateHighWaterMark(uint256 _currentPrice) external;

  /**
   * @notice Resets the high watermark for the portfolio to zero.
   * @dev This function can only be called by the portfolio manager. The high watermark represents the highest value
   * the portfolio has reached and is used for calculating performance fees. Resetting it to zero can be used for
   * specific scenarios, such as the start of a new performance period.
   */
  function resetHighWaterMark() external;

  function highWatermark() external view returns (uint256);

  function managementFee() external view returns (uint256);

  function performanceFee() external view returns (uint256);

  function entryFee() external view returns (uint256);

  function exitFee() external view returns (uint256);
}
