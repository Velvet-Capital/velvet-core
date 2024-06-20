// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {IERC20 as IERC20Base} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC20 is IERC20Base, IERC20Metadata {
  function mint(address to, uint256 amount) external;
}
