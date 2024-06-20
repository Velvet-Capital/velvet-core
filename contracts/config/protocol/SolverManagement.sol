// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";

import {OwnableCheck} from "./OwnableCheck.sol";

/**
 * @title SolverManagement
 * @notice Manages solver handlers, enabling or disabling them as needed for platform operations.
 * Solvers play a crucial role in executing complex operations and strategies on the platform.
 */
abstract contract SolverManagement is OwnableCheck {
  mapping(address => bool) public solverHandler;

  event SolverHandlerEnabled(address indexed handler);
  event SolverHandlerDisabled(address indexed handler);

  /**
   * @notice This function returns a bool according to given input is an solverpHandler or not
   * @param _handler Address of the external swap handler to be checked
   * @return Boolean parameter for is the external swap handler enabled or not
   */
  function isSolver(address _handler) external view virtual returns (bool) {
    return solverHandler[_handler];
  }

  /**
   * @notice Enables a solver handler by setting its address to true in the mapping.
   * @dev This function can only be called by the protocol owner.
   * @param _handler The address of the solver handler to enable.
   * @dev Reverts if the provided handler address is invalid (address(0)).
   */
  function enableSolverHandler(address _handler) external onlyProtocolOwner {
    if (_handler == address(0)) revert ErrorLibrary.InvalidAddress();
    solverHandler[_handler] = true;
    emit SolverHandlerEnabled(_handler);
  }

  /**
   * @notice This function disables the externalSolverHandler input
   * @param _handler Address of the external swap handler to be disabled in the registry
   */
  function disableSolverHandler(
    address _handler
  ) external virtual onlyProtocolOwner {
    if (_handler == address(0)) revert ErrorLibrary.InvalidAddress();

    solverHandler[_handler] = false;
    emit SolverHandlerDisabled(_handler);
  }
}
