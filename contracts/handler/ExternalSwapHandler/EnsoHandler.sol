// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import { SafeERC20Upgradeable, IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable-4.9.6/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { TransferHelper } from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import { ErrorLibrary } from "../../library/ErrorLibrary.sol";
import { IIntentHandler } from "../IIntentHandler.sol";

/**
 * @title EnsoHandler
 * @dev This contract is designed to interface with the Enso platform, facilitating
 * the execution of token swaps and the subsequent transfer of swap outputs. It leverages
 * delegatecall for swap execution, allowing for the integration of complex swap operations
 * and strategies specific to the Enso ecosystem. Additionally, it includes mechanisms for
 * the secure handling of token transfers, including adherence to minimum expected output
 * thresholds for swap operations.
 */
contract EnsoHandler is IIntentHandler {
  // The address of Enso's swap execution logic; swaps are delegated to this target.
  address constant SWAP_TARGET = 0x38147794FF247e5Fc179eDbAE6C37fff88f68C52;

  /**
   * @notice Conducts a token swap operation via the Enso platform and transfers the output tokens
   * to a specified recipient address.
   * @param _to The address designated to receive the output tokens from the swap.
   * @param _callData Encoded bundle containing the swap operation data, structured as follows:
   *        - callDataEnso: Array of bytes representing the encoded data for each swap operation,
   *          allowing for direct interaction with Enso's swap logic.
   *        - tokens: Array of token addresses involved in the swap operations.
   *        - minExpectedOutputAmounts: Array of minimum acceptable output amounts for the tokens
   *          received from each swap operation, ensuring the swap meets the user's expectations.
   * @return _swapReturns Array containing the actual amounts of tokens received from each swap operation.
   */
  function multiTokenSwapAndTransfer(
    address _to,
    bytes memory _callData
  ) external override returns (address[] memory) {
    (
      bytes[] memory callDataEnso,
      address[] memory tokens,
      uint256[] memory minExpectedOutputAmounts
    ) = abi.decode(_callData, (bytes[], address[], uint256[]));

    // Validate lengths of input arrays for consistency.
    uint256 tokensLength = tokens.length;

    if (
      tokensLength != minExpectedOutputAmounts.length ||
      tokensLength != callDataEnso.length
    ) revert ErrorLibrary.InvalidLength();

    // Ensure the recipient address is valid.
    if (_to == address(0)) revert ErrorLibrary.InvalidAddress();

    for (uint256 i; i < tokensLength; i++) {
      address token = tokens[i]; // Optimize gas by caching the token address.
      uint256 buyBalanceBefore = IERC20Upgradeable(token).balanceOf(
        address(this)
      );

      // Perform delegatecall to execute swap operation on the Enso platform.
      (bool success, ) = SWAP_TARGET.delegatecall(callDataEnso[i]);
      if (!success) revert ErrorLibrary.CallFailed();

      // Post-swap processing: verify output against minimum expectations and transfer to recipient.
      uint256 buyBalanceAfter = IERC20Upgradeable(token).balanceOf(
        address(this)
      );
      uint256 swapReturn = buyBalanceAfter - buyBalanceBefore;

      if (swapReturn == 0 || swapReturn < minExpectedOutputAmounts[i])
        revert ErrorLibrary.ReturnValueLessThenExpected();

      TransferHelper.safeTransfer(token, _to, swapReturn);
    }

    return tokens;
  }

  // Function to receive Ether when msg.data is empty
  receive() external payable {}
}
