// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {Portfolio} from "../../core/Portfolio.sol";

/**
 * @title PortfolioV3_3
 * @author Velvet.Capital
 * @notice Maintains the existing portfolio functionality while extending the contract with new variables at the storage's end.
 * @dev This version preserves the core portfolio functionality and introduces additional variables at the end of the storage structure.
 *      This approach allows for the introduction of new features without disrupting existing storage layout, ensuring a seamless upgrade process.
 */
contract PortfolioV3_3 is Portfolio {
  uint256 _addedVariable;
  address _newAddedAddress;
}
