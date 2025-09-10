// Static call test for Pendle Router redeemDueInterestAndRewardsV2 (correct ABI)

const { ethers } = require("hardhat");
import { deployedAddresses } from "./deployedAddresses";

async function main(): Promise<void> {
  let owner2;
  let accounts = await ethers.getSigners();
  [, owner2] = accounts;

  console.log("🎯 Pendle Router redeemDueInterestAndRewardsV2 Static Call Test");

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

  // Gnosis Safe ABI
  const GnosisSafeABI = [
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
  
  console.log("Is owner2 a safe owner?", isOwner);
  console.log("Safe threshold:", threshold.toString());

  if (!isOwner) {
    console.log("❌ Cannot proceed - owner2 is not a safe owner");
    return;
  }

  // Correct Pendle Router ABI from your provided ABI
  const PENDLE_ROUTER_ABI = [
    "function redeemDueInterestAndRewardsV2(address[] calldata SYs, tuple(address yt, bool doRedeemInterest, bool doRedeemRewards, address tokenRedeemSy, uint256 minTokenRedeemOut)[] calldata YTs, address[] calldata markets, address pendleSwap, tuple(address tokenIn, address tokenOut, uint256 minOut, tuple(uint8 swapType, address extRouter, bytes extCalldata, bool needScale) swapData)[] calldata swaps) external returns (uint256[] memory netOutFromSwaps, uint256[] memory netInterests)"
  ];

  const pendleRouter = new ethers.Contract(PENDLE_ROUTER, PENDLE_ROUTER_ABI, owner2);

  // Check SY token balance and allowance (SY token needs approval for redemption)
  const ERC20_ABI = [
    "function balanceOf(address account) external view returns (uint256)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)"
  ];
  const syToken = new ethers.Contract(SY_TOKEN, ERC20_ABI, owner2);
  const ytToken = new ethers.Contract(YT_TOKEN, ERC20_ABI, owner2);
  
  const syBalance = await syToken.balanceOf(vaultAddress);
  const syAllowance = await syToken.allowance(vaultAddress, PENDLE_ROUTER);
  const ytBalance = await ytToken.balanceOf(vaultAddress);
  const ytAllowance = await ytToken.allowance(vaultAddress, PENDLE_ROUTER);
  
  console.log(`\n📊 SY Balance: ${ethers.utils.formatEther(syBalance)}`);
  console.log(`📊 SY Allowance: ${ethers.utils.formatEther(syAllowance)}`);
  console.log(`📊 YT Balance: ${ethers.utils.formatEther(ytBalance)}`);
  console.log(`📊 YT Allowance: ${ethers.utils.formatEther(ytAllowance)}`);

  console.log("\n🧪 Static Call Test: redeemDueInterestAndRewardsV2");

  // Prepare parameters - minimal case with no swaps (like your successful tx)
  const SYs: string[] = []; // Empty SYs array
  const YTs = [{
    yt: YT_TOKEN,
    doRedeemInterest: true,
    doRedeemRewards: false, // Set to false as in your successful tx
    tokenRedeemSy: LISTBNB_TOKEN, // Use ListBNB token as in your successful tx
    minTokenRedeemOut: 1223552819221 // Use the same minTokenRedeemOut as your successful tx
  }];
  const markets: string[] = []; // Empty markets array  
  const pendleSwap = PENDLE_SWAP; // Use actual pendle swap address from your successful tx
  const swaps: any[] = []; // Empty swaps array

  console.log("Prepared parameters:");
  console.log("   SYs:", SYs.length);
  console.log("   YTs:", YTs.length, "- targeting", YT_TOKEN);
  console.log("   Markets:", markets.length);
  console.log("   Swaps:", swaps.length);

  // Prepare transaction data for Gnosis Safe execution
  const redeemData = pendleRouter.interface.encodeFunctionData("redeemDueInterestAndRewardsV2", [
    SYs,
    YTs,
    markets,
    pendleSwap,
    swaps
  ]);

  console.log("   Encoded data length:", redeemData.length);

  // Prepare SY token approval (confirmed needed based on successful wallet transactions)  
  console.log("\n✅ Preparing SY token approval for Pendle Router");
  
  const approvalData = syToken.interface.encodeFunctionData("approve", [PENDLE_ROUTER, ethers.constants.MaxUint256]);
  
  console.log("   SY Approval transaction prepared");
  console.log("   Target:", SY_TOKEN);
  console.log("   Spender:", PENDLE_ROUTER);
  console.log("   Amount: MAX_UINT256");
  
  const approvalTxHash = await gnosisSafe.getTransactionHash(
    SY_TOKEN,                 // to
    0,                       // value
    approvalData,            // data
    0,                       // operation (CALL)
    0,                       // safeTxGas
    0,                       // baseGas
    0,                       // gasPrice
    ethers.constants.AddressZero, // gasToken
    ethers.constants.AddressZero, // refundReceiver
    nonce                    // nonce
  );
  
  console.log("✅ SY Approval transaction hash:", approvalTxHash);
  console.log("   Execute this first: nonce", nonce.toString());
  
  // Also generate the redeem transaction hash
  const redeemTxHash = await gnosisSafe.getTransactionHash(
    PENDLE_ROUTER,           // to
    0,                       // value
    redeemData,             // data
    0,                       // operation (CALL)
    0,                       // safeTxGas
    0,                       // baseGas
    0,                       // gasPrice
    ethers.constants.AddressZero, // gasToken
    ethers.constants.AddressZero, // refundReceiver
    nonce.add(1)            // nonce (after approval)
  );
  
  console.log("✅ Redeem transaction hash:", redeemTxHash);
  console.log("   Execute this second: nonce", nonce.add(1).toString());

  try {
    // Test the static call now (approval should be done)
    console.log("\n🔍 Testing static call (assuming SY approval is done)...");
    
    // Test static call through provider (simulating Gnosis Safe execution)
    const result = await ethers.provider.call({
      to: PENDLE_ROUTER,
      data: redeemData,
      from: vaultAddress // This simulates calling from the Gnosis Safe
    });

    console.log("✅ Static call successful!");
    console.log("   Raw result:", result);

    // Decode the result
    const decodedResult = pendleRouter.interface.decodeFunctionResult("redeemDueInterestAndRewardsV2", result);
    console.log("   Net out from swaps:", decodedResult.netOutFromSwaps.map((r: any) => ethers.utils.formatEther(r)));
    console.log("   Net interests:", decodedResult.netInterests.map((r: any) => ethers.utils.formatEther(r)));

    if (decodedResult.netInterests.some((r: any) => r.gt(0)) || decodedResult.netOutFromSwaps.some((r: any) => r.gt(0))) {
      console.log("🎉 CLAIMABLE AMOUNTS AVAILABLE!");
    } else {
      console.log("📝 No amounts claimable at this time");
    }

    // Generate redeem transaction hash (with incremented nonce after approval)
    if (threshold.eq(1)) {
      const redeemNonce = nonce.add(1); // Always increment since we always prepare approval
      const redeemTxHash = await gnosisSafe.getTransactionHash(
        PENDLE_ROUTER,         // to
        0,                     // value
        redeemData,           // data
        0,                    // operation (CALL)
        0,                    // safeTxGas
        0,                    // baseGas
        0,                    // gasPrice
        ethers.constants.AddressZero, // gasToken
        ethers.constants.AddressZero, // refundReceiver
        redeemNonce           // nonce (incremented after approval)
      );

      console.log("✅ Redeem transaction hash generated:", redeemTxHash);
      console.log("✅ Redeem transaction nonce:", redeemNonce.toString());
      console.log("✅ Ready for execution through Gnosis Safe");
    }

  } catch (error: any) {
    console.log("❌ Static call failed:", error.message);
    
    if (error.message.includes("INVALID_SELECTOR")) {
      console.log("   Function selector still incorrect - checking ABI structure");
    } else if (error.message.includes("YT_ZERO_REWARDS")) {
      console.log("   No rewards to claim (normal if recently claimed)");
    } else if (error.message.includes("ERC20: insufficient allowance")) {
      console.log("\n🔍 Debugging which token needs approval...");
      
      // Let's check all potential token allowances that might be needed
      console.log("   Current allowances:");
      console.log(`   - YT (${YT_TOKEN}): ${ethers.utils.formatEther(ytAllowance)}`);
      console.log(`   - SY (${SY_TOKEN}): ${ethers.utils.formatEther(syAllowance)}`);
      
      // Since we have YT balance but 0 allowance, YT likely needs approval
      if (ytBalance.gt(0) && ytAllowance.eq(0)) {
        console.log("   ⚠️  YT token has balance but zero allowance - likely needs approval for redemption");
        
        // Generate YT approval transaction
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
        
        console.log("\n✅ YT Approval transaction hash:", ytApprovalTxHash);
        console.log("   Target:", YT_TOKEN);
        console.log("   Spender:", PENDLE_ROUTER);
        console.log("   Amount: MAX_UINT256");
        console.log("💡 Execute YT approval first, then redeem with nonce:", nonce.add(1).toString());
      }
    }
  }

  console.log("\n💡 Summary:");
  console.log("   - Using correct router function: redeemDueInterestAndRewardsV2");
  console.log("   - Parameters match successful wallet transaction pattern");
  console.log("   - SY token approval transaction prepared");
  console.log("   - Execute approval transaction first, then redeem transaction");
}

// Run the static call test
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });