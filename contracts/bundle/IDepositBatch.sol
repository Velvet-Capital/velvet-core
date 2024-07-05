// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {FunctionParameters} from "../FunctionParameters.sol";

interface IDepositBatch {
  function multiTokenSwapAndDeposit(
    FunctionParameters.BatchHandler memory data,
    address user
  ) external;
}
