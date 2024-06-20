// SPDX-License-Identifier: BUSL-1.1

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";

/**
 * @title TokenCalculations
 * @dev Provides utility functions for calculating token amounts and ratios in the context of portfolio funds.
 * This contract contains pure functions that are essential for determining the minting amounts for new deposits
 * and calculating the proportionate share of a deposit within the vault. It is utilized by the main
 * portfolio fund contract to facilitate user deposits and withdrawals.
 */
pragma solidity 0.8.17;

contract TokenCalculations {
  // A constant representing the conversion factor from ETH to WEI, facilitating calculations with token amounts.
  uint256 internal constant ONE_ETH_IN_WEI = 10 ** 18;

  /**
   * @notice Calculates the amount of portfolio tokens to mint based on the user's deposit share and total supply.
   * @dev This function is crucial for determining the correct amount of portfolio tokens a user receives upon deposit,
   * taking into account the existing total supply of portfolio tokens.
   * @param _userShare The proportionate deposit amount in WEI the user is making into the fund.
   * @param _totalSupply The current total supply of portfolio tokens in the fund.
   * @return The amount of portfolio tokens that should be minted for the user's deposit.
   */
  function _calculateMintAmount(
    uint256 _userShare,
    uint256 _totalSupply
  ) internal pure returns (uint256) {
    uint256 remainingShare = ONE_ETH_IN_WEI - _userShare;
    if (remainingShare == 0) revert ErrorLibrary.DivisionByZero();
    return (_userShare * _totalSupply) / remainingShare;
  }

  /**
   * @notice Calculates the ratio of an deposit amount to the total token balance in the vault.
   * @dev This helper function computes the ratio of a user's deposit to the total holdings of a specific token
   * in the vault, facilitating proportional deposits and withdrawals.
   * @param depositAmount The amount of a specific token the user wishes to deposit, in WEI.
   * @param tokenBalance The total balance of that specific token currently held in the vault.
   * @return The deposit ratio, scaled to 18 decimal places to maintain precision.
   */
  function _getDepositToVaultBalanceRatio(
    uint256 depositAmount,
    uint256 tokenBalance
  ) internal pure returns (uint256) {
    if (tokenBalance == 0) revert ErrorLibrary.BalanceOfVaultIsZero();

    // Calculate the deposit ratio to 18 decimal precision
    return (depositAmount * ONE_ETH_IN_WEI) / tokenBalance;
  }
}
