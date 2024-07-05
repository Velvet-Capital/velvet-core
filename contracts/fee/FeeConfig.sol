// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/security/ReentrancyGuardUpgradeable.sol";
import {IPortfolio} from "../core/interfaces/IPortfolio.sol";
import {IAssetManagementConfig} from "../config/assetManagement/IAssetManagementConfig.sol";

import {IAccessController} from "../access/IAccessController.sol";
import {IProtocolConfig} from "../config/protocol/IProtocolConfig.sol";
import {ErrorLibrary} from "../library/ErrorLibrary.sol";
import {AccessRoles} from "../access/AccessRoles.sol";

/**
 * @title FeeConfig
 * @dev Abstract contract for fee configuration, including initial setup and access control.
 * Utilizes OpenZeppelin's upgradeable contracts framework for ownership and security.
 * Integrates with the system's components for fee management.
 */
abstract contract FeeConfig is
  OwnableUpgradeable,
  UUPSUpgradeable,
  AccessRoles,
  ReentrancyGuardUpgradeable
{
  // Interfaces for interacting with other contract components.
  IPortfolio public portfolio;
  IAssetManagementConfig public assetManagementConfig;
  IProtocolConfig public protocolConfig;
  IAccessController public accessController;

  // Minimum amount of fees that can be minted.
  uint256 internal constant MIN_MINT_FEE = 1_000_000;

  // Timestamps of the last charged protocol and management fees.
  uint256 public lastChargedProtocolFee;
  uint256 public lastChargedManagementFee;

  // High watermark value for performance fee calculation.
  uint256 public highWatermark;

  /**
   * @dev Modifier to allow only the portfolio manager to execute certain functions.
   */
  modifier onlyPortfolioManager() {
    if (!(accessController.hasRole(PORTFOLIO_MANAGER_ROLE, msg.sender))) {
      revert ErrorLibrary.CallerNotPortfolioManager();
    }
    _;
  }

  /**
   * @dev Modifier to allow only the asset manager to execute certain functions.
   */
  modifier onlyAssetManager() {
    if (!(accessController.hasRole(ASSET_MANAGER, msg.sender))) {
      revert ErrorLibrary.CallerNotAssetManager();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Internal function to initialize contract state. Designed to be called once during contract deployment.
   * @param _portfolio Address of the Portfolio contract.
   * @param _assetManagementConfig Address of the AssetManagementConfig contract.
   * @param _protocolConfig Address of the ProtocolConfig contract.
   * @param _accessController Address of the AccessController contract.
   */
  function _initialize(
    address _portfolio,
    address _assetManagementConfig,
    address _protocolConfig,
    address _accessController
  ) internal initializer {
    if (
      _portfolio == address(0) ||
      _assetManagementConfig == address(0) ||
      _protocolConfig == address(0) ||
      _accessController == address(0)
    ) revert ErrorLibrary.InvalidAddress();

    portfolio = IPortfolio(_portfolio);
    assetManagementConfig = IAssetManagementConfig(_assetManagementConfig);
    protocolConfig = IProtocolConfig(_protocolConfig);
    accessController = IAccessController(_accessController);

    __Ownable_init();
    __UUPSUpgradeable_init();
    __ReentrancyGuard_init();
  }

  /**
   * @dev Internal function to update the timestamps when fees are last charged.
   */
  function _setLastFeeCharged() internal {
    lastChargedProtocolFee = block.timestamp;
    lastChargedManagementFee = block.timestamp;
  }

  /**
   * @dev Internal function to update the high watermark for performance fee calculation.
   * @param _currentPrice Current price of the portfolio token in USD.
   */
  function _updateHighWaterMark(uint256 _currentPrice) internal {
    highWatermark = _currentPrice > highWatermark
      ? _currentPrice
      : highWatermark;
  }

  /**
   * @notice External function to update the high watermark, accessible only by the portfolio manager.
   * @param _currentPrice Current price of the portfolio token in USD to update the high watermark with.
   */
  function updateHighWaterMark(
    uint256 _currentPrice
  ) external onlyPortfolioManager {
    _updateHighWaterMark(_currentPrice);
  }

  /**
   * @notice Resets the high watermark for the portfolio to zero.
   * @dev This function can only be called by the portfolio manager. The high watermark represents the highest value
   * the portfolio has reached and is used for calculating performance fees. Resetting it to zero can be used for
   * specific scenarios, such as the start of a new performance period.
   */
  function resetHighWaterMark() external onlyPortfolioManager {
    highWatermark = 0;
  }

  /**
   * @notice Authorizes contract upgrade by the contract owner.
   * @param _newImplementation Address of the new contract implementation.
   */
  function _authorizeUpgrade(
    address _newImplementation
  ) internal override onlyOwner {
    // Intentionally left empty as required by an abstract contract
  }

  // Reserved storage gap to accommodate potential future layout adjustments.
  uint256[49] private __uint256GapFeeManagement;
}
