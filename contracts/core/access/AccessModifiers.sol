// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {IAccessController} from "../../access/IAccessController.sol";
import {AccessRoles} from "../../access/AccessRoles.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

/**
 * @title AccessModifiers
 * @dev Provides role-based access control modifiers to restrict function execution to specific roles.
 * This abstract contract extends AccessRoles to utilize predefined role constants.
 * It is designed to be inherited by other contracts that require role-based permissions.
 */
abstract contract AccessModifiers is AccessRoles, Initializable {
  // The access controller contract instance for role verification.
  IAccessController public accessController;

  /**
   * @dev Modifier to restrict function access to only the super admin role.
   * Reverts with CallerNotSuperAdmin error if the caller does not have the SUPER_ADMIN role.
   */
  modifier onlySuperAdmin() {
    if (!_checkRole(SUPER_ADMIN, msg.sender)) {
      revert ErrorLibrary.CallerNotSuperAdmin();
    }
    _;
  }

  /**
   * @dev Modifier to restrict function access to only the rebalancer contract.
   * Reverts with CallerNotRebalancerContract error if the caller does not have the REBALANCER_CONTRACT role.
   */
  modifier onlyRebalancerContract() {
    if (!_checkRole(REBALANCER_CONTRACT, msg.sender)) {
      revert ErrorLibrary.CallerNotRebalancerContract();
    }
    _;
  }

  /**
   * @dev Modifier to restrict function access to only entities with the minter role.
   * Reverts with CallerNotPortfolioManager error if the caller does not have the MINTER_ROLE.
   */
  modifier onlyMinter() {
    if (!_checkRole(MINTER_ROLE, msg.sender)) {
      revert ErrorLibrary.CallerNotPortfolioManager();
    }
    _;
  }

  /**
   * @dev Initializes the contract by setting the access controller address.
   * @param _accessController Address of the AccessController contract responsible for role management.
   */
  function __AccessModifiers_init(
    address _accessController
  ) internal onlyInitializing {
    if (_accessController == address(0)) revert ErrorLibrary.InvalidAddress();
    accessController = IAccessController(_accessController);
  }

  /**
   * @notice Checks if a user has a specific role.
   * @param _role The role identifier to check.
   * @param _user The address of the user to check for the role.
   * @return A boolean indicating whether the user has the specified role.
   */
  function _checkRole(
    bytes32 _role,
    address _user
  ) private view returns (bool) {
    return accessController.hasRole(_role, _user);
  }
}
