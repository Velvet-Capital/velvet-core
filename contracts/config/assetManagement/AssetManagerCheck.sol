// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// Importing the ErrorLibrary for standardized error handling across the contract system.
import {ErrorLibrary} from "../../library/ErrorLibrary.sol";

/**
 * @title AssetManagerCheck
 * @dev Provides a mechanism for asset manager verification across the contract system.
 * This abstract contract outlines a basic structure for asset manager checks that can be adapted
 * to various authorization models. It's intended to ensure that only asset managers can
 * access certain functions, enhancing the security and operational integrity of the system.
 */
abstract contract AssetManagerCheck {

   /**
   * @notice Modifier to restrict function access to asset managers.
   * Uses the `_isAssetManager` function to determine the caller's authorization status.
   * @dev Reverts with a CallerNotAssetManager error if the caller does not have asset manager privileges.
   */
  modifier onlyAssetManager() {
    if (!_isAssetManager()) revert ErrorLibrary.CallerNotAssetManager();
    _; // Continues function execution if the caller is an asset manager
  }

  modifier onlyWhitelistManager() {
    if (!_isWhitelistManager()) revert ErrorLibrary.CallerNotWhitelistManager();
    _; // Continues function execution if the caller is an whitelist manager
  }

  /**
   * @dev Abstract function to verify if the current caller is an asset manager.
   * Implementing contracts must override this function to define their specific logic
   * for verifying asset manager status.
   * @return bool Returns true if the current caller is an asset manager, otherwise false.
   */
  function _isAssetManager() internal virtual returns (bool);

  function _isWhitelistManager() internal virtual returns (bool);
}
