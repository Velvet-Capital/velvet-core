// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {AssetManagerCheck} from "./AssetManagerCheck.sol";
import {IProtocolConfig} from "../../config/protocol/IProtocolConfig.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

/**
 * @title PortfolioSettings
 * @dev Manages the configuration settings for a portfolio, including its visibility,
 * transferability, initial portfolio price, and minimum portfolio token amount. Ensures that
 * portfolios adhere to protocol-wide constraints and allows asset managers to update settings.
 */
abstract contract PortfolioSettings is AssetManagerCheck, Initializable {
  IProtocolConfig private protocolConfig;

  // Indicates if the portfolio is open to the public
  bool public publicPortfolio;
  // Indicates if the portfolio's tokens can be transferred
  bool public transferable;
  // Indicates if the portfolio's tokens can be transferred to the public
  bool public transferableToPublic;

  // The initial amount of the portfolio upon creation
  uint256 public initialPortfolioAmount;
  // The minimum amount of portfolio tokens that must be held or withdrawn completely
  uint256 public minPortfolioTokenHoldingAmount;

  // Events for logging updates to portfolio settings
  event TransferabilityUpdated(
    bool indexed _transferable,
    bool indexed _publicTransfers
  );
  event ChangedPortfolioToPublic(
    bool indexed isPublic,
    bool indexed isTransferableToPublic
  );
  event MinPortfolioTokenHoldingAmountUpdated(
    uint256 indexed _minPortfolioTokenHoldingAmount
  );
  event InitialPortfolioAmountUpdated(
    uint256 indexed _newInitialPortfolioAmount
  );

  /**
   * Initializes portfolio settings with values conforming to the protocol configuration.
   * @param _protocolConfig Address of the protocol configuration contract.
   * @param _initialPortfolioAmount The initial amount set for the portfolio.
   * @param _minPortfolioTokenHoldingAmount The minimum portfolio token amount for transactions.
   * @param _publicPortfolio Whether the portfolio is publicly accessible.
   * @param _transferable Whether the portfolio's tokens can be transferred.
   * @param _transferableToPublic Whether the portfolio's tokens can be transferred to the public.
   */
  function __PortfolioSettings_init(
    address _protocolConfig,
    uint256 _initialPortfolioAmount,
    uint256 _minPortfolioTokenHoldingAmount,
    bool _publicPortfolio,
    bool _transferable,
    bool _transferableToPublic
  ) internal onlyInitializing {
    if (_protocolConfig == address(0)) revert ErrorLibrary.InvalidAddress();
    protocolConfig = IProtocolConfig(_protocolConfig);

    if (_initialPortfolioAmount < protocolConfig.minInitialPortfolioAmount()) {
      revert ErrorLibrary.InvalidMinPortfolioAmountByAssetManager();
    }

    if (
      _minPortfolioTokenHoldingAmount <
      protocolConfig.minPortfolioTokenHoldingAmount()
    ) {
      revert ErrorLibrary.InvalidMinAmountByAssetManager();
    }

    initialPortfolioAmount = _initialPortfolioAmount;
    minPortfolioTokenHoldingAmount = _minPortfolioTokenHoldingAmount;
    publicPortfolio = _publicPortfolio;
    _setTransferability(_transferable, _transferableToPublic);
  }

  /**
   * Internal/Helper function to set the transferability settings for the portfolio.
   * @param _transferable Whether the portfolio's tokens can be transferred.
   * @param _publicTransfer Whether the portfolio's tokens can be transferred to the public.
   */
  function _setTransferability(
    bool _transferable,
    bool _publicTransfer
  ) internal {
    transferable = _transferable;

    if (!transferable) {
      transferableToPublic = false;
    } else {
      if (publicPortfolio) {
        if (!_publicTransfer) {
          revert ErrorLibrary.PublicFundToWhitelistedNotAllowed();
        }
        transferableToPublic = true;
      } else {
        transferableToPublic = _publicTransfer;
      }
    }
    emit TransferabilityUpdated(transferable, transferableToPublic);
  }

  /**
   * Updates the transferability settings for the portfolio.
   * @param _transferable Whether the portfolio's tokens can be transferred.
   * @param _publicTransfer Whether the portfolio's tokens can be transferred to the public.
   */
  function updateTransferability(
    bool _transferable,
    bool _publicTransfer
  ) external onlyAssetManager {
    _setTransferability(_transferable, _publicTransfer);
  }

  /**
   * Converts a private portfolio to a public one, enabling wider access.
   */
  function convertPrivateFundToPublic() external onlyAssetManager {
    publicPortfolio = true;
    if (transferable) {
      transferableToPublic = true;
    }
    emit ChangedPortfolioToPublic(publicPortfolio, transferableToPublic);
  }

  /**
   * Updates the minimum portfolio token amount required for transactions.
   * @param _minPortfolioTokenHoldingAmount The new minimum portfolio token amount.
   */
  function updateMinPortfolioTokenHoldingAmount(
    uint256 _minPortfolioTokenHoldingAmount
  ) external onlyAssetManager {
    if (
      _minPortfolioTokenHoldingAmount <
      protocolConfig.minPortfolioTokenHoldingAmount()
    ) revert ErrorLibrary.InvalidMinPortfolioTokenHoldingAmount();

    minPortfolioTokenHoldingAmount = _minPortfolioTokenHoldingAmount;
    emit MinPortfolioTokenHoldingAmountUpdated(_minPortfolioTokenHoldingAmount);
  }

  /**
   * Sets a new initial portfolio price.
   * @param _newAmount The new initial portfolio amount.
   */
  function updateInitialPortfolioAmount(
    uint256 _newAmount
  ) external onlyAssetManager {
    if (_newAmount < protocolConfig.minInitialPortfolioAmount())
      revert ErrorLibrary.InvalidInitialPortfolioAmount();

    initialPortfolioAmount = _newAmount;
    emit InitialPortfolioAmountUpdated(_newAmount);
  }
}
