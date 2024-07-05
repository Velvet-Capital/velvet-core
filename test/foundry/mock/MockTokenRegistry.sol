// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

contract MockTokenRegistry {
  uint256 private _maxManagementFee;
  uint256 private _maxPerformanceFee;
  uint256 private _maxEntryFee;
  uint256 private _maxExitFee;
  uint256 private _minInitialIndexPrice;
  uint256 private _minIndexTokenAmount; // New variable for minimum index token amount

  constructor() {
    // Initialize with default values
    _maxManagementFee = 1000; // Example values
    _maxPerformanceFee = 500;
    _maxEntryFee = 100;
    _maxExitFee = 100;
    _minInitialIndexPrice = 10000000000000000; // Example value
    _minIndexTokenAmount = 5000000000000000; // Example value for minIndexTokenAmount
  }

  // Getter functions
  function maxManagementFee() external view returns (uint256) {
    return _maxManagementFee;
  }

  function maxPerformanceFee() external view returns (uint256) {
    return _maxPerformanceFee;
  }

  function maxEntryFee() external view returns (uint256) {
    return _maxEntryFee;
  }

  function maxExitFee() external view returns (uint256) {
    return _maxExitFee;
  }

  function minInitialIndexPrice() external view returns (uint256) {
    return _minInitialIndexPrice;
  }

  function minIndexTokenAmount() external view returns (uint256) {
    return _minIndexTokenAmount;
  }

  // Setter functions
  function setMaxManagementFee(uint256 fee) external {
    _maxManagementFee = fee;
  }

  function setMaxPerformanceFee(uint256 fee) external {
    _maxPerformanceFee = fee;
  }

  function setMaxEntryFee(uint256 fee) external {
    _maxEntryFee = fee;
  }

  function setMaxExitFee(uint256 fee) external {
    _maxExitFee = fee;
  }

  function setMinInitialIndexPrice(uint256 price) external {
    _minInitialIndexPrice = price;
  }

  function setMinIndexTokenAmount(uint256 amount) external {
    _minIndexTokenAmount = amount;
  }
}
