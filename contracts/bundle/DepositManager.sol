// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import {FunctionParameters} from "../FunctionParameters.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IDepositBatch} from "./IDepositBatch.sol";

/**
 * @title DepositManager
 * @notice Manages deposits of tokens into the contract and handles multi-token swaps and transfers.
 * @dev This contract utilizes a DEPOSIT_BATCH contract to perform multi-token swaps and transfers. It inherits from ReentrancyGuard to prevent reentrant calls.
 */
contract DepositManager is ReentrancyGuard {
  /// @notice The DEPOSIT_BATCH contract that handles the multi-token swap and transfer logic.
  IDepositBatch immutable DEPOSIT_BATCH;

  /**
   * @notice Constructs the DepositManager contract.
   * @param _depositBatch The address of the DEPOSIT_BATCH contract.
   */
  constructor(address _depositBatch) {
    DEPOSIT_BATCH = IDepositBatch(_depositBatch);
  }

  /**
   * @notice Deposits a specified amount of tokens into the contract and executes a multi-token swap and transfer.
   * @dev Transfers the specified deposit amount from the user to the DEPOSIT_BATCH contract, then calls the multiTokenSwapAndTransfer function.
   * @param data A struct containing the following parameters:
   * - _depositToken: The address of the token to be deposited.
   * - _depositAmount: The amount of the token to be deposited.
   * - Other necessary parameters required by the multiTokenSwapAndTransfer function.
   */
  function deposit(
    FunctionParameters.BatchHandler memory data
  ) external nonReentrant {
    address _depositToken = data._depositToken;
    address user = msg.sender;

    TransferHelper.safeTransferFrom(
      _depositToken,
      user,
      address(DEPOSIT_BATCH),
      data._depositAmount
    );

    DEPOSIT_BATCH.multiTokenSwapAndDeposit(data, user);
  }
}
