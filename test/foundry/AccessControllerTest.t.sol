// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {AccessController} from "../../contracts/access/AccessController.sol";

contract AccessControllerTest is Test {
  AccessController accessController;

  function setUp() public {
    accessController = new AccessController();
    // Additional setup if necessary
  }

  function testRoleManagement() public {
    // Example: test adding a role and checking it
    address testUser = address(0x123);
    bytes32 DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");

    // Ensure testUser does not have DEFAULT_ADMIN_ROLE initially
    assertFalse(
      accessController.hasRole(DEFAULT_ADMIN_ROLE, testUser),
      "User should not have role initially"
    );

    // Give testUser the DEFAULT_ADMIN_ROLE
    accessController.grantRole(DEFAULT_ADMIN_ROLE, testUser);

    // Assert testUser now has DEFAULT_ADMIN_ROLE
    assertTrue(
      accessController.hasRole(DEFAULT_ADMIN_ROLE, testUser),
      "User should have role after grant"
    );
  }
}
