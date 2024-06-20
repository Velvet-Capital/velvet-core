// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {AssetManagerCheck} from "./AssetManagerCheck.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

/**
 * @title TreasuryManagement
 * @dev Manages the treasury address for the asset management system, allowing for updates to the treasury.
 * This enables redirection of financial flows, such as fees, to the specified treasury address,
 * and is essential for financial management within the system.
 */
abstract contract TreasuryManagement is AssetManagerCheck, Initializable {
  // Public variable holding the address of the treasury.
  address public assetManagerTreasury;

  // Event emitted when the treasury address is updated.
  event TreasuryUpdated(address indexed newTreasury);

  /**
   * @dev Initializes the contract by setting the initial treasury address.
   * @param _assetManagerTreasury Initial address of the asset manager's treasury.
   */
  function __TreasuryManagement_init(
    address _assetManagerTreasury
  ) internal onlyInitializing {
    // Ensures the treasury address is not the zero address.
    if (_assetManagerTreasury == address(0))
      revert ErrorLibrary.ZeroAddressTreasury();

    assetManagerTreasury = _assetManagerTreasury;
  }

  /**
   * @notice Updates the address of the asset manager's treasury.
   * @dev Can only be called by an asset manager.
   * @param _newAssetManagerTreasury The new address for the asset manager's treasury.
   */
  function updateAssetManagerTreasury(
    address _newAssetManagerTreasury
  ) external onlyAssetManager {
    // Checks that the new treasury address is not the zero address.
    if (_newAssetManagerTreasury == address(0))
      revert ErrorLibrary.InvalidAddress();

    // Updates the treasury address and emits an event with the new address.
    assetManagerTreasury = _newAssetManagerTreasury;
    emit TreasuryUpdated(_newAssetManagerTreasury);
  }
}
