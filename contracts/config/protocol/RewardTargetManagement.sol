// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {OwnableCheck} from "./OwnableCheck.sol";

/**
 * @title RewardTargetManagement
 * @notice Manages reward claim target addresses, enabling or disabling them as needed for platform operations.
 * These addresses play a crucial role in claiming rewards from different sources on the platform.
 */
abstract contract RewardTargetManagement is OwnableCheck {
  mapping(address => bool) public enabledRewardTargetAddress;

  event RewardTargetEnabled(address indexed rewardTargetAddress);
  event RewardTargetDisabled(address indexed rewardTargetAddress);
  event RewardTargetsEnabled(address[] rewardTargetAddresses);

  /**
   * @notice Checks if a reward target address is enabled.
   * @param _rewardTargetAddress The address of the reward target to check.
   * @return Boolean indicating if the reward target address is enabled.
   */
  function isRewardTargetEnabled(
    address _rewardTargetAddress
  ) external view virtual returns (bool) {
    return enabledRewardTargetAddress[_rewardTargetAddress];
  }

  /**
   * @notice Internal function to enable a reward target address.
   * @param _rewardTargetAddress The address of the reward target to enable.
   * @dev This function can only be called by the protocol owner.
   * @dev Reverts if the provided address is invalid (address(0)).
   */
  function _enableRewardTarget(
    address _rewardTargetAddress
  ) internal onlyProtocolOwner {
    if (_rewardTargetAddress == address(0))
      revert ErrorLibrary.InvalidAddress();
    enabledRewardTargetAddress[_rewardTargetAddress] = true;
  }

  /**
   * @notice Enables a reward target address by setting its status to true in the mapping.
   * @param _rewardTargetAddress The address of the reward target to enable.
   * @dev This function can only be called by the protocol owner.
   * @dev Reverts if the provided address is invalid (address(0)).
   */
  function enableRewardTarget(
    address _rewardTargetAddress
  ) external onlyProtocolOwner {
    _enableRewardTarget(_rewardTargetAddress);
    emit RewardTargetEnabled(_rewardTargetAddress);
  }

  /**
   * @notice Enables multiple reward target addresses by setting their status to true in the mapping.
   * @param _rewardTargetAddresses The addresses of the reward targets to enable.
   * @dev This function can only be called by the protocol owner.
   * @dev Reverts if the provided address array is empty.
   */
  function enableRewardTargets(
    address[] calldata _rewardTargetAddresses
  ) external onlyProtocolOwner {
    uint256 rewardTargetLength = _rewardTargetAddresses.length;
    if (rewardTargetLength == 0) revert ErrorLibrary.InvalidLength();
    for (uint256 i; i < rewardTargetLength; i++) {
      _enableRewardTarget(_rewardTargetAddresses[i]);
    }

    emit RewardTargetsEnabled(_rewardTargetAddresses);
  }

  /**
   * @notice Disables a reward target address by setting its status to false in the mapping.
   * @param _rewardTargetAddress The address of the reward target to disable.
   * @dev This function can only be called by the protocol owner.
   * @dev Reverts if the provided address is invalid (address(0)).
   */
  function disableRewardTarget(
    address _rewardTargetAddress
  ) external virtual onlyProtocolOwner {
    if (_rewardTargetAddress == address(0))
      revert ErrorLibrary.InvalidAddress();

    enabledRewardTargetAddress[_rewardTargetAddress] = false;
    emit RewardTargetDisabled(_rewardTargetAddress);
  }
}
