const { ethers, upgrades, tenderly } = require("hardhat");
import { chainIdToAddresses } from "../networkVariables";
import { deployedAddresses } from "./deployedAddresses";

import {
  Portfolio,
  Portfolio__factory,
  ProtocolConfig,
  Rebalancing__factory,
  PortfolioFactory,
} from "../../typechain";
import { createEnsoCallDataRoute } from "../../test/Bsc/IntentCalculations";

const chainId: any = process.env.CHAIN_ID;
  const addresses = chainIdToAddresses[chainId];

function divideAmountEqually(amount: any, tokenCount: number) {
  const amountPerToken = amount.div(tokenCount);

  const depositAmounts = new Array(tokenCount).fill(amountPerToken);
  for (let i = 0; i < tokenCount; i++) {
    depositAmounts[i] = amountPerToken;
  }

  return depositAmounts;
}

const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

async function main(): Promise<void> {
  let owner;
  let owner2;
  let treasury;
  let owner4;
  let accounts = await ethers.getSigners();
  [owner, owner2, treasury, owner4] = accounts;

  const chainId: any = process.env.CHAIN_ID;
  const addresses = chainIdToAddresses[chainId];
  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  const isValidAddress = (address: string) => {
    return (
      address !== ZERO_ADDRESS &&
      address.length === 42 && // Ethereum address length
      address.startsWith("0x")
    );
  };

  // Set maximum gas fee (in Gwei)
  const MAX_GAS_FEE_GWEI = 3; // Adjust this value as needed

  // Get the current base fee
  const feeData = await ethers.provider.getFeeData();
  const baseFee = feeData.lastBaseFeePerGas;

  // Calculate priority fee (tip)
  const priorityFee = ethers.utils.parseUnits("0.1", "gwei");

  // Ensure the priority fee is at least 1 Gwei
  const minPriorityFee = ethers.utils.parseUnits("0.1", "gwei");
  const adjustedPriorityFee = priorityFee.lt(minPriorityFee)
    ? minPriorityFee
    : priorityFee;

  // Calculate max fee per gas, but cap it at MAX_GAS_FEE_GWEI
  const calculatedMaxFee = baseFee.mul(2).add(adjustedPriorityFee);
  const maxFeePerGas = calculatedMaxFee.gt(
    ethers.utils.parseUnits(MAX_GAS_FEE_GWEI.toString(), "gwei")
  )
    ? ethers.utils.parseUnits(MAX_GAS_FEE_GWEI.toString(), "gwei")
    : calculatedMaxFee;

  // Use this for deployment transactions
  const overrides = {
    maxFeePerGas: maxFeePerGas,
    maxPriorityFeePerGas: adjustedPriorityFee,
    gasLimit: 29000000, // Adjust this value based on your contract's complexity
  };

  console.log("Base fee:", ethers.utils.formatUnits(baseFee, "gwei"), "Gwei");
  console.log(
    "Max fee per gas:",
    ethers.utils.formatUnits(maxFeePerGas, "gwei"),
    "Gwei"
  );
  console.log(
    "Priority fee:",
    ethers.utils.formatUnits(adjustedPriorityFee, "gwei"),
    "Gwei"
  );

  console.log("--------------- Deposit Started ---------------");

  const Portfolio = await ethers.getContractFactory("Portfolio");
  const portfolio = await Portfolio.attach(deployedAddresses.portfolioAddress);

  const tokens = await portfolio.getTokens();
  console.log("Tokens:", tokens);

  const vault = await portfolio.vault();
  console.log("Vault:", vault);

  const DepositBatch = await ethers.getContractFactory(
    "DepositBatch"
  );
  const depositBatch = await DepositBatch.attach(
    deployedAddresses.DepositBatch
  );

  console.log("------------- Before Deposit Check -------------");

  const AssetManagementConfig = await ethers.getContractFactory(
    "AssetManagementConfig"
  );
  const config = await portfolio.assetManagementConfig();
  const assetManagementConfig = AssetManagementConfig.attach(config);


  console.log("------------- Creating Enso Call Data Route -------------");

  const totalSupply = await portfolio.totalSupply();
  let amount = ethers.utils.parseUnits("0.0070", "ether");
  let depositAmounts = [];
  let postResponse = [];

  if (totalSupply.gt(0)) {
    depositAmounts = await calculateWeightedDepositAmounts(
      portfolio,
      tokens,
      vault,
      amount
    );
  } else {
    depositAmounts = divideAmountEqually(amount, tokens.length);
    console.log(depositAmounts);
  }

  for (let i = 0; i < tokens.length; i++) {
    let response = await createEnsoCallDataRoute(
      depositBatch.address,
      depositBatch.address,
      "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      tokens[i],
      depositAmounts[i].toString()
    );
    postResponse.push(response.data.tx.data);
  }

  console.log("------------- Executing Deposit Batch -------------");

  const data = await depositBatch.connect(owner4).multiTokenSwapETHAndTransfer(
    {
      _minMintAmount: 0,
      _depositAmount: amount.toString(),
      _target: portfolio.address,
      _depositToken: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      _callData: postResponse,
    },
    {
      value: amount.toString(),
    }
  );

  console.log(
    "------------------------------ Deposit Ended ------------------------------"
  );
}

async function calculateWeightedDepositAmounts(
  portfolio: any,
  tokens: string[],
  vault: string,
  depositAmount: any
): Promise<any[]> {

  const Oracle = await ethers.getContractFactory("PriceOracle");
  const oracle = Oracle.attach(deployedAddresses.PriceOracle);

  let ERC20 = await ethers.getContractFactory("ERC20Upgradeable");

  // Process all tokens in parallel
  const tokenProcessingPromises = tokens.map(async (token, i) => {
    const balance = await ERC20.attach(token).balanceOf(vault);

      // Regular token
      const usdValue = await oracle.convertToUSD18Decimals(token, balance);
      return { usdValue, isCollateral: false, tokenIndex: i };
    }
  );

  const tokenResults = await Promise.all(tokenProcessingPromises);

  // Extract USD values in the same order as portfolio.getTokens()
  const tokenUSDValues = tokenResults.map((result) => result.usdValue);

  const depositAmounts = [];
  for (let i = 0; i < tokens.length; i++) {
      depositAmounts.push(depositAmount.div(tokens.length));
  }

  console.log("Portfolio Tokens (in order):", tokens);
  console.log(
    "Original USD Values (in order):",
    tokenUSDValues.map((v) => ethers.utils.formatEther(v))
  );
  console.log(
    "Deposit Amounts:",
    depositAmounts.map((a) => ethers.utils.formatEther(a))
  );

  return depositAmounts;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });