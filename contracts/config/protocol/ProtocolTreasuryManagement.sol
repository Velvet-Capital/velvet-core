// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";

import {OwnableCheck} from "./OwnableCheck.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

/**
 * @title TreasuryManagement
 * @notice Manages the treasury's address, facilitating updates to the treasury location.
 * This is crucial for directing fees and other financial transactions.
 */
abstract contract ProtocolTreasuryManagement is OwnableCheck, Initializable {
  address public velvetTreasury;

  event TreasuryUpdated(address indexed newTreasury);

  /**
   * @dev Initializes the contract by setting the initial treasury address.
   * @param _velvetTreasury Initial address of the velvet' treasury.
   */
  function __TreasuryManagement_init(
    address _velvetTreasury
  ) internal onlyInitializing {
    // Ensures the treasury address is not the zero address.
    _updateVelvetTreasury(_velvetTreasury);
  }

  /**
   * @dev Updates the address of the treasury.
   * @param _newVelvetTreasury New address for the treasury.
   */
  function updateVelvetTreasury(
    address _newVelvetTreasury
  ) external onlyProtocolOwner {
    _updateVelvetTreasury(_newVelvetTreasury);
    emit TreasuryUpdated(_newVelvetTreasury);
  }

  function _updateVelvetTreasury(address _newTreasury) internal {
    if (_newTreasury == address(0))
      revert ErrorLibrary.ZeroAddressTreasury();
    if(_newTreasury == velvetTreasury)
      revert ErrorLibrary.PreviousTreasuryAddress();

    velvetTreasury = _newTreasury;
  }
}
