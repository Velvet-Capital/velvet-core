// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

/**
 * @title IProtocolConfig
 * @notice Interface for the protocol configuration contract, managing various system settings and functionalities.
 */
interface IProtocolConfig {
  // ----- OracleManagement Functions -----

  /**
   * @notice Updates the address of the price oracle.
   * @param _newOracle The address of the new price oracle.
   */
  function updatePriceOracle(address _newOracle) external;

  /**
   * @notice Returns the address of the current price oracle.
   * @return The address of the current price oracle.
   */
  function oracle() external view returns (address);

  // ----- TreasuryManagement Functions -----

  /**
   * @notice Updates the address of the Velvet treasury.
   * @param _newVelvetTreasury The address of the new Velvet treasury.
   */
  function updateVelvetTreasury(address _newVelvetTreasury) external;

  /**
   * @notice Returns the address of the Velvet treasury.
   * @return The address of the Velvet treasury.
   */
  function velvetTreasury() external view returns (address);

  // ----- SystemSettings Functions -----

  /**
   * @notice Returns the cooldown period for certain protocol operations.
   * @return The cooldown period.
   */
  function cooldownPeriod() external view returns (uint256);

  /**
   * @notice Returns the asset limit for the protocol.
   * @return The asset limit.
   */
  function assetLimit() external view returns (uint256);

  /**
   * @notice Returns the minimum initial portfolio amount.
   * @return The minimum initial portfolio amount.
   */
  function minInitialPortfolioAmount() external view returns (uint256);

  /**
   * @notice Returns the minimum portfolio token holding amount.
   * @return The minimum portfolio token holding amount.
   */
  function minPortfolioTokenHoldingAmount() external view returns (uint256);

  /**
   * @notice Returns whether the protocol is currently paused.
   * @return True if the protocol is paused, false otherwise.
   */
  function isProtocolPaused() external view returns (bool);

  /**
   * @notice Returns whether the protocol is currently in an emergency paused state.
   * @return True if the protocol is in an emergency paused state, false otherwise.
   */
  function isProtocolEmergencyPaused() external view returns (bool);

  /**
   * @notice Sets a new cooldown period for certain protocol operations.
   * @param _newCooldownPeriod The new cooldown period.
   */
  function setCoolDownPeriod(uint256 _newCooldownPeriod) external;

  /**
   * @notice Sets a new asset limit for the protocol.
   * @param _newLimit The new asset limit.
   */
  function setAssetLimit(uint256 _newLimit) external;

  /**
   * @notice Sets the pause state of the protocol.
   * @param _paused The new pause state.
   */
  function setProtocolPause(bool _paused) external;

  /**
   * @notice Sets the emergency pause state of the protocol.
   * @param _paused The new emergency pause state.
   */
  function setEmergencyPause(bool _paused) external;

  // ----- TokenManagement Functions -----

  /**
   * @notice Enables a list of tokens for the protocol.
   * @param _tokens The list of token addresses to enable.
   */
  function enableTokens(address[] calldata _tokens) external;

  /**
   * @notice Disables a specific token for the protocol.
   * @param _token The address of the token to disable.
   */
  function disableToken(address _token) external;

  /**
   * @notice Checks if a specific token is enabled.
   * @param _token The address of the token to check.
   * @return True if the token is enabled, false otherwise.
   */
  function isTokenEnabled(address _token) external view returns (bool);

  // ----- FeeManagement Functions -----

  /**
   * @notice Updates the protocol fee.
   * @param _newProtocolFee The new protocol fee.
   */
  function updateProtocolFee(uint256 _newProtocolFee) external;

  /**
   * @notice Updates the protocol streaming fee.
   * @param _newProtocolStreamingFee The new protocol streaming fee.
   */
  function updateProtocolStreamingFee(
    uint256 _newProtocolStreamingFee
  ) external;

  /**
   * @notice Returns the maximum management fee.
   * @return The maximum management fee.
   */
  function maxManagementFee() external view returns (uint256);

  /**
   * @notice Returns the maximum performance fee.
   * @return The maximum performance fee.
   */
  function maxPerformanceFee() external view returns (uint256);

  /**
   * @notice Returns the maximum entry fee.
   * @return The maximum entry fee.
   */
  function maxEntryFee() external view returns (uint256);

  /**
   * @notice Returns the maximum exit fee.
   * @return The maximum exit fee.
   */
  function maxExitFee() external view returns (uint256);

  /**
   * @notice Returns the protocol fee.
   * @return The protocol fee.
   */
  function protocolFee() external view returns (uint256);

  /**
   * @notice Returns the protocol streaming fee.
   * @return The protocol streaming fee.
   */
  function protocolStreamingFee() external view returns (uint256);

  // ----- SolverManagement Functions -----

  /**
   * @notice Checks if a specific address is a solver.
   * @param _handler The address to check.
   * @return True if the address is a solver, false otherwise.
   */
  function isSolver(address _handler) external view returns (bool);

  /**
   * @notice Enables a solver handler.
   * @param _handler The address of the solver handler to enable.
   */
  function enableSolverHandler(address _handler) external;

  /**
   * @notice Disables a solver handler.
   * @param _handler The address of the solver handler to disable.
   */
  function disableSolverHandler(address _handler) external;

  /**
   * @notice Checks if a specific solver handler is enabled.
   * @param _handler The address to check.
   * @return True if the solver handler is enabled, false otherwise.
   */
  function isSolverHandlerEnabled(
    address _handler
  ) external view returns (bool);

  function whitelistLimit() external view returns (uint256);

  function allowedDustTolerance() external view returns (uint256);

  // ----- RewardTargetManagement Functions -----
  /**
   * @notice Checks if a reward target address is enabled.
   * @param _rewardTargetAddress The address of the reward target to check.
   * @return Boolean indicating if the reward target address is enabled.
   */
  function isRewardTargetEnabled(
    address _rewardTargetAddress
  ) external view returns (bool);

  /**
   * @notice Enables a reward target address by setting its status to true in the mapping.
   * @dev This function can only be called by the protocol owner.
   * @param _rewardTargetAddress The address of the reward target to enable.
   * @dev Reverts if the provided address is invalid (address(0)).
   */
  function enableRewardTarget(address _rewardTargetAddress) external;

  /**
   * @notice Disables a reward target address by setting its status to false in the mapping.
   * @dev This function can only be called by the protocol owner.
   * @param _rewardTargetAddress The address of the reward target to disable.
   * @dev Reverts if the provided address is invalid (address(0)).
   */
  function disableRewardTarget(address _rewardTargetAddress) external;
}
