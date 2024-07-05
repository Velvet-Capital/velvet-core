// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {FeeConfig} from "./FeeConfig.sol";
import {FeeCalculations} from "./FeeCalculations.sol";
import {IPriceOracle} from "../oracle/IPriceOracle.sol";
import {ErrorLibrary} from "../library/ErrorLibrary.sol";

/**
 * @title FeeModule
 * @dev Manages the minting of fees for different operations, utilizing configurations from FeeConfig and calculations from FeeCalculations.
 */
contract FeeModule is FeeConfig, FeeCalculations {
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
  ) external {
    FeeConfig._initialize(
      _portfolio,
      _assetManagementConfig,
      _protocolConfig,
      _accessController
    );
  }

  /**
   * @dev Mints fees to a specified address if the amount is greater than the minimum fee threshold.
   * @param _to The address to mint the fees to.
   * @param _amount The amount of fees to mint.
   * @return The actual amount of fees minted.
   */
  function _mintFees(address _to, uint256 _amount) internal returns (uint256) {
    if (_amount < MIN_MINT_FEE) return 0;

    portfolio.mintShares(_to, _amount);
    return _amount;
  }

  /**
   * @dev Mints both protocol and management fees based on their respective calculated amounts.
   * @param _assetManagerFeeToMint The amount of asset manager fees to mint.
   * @param _protocolFeeToMint The amount of protocol fees to mint.
   */
  function _mintProtocolAndManagementFees(
    uint256 _assetManagerFeeToMint,
    uint256 _protocolFeeToMint
  )
    internal
    returns (uint256 assetManagerFeeMinted, uint256 protocolFeeMinted)
  {
    assetManagerFeeMinted = _mintFees(
      assetManagementConfig.assetManagerTreasury(),
      _assetManagerFeeToMint
    );
    protocolFeeMinted = _mintFees(
      protocolConfig.velvetTreasury(),
      _protocolFeeToMint
    );
  }

  /**
   * @dev Internal function to charge and mint protocol and management fees based on current configurations and token supply.
   * This function calculates the fees to be minted and updates the last fee charged timestamp.
   */
  function _chargeProtocolAndManagementFees() internal nonReentrant {
    uint256 _managementFee = assetManagementConfig.managementFee();
    uint256 _protocolFee = protocolConfig.protocolFee();
    uint256 _protocolStreamingFee = protocolConfig.protocolStreamingFee();
    uint256 _totalSupply = portfolio.totalSupply();

    if (
      _totalSupply == 0 ||
      (_managementFee == 0 && _protocolFee == 0 && _protocolStreamingFee == 0)
    ) {
      _setLastFeeCharged();
      return;
    }

    (
      uint256 assetManagerFeeToMint,
      uint256 protocolFeeToMint
    ) = _calculateProtocolAndManagementFeesToMint(
        _managementFee,
        _protocolFee,
        _protocolStreamingFee,
        _totalSupply,
        lastChargedManagementFee,
        lastChargedProtocolFee,
        block.timestamp
      );

    _mintProtocolAndManagementFees(assetManagerFeeToMint, protocolFeeToMint);
    _setLastFeeCharged();

    emit FeesToBeMinted(
      assetManagementConfig.assetManagerTreasury(),
      protocolConfig.velvetTreasury(),
      protocolFeeToMint,
      assetManagerFeeToMint
    );
  }

  /**
   * @dev External function to charge and mint protocol and management fees.
   * Can only be called by the portfolio manager.
   */
  function chargeProtocolAndManagementFeesProtocol()
    external
    onlyPortfolioManager
  {
    _chargeProtocolAndManagementFees();
  }

  /**
   * @notice External function to charge protocol and management fees.
   * Can only be called when the protocol is not in emergency pause.
   */
  function chargeProtocolAndManagementFees()
    external
    protocolNotEmergencyPaused
  {
    _chargeProtocolAndManagementFees();
  }

  /**
   * @dev Charges entry or exit fees based on a specified percentage, adjusting the mint amount accordingly.
   * @param _mintAmount The amount being minted or burned, subject to entry/exit fees.
   * @param _fee The fee percentage to apply.
   * @return userAmount The amount after fees have been deducted.
   */
  function _chargeEntryOrExitFee(
    uint256 _mintAmount,
    uint256 _fee
  ) external nonReentrant onlyPortfolioManager returns (uint256 userAmount) {
    uint256 entryOrExitFee = _calculateEntryOrExitFee(_fee, _mintAmount);
    (uint256 protocolFee, uint256 assetManagerFee) = _splitFee(
      entryOrExitFee,
      protocolConfig.protocolFee()
    );

    (assetManagerFee, protocolFee) = _mintProtocolAndManagementFees(
      assetManagerFee,
      protocolFee
    );
    userAmount = _mintAmount - protocolFee - assetManagerFee;

    emit EntryExitFeeCharged(protocolFee, assetManagerFee);
  }

  /**
   * @dev Calculates and mints performance fees based on the vault's performance relative to a high watermark.
   * Can only be called by the asset manager when the protocol is not in emergency pause.
   */
  function chargePerformanceFee()
    external
    onlyAssetManager
    protocolNotEmergencyPaused
    nonReentrant
  {
    uint256 totalSupply = portfolio.totalSupply();

    uint256 vaultBalance = portfolio.getVaultValueInUSD(
      IPriceOracle(protocolConfig.oracle()),
      portfolio.getTokens(),
      totalSupply,
      portfolio.vault()
    );
    uint256 currentPrice = _getCurrentPrice(vaultBalance, totalSupply);

    if (totalSupply == 0 || vaultBalance == 0 || highWatermark == 0) {
      _updateHighWaterMark(currentPrice);
      return;
    }

    uint256 performanceFee = _calculatePerformanceFeeToMint(
      currentPrice,
      highWatermark,
      totalSupply,
      vaultBalance,
      assetManagementConfig.performanceFee()
    );

    (uint256 protocolFee, uint256 assetManagerFee) = _splitFee(
      performanceFee,
      protocolConfig.protocolFee()
    );

    _mintProtocolAndManagementFees(assetManagerFee, protocolFee);
    _updateHighWaterMark(
      _getCurrentPrice(vaultBalance, portfolio.totalSupply())
    );
  }

  /**
   * @notice Modifier to restrict function execution if the protocol is in emergency pause.
   * Uses the `isProtocolEmergencyPaused` function to determine the protocol's pause status.
   * @dev Reverts with a ProtocolEmergencyPaused error if the protocol is paused.
   */
  modifier protocolNotEmergencyPaused() {
    if (protocolConfig.isProtocolEmergencyPaused())
      revert ErrorLibrary.ProtocolEmergencyPaused();
    _; // Continues function execution if the protocol is not paused
  }
}
