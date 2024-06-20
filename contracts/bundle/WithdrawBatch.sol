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
 * @title WithdrawHandler
 * @dev This contract facilitates batching multiple transactions for users, providing a seamless experience.
 * It withdraws users vault token to contract and swaps multiple tokens to single token (chosen by user) using enso and send it to user,
 * if token to swap into is the same as users desired token then it simply transfers the token balance of contract. Finally, any leftover
 * dust is also returned to the user
 */
contract WithdrawBatch is ReentrancyGuard {
  // The address of Enso's swap execution logic; swaps are delegated to this target.
  address constant SWAP_TARGET = 0x38147794FF247e5Fc179eDbAE6C37fff88f68C52;
  address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /**
   * @notice Performs a multi-token withdrawal and swap operation for the user.
   * @param _target Adress of portfolio contract to withdraw from
   * @param _tokenToWithdraw Address of token user needs(will receive)
   * @param _portfolioTokenAmount The amount of portfolio tokens to withdraw
   * @param _callData Encoded call data for swap operation
   */
  function multiTokenSwapAndWithdraw(
    address _target,
    address _tokenToWithdraw,
    uint256 _portfolioTokenAmount,
    bytes[] memory _callData
  ) external nonReentrant {
    address[] memory tokens = IPortfolio(_target).getTokens();
    uint256 tokenLength = tokens.length;
    address user = msg.sender;
    uint256 balanceOfSameToken;

    if (_callData.length != tokenLength) revert ErrorLibrary.InvalidLength();

    uint256 userBalanceBeforeSwap = _getTokenBalanceOfUser(_tokenToWithdraw, user);

    IPortfolio(_target).multiTokenWithdrawalFor(
      user,
      address(this),
      _portfolioTokenAmount
    );

    // Perform swaps and send tokens to user
    for (uint256 i = 0; i < tokenLength; i++) {
      address _token = tokens[i];
      if (_tokenToWithdraw == _token) {
        //Balance transferred to user directly
        balanceOfSameToken = _getTokenBalance(_token, address(this));
        TransferHelper.safeTransfer(_token, user, balanceOfSameToken);
      } else {
        (bool success, ) = SWAP_TARGET.delegatecall(_callData[i]);
        if (!success) revert ErrorLibrary.CallFailed();

        // Return any leftover dust to the user
        TransferHelper.safeTransfer(
          _token,
          user,
          _getTokenBalance(_token, address(this))
        );
      }
    }

    // Subtracting balanceIfSameToken to get the correct amount, to verify that calldata is not manipulated, 
    // and to ensure the user has received their shares properly
    uint256 userBalanceAfterSwap = _getTokenBalanceOfUser(_tokenToWithdraw, user) -
      balanceOfSameToken;

    //Checking balance of user after swap, to confirm recevier is user
    if (userBalanceAfterSwap <= userBalanceBeforeSwap)
      revert ErrorLibrary.InvalidBalanceDiff();
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

  /**
   * @notice Helper function to get balance of any token for any user.
   * @param _token Address of token to get balance.
   * @param _user Address of user to get balance of.
   * @return balance Balance of the specified token for the user.
   */
  function _getTokenBalanceOfUser(
    address _token,
    address _user
  ) internal view returns (uint256 balance) {
    if (_token == ETH_ADDRESS) {
      balance = _user.balance;
    } else {
      balance = _getTokenBalance(_token, _user);
    }
  }

  // Function to receive Ether when msg.data is empty
  receive() external payable {}
}
