import "@nomicfoundation/hardhat-chai-matchers";
import { ethers, userConfig } from "hardhat";
import { BigNumber, Contract } from "ethers";

import { IERC20Upgradeable__factory } from "../../typechain";

const axios = require("axios");
const qs = require("qs");

export async function createEnsoCallData(
  data: any,
  ensoHandler: string,
): Promise<any> {
  const params = {
    chainId: 56,
    fromAddress: ensoHandler,
  };
  const postUrl = "https://api.enso.finance/api/v1/shortcuts/bundle?";

  const headers = {
    "Content-Type": "application/json",
    Authorization: process.env.ENSO_KEY,
  };

  return await axios.post(postUrl + `${qs.stringify(params)}`, data, {
    headers,
  });
}

export async function createEnsoCallDataRoute(
  ensoHandler: string,
  receiver: string,
  _tokenIn: any,
  _tokenOut: any,
  _amountIn: any,
): Promise<any> {
  const params = {
    chainId: 56,
    fromAddress: ensoHandler,
    receiver: receiver,
    spender: ensoHandler,
    amountIn: _amountIn,
    slippage: 300,
    tokenIn: _tokenIn,
    tokenOut: _tokenOut,
    routingStrategy: "delegate",
  };

  const postUrl = "https://api.enso.finance/api/v1/shortcuts/route?";

  const headers = {
    Authorization: process.env.ENSO_KEY,
  };

  return await axios.get(postUrl + `${qs.stringify(params)}`, {
    headers,
  });
}

export async function calculateSwapAmounts(
  portfolioAddress: string,
  portfolioAddressLibraryAddressLibraryAddress: string,
  depositAmount: any,
): Promise<{ inputAmounts: any[] }> {
  const Portfolio = await ethers.getContractFactory("Portfolio");
  const portfolioSwapInstance = Portfolio.attach(portfolioAddress);

  const length = (await portfolioSwapInstance.getTokens()).length;
  let inputAmounts = [];
  for (let i = 0; i < length; i++) {
    inputAmounts.push(
      ethers.BigNumber.from(depositAmount).div(length).toString(),
    );
  }
  return { inputAmounts };
}

// Returns the calldata returned by the Enso API
export async function createEnsoDataDeposit(
  _nativeTokenAddress: string,
  _depositToken: string,
  _portfolioTokens: string[],
  _userAddress: any,
  _inputAmounts: any[],
): Promise<{
  ensoApiResponse: any;
}> {
  let data = [];

  for (let i = 0; i < _portfolioTokens.length; i++) {
    if (_depositToken.toLowerCase() != _portfolioTokens[i].toLowerCase()) {
      data.push({
        protocol: "enso",
        action: "route",
        args: {
          tokenIn: _depositToken,
          tokenOut: _portfolioTokens[i],
          amountIn: _inputAmounts[i],
        },
      });
    }
  }

  return {
    ensoApiResponse: await createEnsoCallData(data, _userAddress),
  };
}

// Creates the calldata for the deposit including the Enso calldata + wrap/transfer calldata
export async function getDepositCalldata(
  portfolioAddress: string,
  portfolioAddressLibraryAddressLibraryAddress: string,
  depositToken: string,
  nativeTokenAddress: string,
  depositAmount: string,
  userAddress: string,
  inputAmounts: any[],
  nativeDeposit: boolean,
): Promise<any> {
  const Portfolio = await ethers.getContractFactory("Portfolio");
  const portfolio = Portfolio.attach(portfolioAddress);
  const _portfolioTokens = await portfolio.getTokens();

  //Get Smart Wallet For User

  // console.log("getWalletReponse",await getUserSmartWallet(userAddress));

  const { ensoApiResponse } = await createEnsoDataDeposit(
    nativeTokenAddress, // native token
    depositToken, // deposit token Enso (0xeeee... for native)
    _portfolioTokens,
    userAddress,
    inputAmounts,
  );

  return ensoApiResponse.data;
}
