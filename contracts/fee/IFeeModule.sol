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
   */
  function _chargeProtocolAndManagementFees() external;

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
}
