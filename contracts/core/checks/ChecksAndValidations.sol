// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {IPortfolio} from "../interfaces/IPortfolio.sol";
import {Dependencies} from "../config/Dependencies.sol";
import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";

/**
 * @title ChecksAndValidations
 * @dev Provides a suite of functions for performing various checks and validations across the platform, ensuring consistency and security in operations.
 * This abstract contract relies on inherited configurations from Dependencies to access global settings and state.
 */
abstract contract ChecksAndValidations is Dependencies {
  /**
   * @notice Validates the mint amount against a user-specified minimum to protect against slippage.
   * @param _mintAmount The amount of tokens calculated to be minted based on the user's deposited assets.
   * @param _minMintAmount The minimum acceptable amount of tokens the user expects to receive, preventing excessive slippage.
   */
  function _verifyUserMintedAmount(
    uint256 _mintAmount,
    uint256 _minMintAmount
  ) internal pure {
    if (_minMintAmount > _mintAmount) revert ErrorLibrary.InvalidMintAmount();
  }

  /**
   * @notice Verifies conditions before allowing an deposit to proceed.
   * @param _user The address of the user attempting to make the deposit.
   * @param _tokensLength The number of tokens in the portfolio at the time of deposit.
   * Ensures that the user is allowed to deposit based on the portfolio's public status and their whitelisting status.
   * Checks that the protocol is not paused and that the portfolio is properly initialized with tokens.
   */
  function _beforeDepositCheck(address _user, uint256 _tokensLength) internal {
    if (
      !(assetManagementConfig().publicPortfolio() ||
        assetManagementConfig().whitelistedUsers(_user)) ||
      _user == assetManagementConfig().assetManagerTreasury() ||
      _user == protocolConfig().velvetTreasury()
    ) {
      revert ErrorLibrary.UserNotAllowedToDeposit();
    }
    if (protocolConfig().isProtocolPaused()) {
      revert ErrorLibrary.ProtocolIsPaused();
    }
    if (_tokensLength == 0) {
      revert ErrorLibrary.PortfolioTokenNotInitialized();
    }
  }

  /**
   * @notice Performs checks before allowing a withdrawal operation to proceed.
   * @param owner The address of the token owner initiating the withdrawal.
   * @param portfolio The portfolio contract from which tokens are being withdrawn.
   * @param _tokenAmount The amount of portfolio tokens the user wishes to withdraw.
   * Verifies that the protocol is not in an emergency pause state.
   * Confirms that the user has sufficient tokens for the withdrawal.
   * Ensures that the withdrawal does not result in a balance below the minimum allowed portfolio token amount.
   */
  function _beforeWithdrawCheck(
    address owner,
    IPortfolio portfolio,
    uint256 _tokenAmount,
    uint256 _tokensLength,
    address[] memory _exemptionTokens
  ) internal view {
    if (protocolConfig().isProtocolEmergencyPaused()) {
      revert ErrorLibrary.ProtocolIsPaused();
    }
    uint256 balanceOfUser = portfolio.balanceOf(owner);
    if (_tokenAmount > balanceOfUser) {
      revert ErrorLibrary.CallerNotHavingGivenPortfolioTokenAmount();
    }
    uint256 balanceAfterRedemption = balanceOfUser - _tokenAmount;
    if (
      balanceAfterRedemption != 0 &&
      balanceAfterRedemption < protocolConfig().minPortfolioTokenHoldingAmount()
    ) {
      revert ErrorLibrary.CallerNeedToMaintainMinTokenAmount();
    }
    if (_exemptionTokens.length > _tokensLength) {
      revert ErrorLibrary.InvalidExemptionTokensLength();
    }
  }

  /**
   * @notice Validates a token before initializing it in the portfolio.
   * @param token The address of the token being validated.
   * Checks that the token is whitelisted if token whitelisting is enabled in the asset management configuration.
   * Ensures that the token address is not the zero address.
   */
  function _beforeInitCheck(address token) internal {
    if (
      (assetManagementConfig().tokenWhitelistingEnabled() &&
        !assetManagementConfig().whitelistedTokens(token))
    ) {
      revert ErrorLibrary.TokenNotWhitelisted();
    }
    if (token == address(0)) {
      revert ErrorLibrary.InvalidTokenAddress();
    }
  }
}
