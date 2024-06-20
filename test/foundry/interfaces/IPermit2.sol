// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../../../../contracts/core/interfaces/IAllowanceTransfer.sol";

interface IPermit2 is IAllowanceTransfer {
  //function DOMAIN_SEPARATOR() external returns (bytes32);

  function permit(
    address owner,
    PermitBatch memory permitBatch,
    bytes calldata signature
  ) external;
}
