// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";

import {MathUtils} from "../calculations/MathUtils.sol";

/**
 * @title CooldownManager
 * @dev Manages cooldown periods for depositors to impose restrictions on rapid deposit and withdrawal actions.
 * This contract tracks the timestamps of users' last deposits and applies cooldown periods to mitigate
 * the risks associated with quick, speculative trading, and to ensure the stability of the fund.
 */
contract CooldownManager {
  // Maps an address to its last deposit timestamp to enforce cooldown periods.
  mapping(address => uint256) public userLastDepositTime;
  // Maps an address to its last withdrawal cooldown timestamp to enforce withdrawal restrictions.
  mapping(address => uint256) public userCooldownPeriod;

  /**
   * @dev Calculates the cooldown period to be applied to an depositor after making a deposit.
   * The cooldown mechanism is designed to discourage immediate withdrawals after deposits, encouraging longer-term deposit by imposing a waiting period.
   *
   * @param _currentUserBalance The current balance of the depositor's tokens in the pool, representing their share of the deposit.
   * @param _mintedLiquidity The amount of liquidity (in terms of pool tokens) that will be minted for the depositor as a result of the deposit.
   * @param _defaultCooldownTime  The predefined cooldown duration set by the protocol, representing the minimum time an depositor must wait before making a withdrawal.
   * @param _oldCooldownTime The cooldown time previously applied to the depositor, factoring in any past deposits.
   * @param _lastDepositTimestamp The timestamp of the depositor's last deposit, used to calculate the remaining cooldown time.
   * @return cooldown The new cooldown time to be applied to the depositor's account, calculated based on their current and newly minted balances, as well as the protocol's cooldown settings.
   */
  function _calculateCooldownPeriod(
    uint256 _currentUserBalance,
    uint256 _mintedLiquidity,
    uint256 _defaultCooldownTime,
    uint256 _oldCooldownTime,
    uint256 _lastDepositTimestamp
  ) internal view returns (uint256 cooldown) {
    uint256 prevCooldownEnd = _lastDepositTimestamp + _oldCooldownTime;
    // Calculate remaining cooldown from previous deposit, if any.
    uint256 prevCooldownRemaining = MathUtils._subOrZero(
      prevCooldownEnd,
      block.timestamp
    );

    // If the depositor's current balance is zero (new depositor or fully withdrawn), apply full cooldown for new liquidity, unless minting zero liquidity.
    if (_currentUserBalance == _mintedLiquidity) {
      cooldown = _mintedLiquidity == 0 ? 0 : _defaultCooldownTime;
    } else if (
      _mintedLiquidity == 0 || _defaultCooldownTime < prevCooldownRemaining
    ) {
      // If no new liquidity is minted or if the current cooldown is less than remaining, apply the remaining cooldown.
      cooldown = prevCooldownRemaining;
    } else {
      // Calculate average cooldown based on the proportion of existing and new liquidity.
      uint256 balanceBeforeMint = _currentUserBalance - _mintedLiquidity;
      uint256 averageCooldown = (_mintedLiquidity *
        _defaultCooldownTime +
        balanceBeforeMint *
        prevCooldownRemaining) / _currentUserBalance;
      // Ensure the cooldown does not exceed the current cooldown setting and is at least 1 second.
      cooldown = averageCooldown > _defaultCooldownTime
        ? _defaultCooldownTime
        : MathUtils._max(averageCooldown, 1);
    }
  }

  /**
   * @notice Verifies if a user's cooldown period has passed and if they are eligible to perform the next action.
   * @dev Throws an error if the cooldown period has not yet passed, enforcing the restriction.
   * @param _user The address of the user to check the cooldown period for.
   */
  function _checkCoolDownPeriod(address _user) internal view {
    uint256 userCoolDownPeriod = userLastDepositTime[_user] +
      userCooldownPeriod[_user];
    uint256 remainingCoolDown = userCoolDownPeriod <= block.timestamp
      ? 0
      : userCoolDownPeriod - block.timestamp;

    if (remainingCoolDown > 0) {
      revert ErrorLibrary.CoolDownPeriodNotPassed();
    }
  }
}
