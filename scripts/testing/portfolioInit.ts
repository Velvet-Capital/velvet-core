// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
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

  console.log("--------------- Portfolio Init Started ---------------");

  const Portfolio = await ethers.getContractFactory("Portfolio");
  // const portfolio = await Portfolio.attach(deployedAddresses.portfolioContract);

  const PortfolioFactory = await ethers.getContractFactory("PortfolioFactory");
  const portfolioFactory = await PortfolioFactory.attach(
    deployedAddresses.PortfolioFactory
  );

  // console.log("Creating portfolio...");
  // const portfolioDeployed = await portfolioFactory
  //   .connect(owner2)
  //   .createPortfolioCustodial({
  //     _name: "PORTFOLIOLY",
  //     _symbol: "IDX",
  //     _managementFee: "100",
  //     _performanceFee: "0",
  //     _entryFee: "0",
  //     _exitFee: "0",
  //     _initialPortfolioAmount: "10000000000000000000000",
  //     _minPortfolioTokenHoldingAmount: "10000000000000000",
  //     _assetManagerTreasury: treasury.address,
  //     _whitelistedTokens: [],
  //     _public: true,
  //     _transferable: true,
  //     _transferableToPublic: true,
  //     _whitelistTokens: false,
  //   }, [owner2.address], "1");

  // await sleep(30000);

  console.log("Portfolio created...");

  let portfolioId = await portfolioFactory.portfolioId();
  console.log("Portfolio ID:", portfolioId);

  console.log("Portfolio ID:", portfolioId - 1);
  const portfolioAddress = await portfolioFactory.getPortfolioList(portfolioId - 1);
  const portfolioInfo = await portfolioFactory.PortfolioInfolList(portfolioId - 1);

  const portfolio = await ethers.getContractAt(
    Portfolio__factory.abi,
    portfolioAddress
  );

  console.log("Portfolio Address:", portfolioAddress);
  console.log("Portfolio Vault:", await portfolio.vault());

  await portfolio.connect(owner2).initToken([
    deployedAddresses.wbnbAddress,
  ]);

  console.log(
    "------------------------------ Portfolio Init Ended ------------------------------"
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });