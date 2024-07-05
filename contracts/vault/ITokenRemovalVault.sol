// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface ITokenRemovalVault {
  /**
   * @notice Initializes the TokenRemovalVault contract.
   * @dev This function is called only once during the deployment of the contract.
   */
  function init() external;

  /**
   * @notice Withdraws a specified amount of tokens to a specified address.
   * @dev This function can only be called by the owner of the contract.
   * @param _token The address of the token to withdraw.
   * @param _to The address to which the tokens will be sent.
   * @param _amount The amount of tokens to withdraw.
   */
  function withdrawTokens(
    address _token,
    address _to,
    uint256 _amount
  ) external;
}
