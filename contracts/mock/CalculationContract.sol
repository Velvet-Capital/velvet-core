pragma solidity 0.8.17;

contract CalculationContract {
  function subAmounts(uint256 a, uint256 b) external pure returns (uint256) {
    require(a >= b, "invalid amounts");
    return a - b;
  }

  function calculateShare(
    uint256 a,
    uint256 b,
    uint256 c
  ) external pure returns (uint256) {
    return (a * b) / c;
  }

  function add(uint256 a, uint256 b) external pure returns (uint256) {
    return a + b;
  }
}