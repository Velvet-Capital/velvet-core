// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// Importing the ErrorLibrary for standardized error handling across the contract system.
import {ErrorLibrary} from "../../library/ErrorLibrary.sol";

/**
 * @title OwnableCheck
 * @dev Provides a flexible and overrideable mechanism for ownership verification across the contract system.
 * This abstract contract defines a basic ownership check structure that can be adapted to fit various ownership models.
 * It is designed to work in conjunction with a more comprehensive ownership management system.
 */
abstract contract OwnableCheck {
  /**
   * @notice Modifier to restrict function access to the contract's owner.
   * Utilizes the `_isOwner` function to check caller's ownership status.
   * @dev Reverts with a standardized error if called by any account other than the owner.
   */
  modifier onlyProtocolOwner() {
    if (!_isOwner()) revert ErrorLibrary.CallerNotOwner();
    _; // Continues execution for the owner
  }

  function _owner() internal virtual returns (address);

  /**
   * @dev Abstract function to determine if the current caller is the owner.
   * This function must be implemented by inheriting contracts to define specific ownership logic.
   * @return bool Returns true if the current caller is the owner, otherwise false.
   */
  function _isOwner() internal virtual returns (bool);
}
