// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface IWithdrawBatch {
  function multiTokenSwapAndWithdraw(
    address _target,
    address _tokenToWithdraw,
    address user,
    uint256 _expectedOutputAmount,
    bytes[] memory _callData
  ) external;
}
