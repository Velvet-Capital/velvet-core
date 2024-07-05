// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

/**
 * @title MathUtils
 * @notice Provides utility functions for common mathematical operations.
 * @dev This library offers functions for operations like finding the minimum
 *      and maximum values between two numbers. It can be extended to include
 *      more complex mathematical functions as needed.
 */
library MathUtils {
  error InvalidCastToUint160();

  /**
   * @notice Returns the smaller of two numbers.
   * @param _a The first number to compare.
   * @param _b The second number to compare.
   * @return The smaller of the two numbers.
   */
  function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
    return _a < _b ? _a : _b;
  }

  /**
   * @notice Returns the larger of two numbers.
   * @param _a The first number to compare.
   * @param _b The second number to compare.
   * @return The larger of the two numbers.
   */
  function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
    return _a > _b ? _a : _b;
  }

  /**
   * @notice Subtracts two numbers, returning zero if the result would be negative.
   * @param _a The number from which to subtract.
   * @param _b The number to subtract from the first number.
   * @return The result of the subtraction or zero if it would be negative.
   */
  function _subOrZero(uint256 _a, uint256 _b) internal pure returns (uint256) {
    if (_a > _b) {
      unchecked {
        return _a - _b;
      }
    } else {
      return 0;
    }
  }

  /**
   * @notice Safely casts a uint value to uint160, ensuring the value is within the range of uint160.
   * @param _val The value to cast to uint160.
   * @return The value cast to uint160, if it is representable.
   * @dev Reverts with `InvalidCastToUint160` error if the value exceeds the maximum uint160 value.
   */
  function safe160(uint _val) internal pure returns (uint160) {
    if (_val > type(uint160).max) revert InvalidCastToUint160();
    return uint160(_val);
  }
}
