import "@nomicfoundation/hardhat-chai-matchers";
import { ethers, userConfig } from "hardhat";
import { BigNumber, Contract } from "ethers";

import { IERC20Upgradeable__factory } from "../../typechain";

const axios = require("axios");
const qs = require("qs");

export async function calcuateExpectedMintAmount(
  userShare: any,
  totalSupply: any,
): Promise<any> {
  // wrong user share!!!
  // deposit amount / (depositamount + balance)
  return (userShare * totalSupply) / (Number(1000000000000000000) - userShare);
}

export async function createEnsoDataElement(
  _tokenIn: any,
  _tokenOut: any,
  _amountIn: any,
): Promise<any> {
  return {
    protocol: "enso",
    action: "route",
    args: {
      tokenIn: _tokenIn,
      tokenOut: _tokenOut,
      amountIn: _amountIn,
      slippage: "1500",
    },
  };
}
