// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import {IAllowanceTransfer} from "../core/interfaces/IAllowanceTransfer.sol";
import {ErrorLibrary} from "../library/ErrorLibrary.sol";
import {IPortfolio} from "../core/interfaces/IPortfolio.sol";
import {FunctionParameters} from "../FunctionParameters.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/**
 * @title BatchHandler
 * @dev This contract facilitates batching multiple transactions for users, providing a seamless experience.
 * It swaps the user's single token (chosen by the user) to vault tokens of a portfolio using Enso and deposits
 * the tokens into the portfolio, issuing the user portfolio tokens. If the token to swap is the same as a portfolio token,
 * the user's amount is simply passed as calldata. Finally, any leftover dust is returned to the user.
 */
contract DepositBatch is ReentrancyGuard {
  // The address of Enso's swap execution logic; swaps are delegated to this target.
  address constant SWAP_TARGET = 0x38147794FF247e5Fc179eDbAE6C37fff88f68C52;

  /**
   * @notice Performs a multi-token swap and deposit operation for the user.
   * @param data Struct containing parameters for the batch handler.
   */
  function multiTokenSwapAndTransfer(
    FunctionParameters.BatchHandler memory data
  ) external payable nonReentrant{
    address[] memory tokens = IPortfolio(data._target).getTokens();
    uint256 tokenLength = tokens.length;
    uint256[] memory depositAmounts = new uint256[](tokenLength);
    address user = msg.sender;
    address _depositToken = data._depositToken;

    if (data._callData.length != tokenLength)
      revert ErrorLibrary.InvalidLength();

    // Transfer tokens from user if no ETH is sent
    if (msg.value == 0) {
      TransferHelper.safeTransferFrom(
        _depositToken,
        user,
        address(this),
        data._depositAmount
      );
    }

    // Perform swaps and calculate deposit amounts for each token
    for (uint256 i; i < tokenLength; i++) {
      address _token = tokens[i];
      uint256 balance;
      if (_token == _depositToken) {
        //Sending encoded balance instead of swap calldata
        balance = abi.decode(data._callData[i], (uint256));
      } else {
        (bool success, ) = SWAP_TARGET.delegatecall(data._callData[i]);
        if (!success) revert ErrorLibrary.CallFailed();
        balance = _getTokenBalance(_token, address(this));
      }
      if (balance == 0) revert ErrorLibrary.InvalidBalanceDiff();
      IERC20(_token).approve(data._target, balance);
      depositAmounts[i] = balance;
    }

    IPortfolio(data._target).multiTokenDepositFor(
      user,
      depositAmounts,
      data._minMintAmount
    );

    //Return any leftover vault token dust to the user
    for (uint256 i; i < tokenLength; i++) {
      address _token = tokens[i];
      TransferHelper.safeTransfer(
        _token,
        user,
        _getTokenBalance(_token, address(this))
      );
    }

    // Return any leftover invested token dust to the user
    if (msg.value == 0) {
      TransferHelper.safeTransfer(
        _depositToken,
        user,
        _getTokenBalance(_depositToken, address(this))
      );
    } else {
      (bool sent, ) = user.call{value: address(this).balance}("");
      if (!sent) revert ErrorLibrary.TransferFailed();
    }
  }

  /**
   * @notice Helper function to get balance of any token for any user.
   * @param _token Address of token to get balance.
   * @param _of Address of user to get balance of.
   * @return uint256 Balance of the specified token for the user.
   */
  function _getTokenBalance(
    address _token,
    address _of
  ) internal view returns (uint256) {
    return IERC20(_token).balanceOf(_of);
  }

  // Function to receive Ether when msg.data is empty
  receive() external payable {}
}
