// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../library/ErrorLibrary.sol";

import {IPortfolio} from "../core/interfaces/IPortfolio.sol";
import {IAccessController} from "../access/IAccessController.sol";
import {IProtocolConfig} from "../config/protocol/IProtocolConfig.sol";
import {IAssetManagementConfig} from "../config/assetManagement/IAssetManagementConfig.sol";

import {ITokenExclusionManager} from "../core/interfaces/ITokenExclusionManager.sol";

import {AccessRoles} from "../access/AccessRoles.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

import {TokenBalanceLibrary} from "../core/calculations/TokenBalanceLibrary.sol";

/**
 * @title RebalancingConfig
 * @notice Provides auxiliary functions to support the RebalancingCore contract operations, including balance checks and validator checks.
 * @dev This contract includes helper functions for rebalancing operations such as validating handler, checking token balances, and initial setup.
 */

contract RebalancingConfig is AccessRoles, Initializable, TokenBalanceLibrary {
  IPortfolio public portfolio;
  IAccessController public accessController;
  IProtocolConfig public protocolConfig;
  IAssetManagementConfig public assetManagementConfig;
  ITokenExclusionManager internal tokenExclusionManager;

  mapping(address => bool) public tokensMapping;

  address internal _vault;

  /**
   * @notice Initializes the contract with portfolio, access controller, protocol and asset management configuration.
   * @param _portfolio Address of the Portfolio contract.
   * @param _accessController Address of the AccessController.
   */
  function __RebalancingHelper_init(
    address _portfolio,
    address _accessController
  ) internal onlyInitializing {
    if (_portfolio == address(0) || _accessController == address(0))
      revert ErrorLibrary.InvalidAddress();

    portfolio = IPortfolio(_portfolio);
    accessController = IAccessController(_accessController);
    protocolConfig = IProtocolConfig(portfolio.protocolConfig());
    assetManagementConfig = IAssetManagementConfig(
      portfolio.assetManagementConfig()
    );
    tokenExclusionManager = ITokenExclusionManager(
      portfolio.tokenExclusionManager()
    );
    _vault = portfolio.vault();
  }

  /**
   * @dev Ensures that the function is only called by an asset manager.
   */
  modifier onlyAssetManager() {
    if (!accessController.hasRole(ASSET_MANAGER, msg.sender)) {
      revert ErrorLibrary.CallerNotAssetManager();
    }
    _;
  }

  /**
   * @notice Checks that each token bought by the Solver is in the portfolio list.
   * @param _ensoBuyTokens Array of token addresses bought by the Solver.
   * @param _newTokens Array of new portfolio tokens.
   */
  function _verifyNewTokenList(
    address[] memory _ensoBuyTokens,
    address[] memory _newTokens
  ) internal {
    uint256 tokenLength = _newTokens.length;
    for (uint256 i; i < tokenLength; i++) {
      address token = _newTokens[i];
      if (_getTokenBalanceOf(token, _vault) == 0)
        revert ErrorLibrary.BalanceOfVaultCannotNotBeZero(token);
      tokensMapping[token] = true;
    }

    uint256 ensoBuyTokensLength = _ensoBuyTokens.length;
    for (uint256 i; i < ensoBuyTokensLength; i++) {
      if (!tokensMapping[_ensoBuyTokens[i]]) {
        revert ErrorLibrary.InvalidBuyTokenList();
      }
    }

    for (uint256 i; i < tokenLength; i++) {
      delete tokensMapping[_newTokens[i]];
    }
  }

  /**
   * @notice Updates the token balance mapping based on the new token list.
   * @param _portfolioTokens Array of current portfolio tokens.
   * @param _newTokens Array of new tokens after rebalancing.
   */
  function _verifyZeroBalanceForRemovedTokens(
    address[] memory _portfolioTokens,
    address[] memory _newTokens
  ) internal {
    uint256 tokenLength = _portfolioTokens.length;
    for (uint256 i; i < tokenLength; i++) {
      tokensMapping[_portfolioTokens[i]] = true;
    }

    uint256 newTokensLength = _newTokens.length;
    for (uint256 i; i < newTokensLength; i++) {
      tokensMapping[_newTokens[i]] = false;
    }

    for (uint256 i; i < tokenLength; i++) {
      address _portfolioToken = _portfolioTokens[i];
      if (tokensMapping[_portfolioToken]) {
        if (_getTokenBalanceOf(_portfolioToken, _vault) != 0)
          revert ErrorLibrary.NonPortfolioTokenBalanceIsNotZero();
      }
      delete tokensMapping[_portfolioToken];
    }
  }

  /**
   * @notice The function is used to get tokens from portfolio
   * @return Array of token returned
   */
  function _getCurrentTokens() internal view returns (address[] memory) {
    return portfolio.getTokens();
  }

  /**
   * @notice Checks if a token is part of the current portfolio token list.
   * @param _token The address of the token to check.
   * @return bool Returns true if the token is part of the portfolio, false otherwise.
   */
  function _isPortfolioToken(address _token) internal view returns (bool) {
    address[] memory currentTokens = _getCurrentTokens();
    uint256 tokensLength = currentTokens.length;
    for (uint256 i; i < tokensLength; i++) {
      if (currentTokens[i] == _token) {
        return true;
      }
    }
    return false;
  }
}
