// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ErrorLibrary} from "../../library/ErrorLibrary.sol";

/**
 * @title Token Balance Library
 * @dev Library for managing token balances within a vault. Provides utility functions to fetch individual
 * and collective token balances from a specified vault address.
 */
contract TokenBalanceLibrary {
  /**
   * @notice Fetches the balances of multiple tokens from a single vault.
   * @dev Iterates through an array of token addresses to retrieve each token's balance in the vault.
   * Utilizes `_getTokenBalanceOf` to fetch each individual token balance securely and efficiently.
   *
   * @param portfolioTokens Array of ERC20 token addresses whose balances are to be fetched.
   * @param _vault The vault address from which to retrieve the balances.
   * @return vaultBalances Array of balances corresponding to the list of input tokens.
   */
  function getTokenBalancesOf(
    address[] memory portfolioTokens,
    address _vault
  ) public view returns (uint256[] memory vaultBalances) {
    uint256 portfolioLength = portfolioTokens.length;
    vaultBalances = new uint256[](portfolioLength); // Initializes the array to hold fetched balances.
    for (uint256 i; i < portfolioLength; i++) {
      vaultBalances[i] = _getTokenBalanceOf(portfolioTokens[i], _vault); // Fetches balance for each token.
    }
  }

  /**
   * @notice Fetches the balance of a specific token held in a given vault.
   * @dev Retrieves the token balance using the ERC20 `balanceOf` function.
   * Throws if the token or vault address is zero to prevent erroneous queries.
   *
   * @param _token The address of the token whose balance is to be retrieved.
   * @param _vault The address of the vault where the token is held.
   * @return tokenBalance The current token balance within the vault.
   */
  function _getTokenBalanceOf(
    address _token,
    address _vault
  ) internal view returns (uint256 tokenBalance) {
    if (_token == address(0) || _vault == address(0))
      revert ErrorLibrary.InvalidAddress(); // Ensures neither the token nor the vault address is zero.
    tokenBalance = IERC20Upgradeable(_token).balanceOf(_vault); // Actual balance fetch.
  }
}
