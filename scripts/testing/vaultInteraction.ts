// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, upgrades, tenderly } = require("hardhat");
import { chainIdToAddresses } from "../networkVariables";
import { deployedAddresses } from "./deployedAddresses";

// Clean Pendle integration - only essential imports

const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

async function main(): Promise<void> {
  let owner2;
  let accounts = await ethers.getSigners();
  [, owner2] = accounts;

  // BSC Mainnet configuration

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

  console.log("🚀 Vault Interaction with Pendle Router Started");

  // Pendle Router Configuration for BSC
  const PENDLE_ROUTER = ethers.utils.getAddress("0x888888888889758F76e7103c6CbF23ABbF58F946");
  const YT_TOKEN = ethers.utils.getAddress("0xBe436f6Ed7Ff7f747AaE1912F88C59549df82158");
  const WBNB_ADDRESS = ethers.utils.getAddress("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c");
  
  // Market address from your successful transaction
  const MARKET_ADDRESS = ethers.utils.getAddress("0xbd577ddabb5a1672d3c786726b87a175de652b96");
  
  // Get deployed vault address
  const vaultAddress = deployedAddresses.vaultAddress;
  
  console.log("Vault Address:", vaultAddress);
  console.log("Owner2 Address:", owner2.address);

  // Load the Gnosis Safe interface
  const GnosisSafeABI = [
    "function execTransaction(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes calldata signatures) external returns (bool success)",
    "function isOwner(address owner) external view returns (bool)",
    "function getThreshold() external view returns (uint256)",
    "function getOwners() external view returns (address[] memory)",
    "function nonce() external view returns (uint256)",
    "function getTransactionHash(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce) external view returns (bytes32)",
    "function encodeTransactionData(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce) external view returns (bytes memory)"
  ];

  const gnosisSafe = new ethers.Contract(vaultAddress, GnosisSafeABI, owner2);
  
  // Verify owner2 is an owner of the safe
  const isOwner = await gnosisSafe.isOwner(owner2.address);
  console.log("Is owner2 a safe owner?", isOwner);
  
  if (!isOwner) {
    console.log("Owner2 is not a safe owner, cannot proceed with transaction");
    return;
  }

  // Get safe details
  const threshold = await gnosisSafe.getThreshold();
  const owners = await gnosisSafe.getOwners();
  const nonce = await gnosisSafe.nonce();
  
  console.log("Safe threshold:", threshold.toString());
  console.log("Safe owners:", owners);
  console.log("Safe nonce:", nonce.toString());

  // WBNB ERC20 ABI for approval and transfer
  const ERC20_ABI = [
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function balanceOf(address account) external view returns (uint256)",
    "function transfer(address to, uint256 amount) external returns (bool)"
  ];

  const wbnb = new ethers.Contract(WBNB_ADDRESS, ERC20_ABI, owner2);

  // Check WBNB balance in the vault
  const vaultWBNBBalance = await wbnb.balanceOf(vaultAddress);
  console.log("Vault WBNB Balance:", ethers.utils.formatEther(vaultWBNBBalance));

  if (vaultWBNBBalance.eq(0)) {
    console.log("No WBNB in vault to swap");
    return;
  }

  console.log(" Target YT Token:", YT_TOKEN);

  // Amount to swap - using 0.0035 WBNB as you specified
  const swapAmount = ethers.utils.parseEther("0.0035");
  
  if (vaultWBNBBalance.lt(swapAmount)) {
    console.log("Insufficient WBNB balance in vault for swap");
    return;
  }

  console.log("💰 Swapping", ethers.utils.formatEther(swapAmount), "WBNB for YT tokens");

  console.log("🔧 Using official Pendle RouterSample pattern");
  
  // Use the EXACT same pattern as RouterSample.sol from Pendle examples
  const PendleRouterABI = [
    "function swapExactTokenForYt(address receiver, address market, uint256 minYtOut, tuple(uint256 guessMin, uint256 guessMax, uint256 guessOffchain, uint256 maxIteration, uint256 eps) approxParams, tuple(address tokenIn, uint256 netTokenIn, address tokenMintSy, address pendleSwap, tuple(uint8 swapType, address extRouter, bytes extCalldata, bool needScale) swapData) input, tuple(uint256 salt, uint256 expiry, uint256 sigR, uint256 sigS, uint8 sigV) limit) external payable returns (uint256 netYtOut, uint256 netSyFee, uint256 netSyInterm)"
  ];

  const pendleRouter = new ethers.Contract(PENDLE_ROUTER, PendleRouterABI, owner2);

  // DefaultApprox from StructGen.sol: ApproxParams(0, type(uint256).max, 0, 256, 1e14)
  const defaultApprox = {
    guessMin: 0,
    guessMax: ethers.constants.MaxUint256,
    guessOffchain: 0,
    maxIteration: 256,
    eps: ethers.utils.parseUnits("1", 14) // 1e14
  };

  // createTokenInputStruct pattern - simple TokenInput without aggregators
  const tokenInput = {
    tokenIn: WBNB_ADDRESS,
    netTokenIn: swapAmount, // Dynamic amount
    tokenMintSy: WBNB_ADDRESS, // tokenMintSy = tokenIn (from StructGen.sol)
    pendleSwap: ethers.constants.AddressZero, // address(0)
    swapData: {
      swapType: 0,
      extRouter: ethers.constants.AddressZero,
      extCalldata: "0x",
      needScale: false
    }
  };

  // emptyLimit from StructGen.sol
  const emptyLimit = {
    salt: 0,
    expiry: 0,
    sigR: 0,
    sigS: 0,
    sigV: 0
  };

  const minYtOut = 0; // Use 0 like in the RouterSample example

  // Encode using the RouterSample pattern
  const swapData = pendleRouter.interface.encodeFunctionData("swapExactTokenForYt", [
    vaultAddress, // receiver (like address(this) in RouterSample)
    MARKET_ADDRESS, // market address
    minYtOut, // 0 (like in RouterSample)
    defaultApprox, // defaultApprox from StructGen.sol
    tokenInput, // createTokenInputStruct pattern
    emptyLimit // emptyLimit from StructGen.sol
  ]);

  const pendleSwapTx = {
    to: PENDLE_ROUTER,
    data: swapData,
    value: "0"
  };
  
  console.log("✅ Pendle transaction prepared");
  console.log("   Target:", pendleSwapTx.to);
  console.log("   Data length:", pendleSwapTx.data.length);

  console.log("Preparing transactions through Gnosis Safe...");
  
  console.log("Preparing transactions through Gnosis Safe...");
  
  // For single signature (threshold = 1), we need to create a proper signature
  if (threshold.eq(1)) {
    try {
      // STEP 1: Approve Pendle Router
      console.log("Step 1: Approving Pendle Router to spend WBNB...");
      
      const approveData = wbnb.interface.encodeFunctionData("approve", [
        PENDLE_ROUTER,
        swapAmount
      ]);

      const approveTxHash = await gnosisSafe.getTransactionHash(
        WBNB_ADDRESS,
        0,
        approveData,
        0, // CALL operation
        0, // safeTxGas
        0, // baseGas
        0, // gasPrice
        ethers.constants.AddressZero, // gasToken
        ethers.constants.AddressZero, // refundReceiver
        nonce
      );
      
      const approveMessageBytes = ethers.utils.arrayify(approveTxHash);
      const approveSignature = await owner2.signMessage(approveMessageBytes);
      
      // Use working signature format
      const approveSigBytes = ethers.utils.arrayify(approveSignature);
      approveSigBytes[64] += 4;
      const adjustedApproveSignature = ethers.utils.hexlify(approveSigBytes);
      
      const approveTx = await gnosisSafe.execTransaction(
        WBNB_ADDRESS,
        0,
        approveData,
        0,
        0,
        0,
        0,
        ethers.constants.AddressZero,
        ethers.constants.AddressZero,
        adjustedApproveSignature,
        overrides
      );
      
      await approveTx.wait();
      console.log("✅ Approval executed:", approveTx.hash);
      
      // Check allowance
      await sleep(3000);
      const allowance = await wbnb.allowance(vaultAddress, PENDLE_ROUTER);
      console.log("✅ Pendle Router allowance:", ethers.utils.formatEther(allowance));
      
      // STEP 2: Execute Pendle Swap
      console.log("Step 2: Executing Pendle swap for YT tokens...");
      
      const newNonce = await gnosisSafe.nonce();

      console.log("New Nonce:", newNonce);
    console.log("Pendle Swap Tx:", pendleSwapTx);
      
      const swapTxHash = await gnosisSafe.getTransactionHash(
        pendleSwapTx.to,
        parseInt(pendleSwapTx.value),
        pendleSwapTx.data,
        0,
        0,
        0,
        0,
        ethers.constants.AddressZero,
        ethers.constants.AddressZero,
        newNonce
      );
      
      const swapMessageBytes = ethers.utils.arrayify(swapTxHash);
      const swapSignature = await owner2.signMessage(swapMessageBytes);
      
      // Use same working signature format
      const swapSigBytes = ethers.utils.arrayify(swapSignature);
      swapSigBytes[64] += 4;
      const adjustedSwapSignature = ethers.utils.hexlify(swapSigBytes);
      
      const swapTx = await gnosisSafe.execTransaction(
        pendleSwapTx.to,
        parseInt(pendleSwapTx.value),
        pendleSwapTx.data,
        0,
        0,
        0,
        0,
        ethers.constants.AddressZero,
        ethers.constants.AddressZero,
        adjustedSwapSignature,
        overrides
      );
      
      await swapTx.wait();
      console.log("✅ Pendle swap executed:", swapTx.hash);
      
      // Wait and check final balances
      await sleep(3000);
      
      // Check YT token balance
      const ytToken = new ethers.Contract(YT_TOKEN, ERC20_ABI, owner2);
      const ytBalance = await ytToken.balanceOf(vaultAddress);
      
      // Check remaining WBNB balance
      const vaultWBNBBalanceAfter = await wbnb.balanceOf(vaultAddress);
      
      console.log("🎉 SUCCESS! Pendle integration completed:");
      console.log("📊 Final Balances:");
      console.log("   Vault WBNB:", ethers.utils.formatEther(vaultWBNBBalanceAfter));
      console.log("   Vault YT Tokens:", ethers.utils.formatEther(ytBalance));
      console.log("🔗 Approval Tx:", approveTx.hash);
      console.log("🔗 Pendle Swap Tx:", swapTx.hash);
      
    } catch (error: any) {
      console.error("❌ Transaction failed:", error);
      console.error("Error message:", error.message);
    }
  } else {
    console.log("Multi-sig safe requires additional signature handling");
    console.log("You'll need to implement proper signature collection for threshold >1");
  }

  console.log("🎉 Vault Interaction with Pendle Router Completed");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });