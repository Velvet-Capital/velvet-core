// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ITokenExclusionManager} from "../../../../core/interfaces/ITokenExclusionManager.sol";

/**
 * @title UserManagement
 * @dev Provides functionalities related to managing user-specific states within the platform,
 * such as tracking deposit times and managing withdrawal cooldown periods. This contract
 * interacts with the TokenExclusionManager to update user records during deposit and
 * withdrawal operations.
 */
contract UserManagementV3_2 {
  // Mapping to track the last time a user made an deposit. This is used to enforce any cooldowns or restrictions on new deposits.
  mapping(address => uint256) public _lastDepositTime;

  // Mapping to track the cooldown period after a user makes a withdrawal. This is used to restrict the frequency of withdrawals.
  mapping(address => uint256) public _lastWithdrawCooldown;

  // Reference to the TokenExclusionManager contract which manages token-specific rules and user records related to deposits and withdrawals.
  ITokenExclusionManager public tokenExclusionManager;

  address internal _addedAddressVar;

  uint256[9] internal _addedList;

  /**
   * @dev Initializes the UserManagement contract with a reference to the TokenExclusionManager contract.
   * @param _tokenExclusionManager The address of the TokenExclusionManager contract.
   */
  function __UserManagement_init(address _tokenExclusionManager) internal {
    tokenExclusionManager = ITokenExclusionManager(_tokenExclusionManager);
  }

  /**
   * @dev Updates the user's record in the TokenExclusionManager. This includes the user's current balance
   * after an deposit or withdrawal operation has occurred.
   * @param _user The address of the user whose record is being updated.
   * @param _userBalance The new balance of the user after the operation.
   */
  function _updateUserRecord(address _user, uint256 _userBalance) internal {
    tokenExclusionManager.setUserRecord(_user, _userBalance);
  }

  // Reserved storage gap to accommodate potential future layout adjustments.
  uint256[39] internal __uint256GapUserManagement;
}
