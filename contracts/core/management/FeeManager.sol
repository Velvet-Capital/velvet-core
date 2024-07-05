// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// Import the IFeeModule interface to interact with the fee module.
import {IFeeModule} from "../../fee/IFeeModule.sol";

// Import AccessModifiers to utilize role-based access control.
import {AccessModifiers} from "../access/AccessModifiers.sol";

// Import Dependencies to access configurations and modules.
import {Dependencies} from "../config/Dependencies.sol";

/**
 * @title FeeManager
 * @dev Extends AccessModifiers and Dependencies to manage and execute fee-related operations within the platform.
 * Provides functionality to charge management and protocol fees, ensuring that fee operations are handled
 * securely and in accordance with platform rules.
 */
abstract contract FeeManager is AccessModifiers, Dependencies {
  /**
   * @notice Charges applicable fees by calling the fee module.
   * @dev Calls the `_chargeProtocolAndManagementFees` function of the fee module. Charges are only applied
   * if the caller is not the asset manager treasury or the protocol treasury, preventing unnecessary fee deduction
   * during internal operations.
   * This design ensures that fees are dynamically managed based on the transaction context and are only deducted
   * when appropriate, maintaining platform efficiency.
   */
  function _chargeFees(address _user) internal {
    // Check if the sender is not a treasury account to avoid charging fees on internal transfers.
    if (
      !(_user == assetManagementConfig().assetManagerTreasury() ||
        _user == protocolConfig().velvetTreasury())
    ) {
      // Invoke the fee module to charge both protocol and management fees.
      feeModule().chargeProtocolAndManagementFeesProtocol();
    }
  }
}
