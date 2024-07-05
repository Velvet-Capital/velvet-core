// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

contract MockAccessController {
  // Implement minimal functionality required for your tests
  function hasRole(bytes32, address) external view returns (bool) {
    return true; // Simplified implementation
  }
}
