// Execute Pendle Router redeemDueInterestAndRewardsV2 through Gnosis Safe

const { ethers } = require("hardhat");
import { deployedAddresses } from "./deployedAddresses";

const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

async function main(): Promise<void> {
  let owner2;
  let accounts = await ethers.getSigners();
  [, owner2] = accounts;

  console.log("🚀 Executing Pendle Router redeemDueInterestAndRewardsV2");

  const PENDLE_ROUTER = ethers.utils.getAddress("0x888888888889758f76e7103c6cbf23abbf58f946");
  const YT_TOKEN = ethers.utils.getAddress("0xBe436f6Ed7Ff7f747AaE1912F88C59549df82158");
  const SY_TOKEN = ethers.utils.getAddress("0x27FaF900007B4cBa7803000251ec96Bc69ff1BEa");
  const LISTBNB_TOKEN = ethers.utils.getAddress("0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B"); // tokenRedeemSy from your successful tx
  const PENDLE_SWAP = ethers.utils.getAddress("0xd4F480965D2347d421F1bEC7F545682E5Ec2151D"); // pendleSwap from your successful tx
  const vaultAddress = deployedAddresses.vaultAddress;
  
  console.log("Vault Address:", vaultAddress);
  console.log("Pendle Router:", PENDLE_ROUTER);
  console.log("YT Token:", YT_TOKEN);
  console.log("SY Token:", SY_TOKEN);
  console.log("ListBNB Token:", LISTBNB_TOKEN);
  console.log("Pendle Swap:", PENDLE_SWAP);
  console.log("Owner2 Address:", owner2.address);

  // Gas configuration for BSC
  const MAX_GAS_FEE_GWEI = 3;
  const feeData = await ethers.provider.getFeeData();
  const baseFee = feeData.lastBaseFeePerGas;
  const priorityFee = ethers.utils.parseUnits("0.1", "gwei");
  const minPriorityFee = ethers.utils.parseUnits("0.1", "gwei");
  const adjustedPriorityFee = priorityFee.lt(minPriorityFee) ? minPriorityFee : priorityFee;
  const calculatedMaxFee = baseFee.mul(2).add(adjustedPriorityFee);
  const maxFeePerGas = calculatedMaxFee.gt(
    ethers.utils.parseUnits(MAX_GAS_FEE_GWEI.toString(), "gwei")
  )
    ? ethers.utils.parseUnits(MAX_GAS_FEE_GWEI.toString(), "gwei")
    : calculatedMaxFee;

  const overrides = {
    maxFeePerGas: maxFeePerGas,
    maxPriorityFeePerGas: adjustedPriorityFee,
    gasLimit: 29000000,
  };

  console.log("Gas Settings:");
  console.log("   Base fee:", ethers.utils.formatUnits(baseFee, "gwei"), "Gwei");
  console.log("   Max fee per gas:", ethers.utils.formatUnits(maxFeePerGas, "gwei"), "Gwei");
  console.log("   Priority fee:", ethers.utils.formatUnits(adjustedPriorityFee, "gwei"), "Gwei");

  // Gnosis Safe ABI
  const GnosisSafeABI = [
    "function execTransaction(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes calldata signatures) external returns (bool success)",
    "function isOwner(address owner) external view returns (bool)",
    "function getThreshold() external view returns (uint256)",
    "function nonce() external view returns (uint256)",
    "function getTransactionHash(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce) external view returns (bytes32)"
  ];

  const gnosisSafe = new ethers.Contract(vaultAddress, GnosisSafeABI, owner2);
  
  // Verify setup
  const isOwner = await gnosisSafe.isOwner(owner2.address);
  const threshold = await gnosisSafe.getThreshold();
  const nonce = await gnosisSafe.nonce();
  
  console.log("\nGnosis Safe Status:");
  console.log("   Is owner2 a safe owner?", isOwner);
  console.log("   Safe threshold:", threshold.toString());
  console.log("   Safe nonce:", nonce.toString());

  if (!isOwner) {
    console.log("❌ Cannot proceed - owner2 is not a safe owner");
    return;
  }

  // Pendle Router ABI (same as static call test)
  const PENDLE_ROUTER_ABI = [
    "function redeemDueInterestAndRewardsV2(address[] calldata SYs, tuple(address yt, bool doRedeemInterest, bool doRedeemRewards, address tokenRedeemSy, uint256 minTokenRedeemOut)[] calldata YTs, address[] calldata markets, address pendleSwap, tuple(address tokenIn, address tokenOut, uint256 minOut, tuple(uint8 swapType, address extRouter, bytes extCalldata, bool needScale) swapData)[] calldata swaps) external returns (uint256[] memory netOutFromSwaps, uint256[] memory netInterests)"
  ];

  const pendleRouter = new ethers.Contract(PENDLE_ROUTER, PENDLE_ROUTER_ABI, owner2);

  // Check token balances and allowances before
  const ERC20_ABI = [
    "function balanceOf(address account) external view returns (uint256)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)"
  ];
  const ytToken = new ethers.Contract(YT_TOKEN, ERC20_ABI, owner2);
  const syToken = new ethers.Contract(SY_TOKEN, ERC20_ABI, owner2);
  
  const ytBalanceBefore = await ytToken.balanceOf(vaultAddress);
  const syBalanceBefore = await syToken.balanceOf(vaultAddress);
  const syAllowance = await syToken.allowance(vaultAddress, PENDLE_ROUTER);
  const ytAllowance = await ytToken.allowance(vaultAddress, PENDLE_ROUTER);
  
  console.log(`\n📊 Before Execution:`);
  console.log(`   YT Balance: ${ethers.utils.formatEther(ytBalanceBefore)}`);
  console.log(`   SY Balance: ${ethers.utils.formatEther(syBalanceBefore)}`);
  console.log(`   SY Allowance: ${ethers.utils.formatEther(syAllowance)}`);
  console.log(`   YT Allowance: ${ethers.utils.formatEther(ytAllowance)}`);

  // Prepare parameters (same as successful static call)
  const SYs: string[] = [];
  const YTs = [{
    yt: YT_TOKEN,
    doRedeemInterest: true,
    doRedeemRewards: true, // Set to false as in your successful tx
    tokenRedeemSy: LISTBNB_TOKEN, // Use ListBNB token as in your successful tx
    minTokenRedeemOut: 0 // Use the same minTokenRedeemOut as your successful tx
  }];
  const markets: string[] = [];
  const pendleSwap = PENDLE_SWAP; // Use actual pendle swap address from your successful tx
  const swaps: any[] = [];

  // Prepare transaction data
  const redeemData = pendleRouter.interface.encodeFunctionData("redeemDueInterestAndRewardsV2", [
    SYs,
    YTs,
    markets,
    pendleSwap,
    swaps
  ]);

  // Check if approvals are needed
  let needsSyApproval = syAllowance.eq(0);
  let needsYtApproval = ytAllowance.eq(0) && ytBalanceBefore.gt(0);
  
  if (needsYtApproval) {
    console.log("\n⚠️  YT token needs approval first!");
    console.log("   Executing YT approval transaction...");
    
    // Prepare YT approval transaction
    const ytApprovalData = ytToken.interface.encodeFunctionData("approve", [PENDLE_ROUTER, ethers.constants.MaxUint256]);
    
    const ytApprovalTxHash = await gnosisSafe.getTransactionHash(
      YT_TOKEN,
      0,
      ytApprovalData,
      0,
      0,
      0,
      0,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      nonce
    );
    
    console.log("   YT Approval transaction hash:", ytApprovalTxHash);
    
    // Sign and execute YT approval
    const ytApprovalMessageBytes = ethers.utils.arrayify(ytApprovalTxHash);
    const ytApprovalSignature = await owner2.signMessage(ytApprovalMessageBytes);
    const ytApprovalSigBytes = ethers.utils.arrayify(ytApprovalSignature);
    ytApprovalSigBytes[64] += 4;
    const adjustedYtApprovalSignature = ethers.utils.hexlify(ytApprovalSigBytes);
    
    const ytApprovalTx = await gnosisSafe.execTransaction(
      YT_TOKEN,
      0,
      ytApprovalData,
      0,
      0,
      0,
      0,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      adjustedYtApprovalSignature,
      overrides
    );
    
    console.log("🔄 YT Approval transaction submitted:", ytApprovalTx.hash);
    console.log("   Waiting for confirmation...");
    
    const ytApprovalReceipt = await ytApprovalTx.wait();
    console.log("✅ YT Approval confirmed in block:", ytApprovalReceipt.blockNumber);
    
    await sleep(3000);
    console.log("✅ YT token approved for Pendle Router");
  }
  
  if (needsSyApproval) {
    console.log("\n⚠️  SY token needs approval first!");
    console.log("   Executing SY approval transaction...");
    
    // Prepare SY approval transaction
    const approvalData = syToken.interface.encodeFunctionData("approve", [PENDLE_ROUTER, ethers.constants.MaxUint256]);
    
    const approvalTxHash = await gnosisSafe.getTransactionHash(
      SY_TOKEN,
      0,
      approvalData,
      0,
      0,
      0,
      0,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      nonce
    );
    
    console.log("   Approval transaction hash:", approvalTxHash);
    
    // Sign and execute approval
    const approvalMessageBytes = ethers.utils.arrayify(approvalTxHash);
    const approvalSignature = await owner2.signMessage(approvalMessageBytes);
    const approvalSigBytes = ethers.utils.arrayify(approvalSignature);
    approvalSigBytes[64] += 4;
    const adjustedApprovalSignature = ethers.utils.hexlify(approvalSigBytes);
    
    const approvalTx = await gnosisSafe.execTransaction(
      SY_TOKEN,
      0,
      approvalData,
      0,
      0,
      0,
      0,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      adjustedApprovalSignature,
      overrides
    );
    
    console.log("🔄 Approval transaction submitted:", approvalTx.hash);
    console.log("   Waiting for confirmation...");
    
    const approvalReceipt = await approvalTx.wait();
    console.log("✅ Approval confirmed in block:", approvalReceipt.blockNumber);
    
    await sleep(3000); // Wait for state update
    console.log("✅ SY token approved for Pendle Router");
  }

  console.log("\n🎯 Executing Redemption Transaction...");
  console.log("   Target:", PENDLE_ROUTER);
  console.log("   Data length:", redeemData.length);

  if (threshold.eq(1)) {
    try {
      // Get updated nonce after approval (if executed)
      const currentNonce = await gnosisSafe.nonce();
      // Generate transaction hash for signing
      const txHash = await gnosisSafe.getTransactionHash(
        PENDLE_ROUTER,         // to
        0,                     // value
        redeemData,           // data
        0,                    // operation (CALL)
        0,                    // safeTxGas
        0,                    // baseGas
        0,                    // gasPrice
        ethers.constants.AddressZero, // gasToken
        ethers.constants.AddressZero, // refundReceiver
        currentNonce          // use updated nonce
      );

      console.log("Transaction hash:", txHash);

      // Sign the transaction hash
      const messageBytes = ethers.utils.arrayify(txHash);
      const signature = await owner2.signMessage(messageBytes);
      
      // Adjust signature for Gnosis Safe format (add 4 to v value for contract signatures)
      const sigBytes = ethers.utils.arrayify(signature);
      sigBytes[64] += 4;
      const adjustedSignature = ethers.utils.hexlify(sigBytes);
      
      console.log("Signature prepared, executing transaction...");

      // Execute the transaction
      const executeTx = await gnosisSafe.execTransaction(
        PENDLE_ROUTER,         // to
        0,                     // value
        redeemData,           // data
        0,                    // operation (CALL)
        0,                    // safeTxGas
        0,                    // baseGas
        0,                    // gasPrice
        ethers.constants.AddressZero, // gasToken
        ethers.constants.AddressZero, // refundReceiver
        adjustedSignature,    // signatures
        overrides
      );

      console.log("🔄 Transaction submitted:", executeTx.hash);
      console.log("   Waiting for confirmation...");

      const receipt = await executeTx.wait();
      console.log("✅ Transaction confirmed in block:", receipt.blockNumber);
      console.log("   Gas used:", receipt.gasUsed.toString());

      // Wait a bit for state to update
      await sleep(3000);

      // Check balances after
      const ytBalanceAfter = await ytToken.balanceOf(vaultAddress);
      
      console.log("\n📊 After Execution:");
      console.log(`   YT Balance: ${ethers.utils.formatEther(ytBalanceAfter)}`);
      console.log(`   YT Balance Change: ${ethers.utils.formatEther(ytBalanceAfter.sub(ytBalanceBefore))}`);

      if (ytBalanceAfter.eq(ytBalanceBefore)) {
        console.log("📝 No balance change - this is expected if no rewards were available");
      } else {
        console.log("🎉 Balance changed - rewards may have been processed!");
      }

      console.log("\n🎉 SUCCESS!");
      console.log("   Transaction executed through Gnosis Safe");
      console.log("   Pendle redeemDueInterestAndRewardsV2 called successfully");
      console.log("   TX Hash:", executeTx.hash);

    } catch (error: any) {
      console.error("❌ Transaction failed:", error);
      console.error("   Error message:", error.message);
      
      if (error.message.includes("GS013")) {
        console.log("   Safe transaction failed - check parameters");
      } else if (error.message.includes("revert")) {
        console.log("   Contract call reverted - function may have failed");
      }
    }
  } else {
    console.log("⚠️ Multi-sig safe requires additional signature handling");
    console.log("   This script only handles single signature (threshold = 1)");
  }

  console.log("\n✅ Execution attempt completed!");
}

// Run the execution
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });