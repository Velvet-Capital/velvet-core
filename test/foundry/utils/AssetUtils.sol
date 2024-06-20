// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {ERC20 as BaseERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {Test} from "forge-std/Test.sol";

abstract contract AssetUtils is Test {
  function getAssetUnit(address asset) internal view returns (uint256) {
    return 10 ** IERC20(asset).decimals();
  }

  function _generateTestToken(
    uint8 decimals,
    string memory name,
    string memory symbol
  ) internal returns (IERC20 token) {
    address tokenAddress = address(new SampleToken(name, symbol, decimals));
    vm.label(tokenAddress, name);

    return IERC20(tokenAddress);
  }

  function generateTestTokenByDecimal(
    uint8 decimals
  ) internal returns (IERC20 token) {
    return _generateTestToken(decimals, "Sample Token", "SMP");
  }

  function generateTestToken() internal returns (IERC20 token) {
    return generateTestTokenByDecimal(18);
  }

  function generateTestTokenByName(
    string memory _name,
    uint8 _decimals
  ) public returns (IERC20 token) {
    return _generateTestToken(_decimals, _name, _name);
  }
}

contract SampleToken is BaseERC20 {
  uint8 internal immutable tokenDecimals;

  constructor(
    string memory name,
    string memory symbol,
    uint8 decimals
  ) BaseERC20(name, symbol) {
    tokenDecimals = decimals;
  }

  function decimals() public view virtual override returns (uint8) {
    return tokenDecimals;
  }

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }
}
