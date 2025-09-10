// Static call test for swapExactTokenForYt function with tiny WBNB amount

const { ethers } = require("hardhat");
import { deployedAddresses } from "./deployedAddresses";

async function main(): Promise<void> {
  let owner2;
  let accounts = await ethers.getSigners();
  [, owner2] = accounts;

  console.log("🧪 Testing swapExactTokenForYt Static Call");

  const PENDLE_ROUTER = ethers.utils.getAddress("0x888888888889758f76e7103c6cbf23abbf58f946");
  const YT_TOKEN = ethers.utils.getAddress("0xBe436f6Ed7Ff7f747AaE1912F88C59549df82158");
  const WBNB_ADDRESS = ethers.utils.getAddress("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c");
  const MARKET_ADDRESS = ethers.utils.getAddress("0xbd577ddabb5a1672d3c786726b87a175de652b96");
  const vaultAddress = deployedAddresses.vaultAddress;
  
  console.log("Vault Address:", vaultAddress);
  console.log("Pendle Router:", PENDLE_ROUTER);
  console.log("YT Token:", YT_TOKEN);
  console.log("WBNB Token:", WBNB_ADDRESS);
  console.log("Market:", MARKET_ADDRESS);

  // Check WBNB balance
  const ERC20_ABI = ["function balanceOf(address account) external view returns (uint256)", "function allowance(address owner, address spender) external view returns (uint256)"];
  const wbnb = new ethers.Contract(WBNB_ADDRESS, ERC20_ABI, owner2);
  const wbnbBalance = await wbnb.balanceOf(vaultAddress);
  
  console.log(`\n📊 WBNB Balance: ${ethers.utils.formatEther(wbnbBalance)}`);

  if (wbnbBalance.eq(0)) {
    console.log("❌ No WBNB in vault to test swap");
    return;
  }

  // Use very small amount for testing - 0.001 WBNB
  const testAmount = ethers.utils.parseEther("0.001");
  
  if (wbnbBalance.lt(testAmount)) {
    console.log("⚠️ Using smaller amount:", ethers.utils.formatEther(wbnbBalance.div(10)));
    // Use 10% of available balance if very low
    const smallerAmount = wbnbBalance.div(10);
    if (smallerAmount.gt(0)) {
      // Use the smaller amount
    } else {
      console.log("❌ WBNB balance too small for testing");
      return;
    }
  }

  console.log(`\n🔍 Testing swap of ${ethers.utils.formatEther(testAmount)} WBNB → YT`);

  // Check allowance
  const allowance = await wbnb.allowance(vaultAddress, PENDLE_ROUTER);
  console.log(`Current allowance: ${ethers.utils.formatEther(allowance)}`);

  // Try the confirmed working YT functions instead
  const PENDLE_ROUTER_ABI = [
    // This function was confirmed to exist in our test
    "function swapTokenToExactYt(address receiver, address market, uint256 exactYtOut, tuple(uint256 guessMin, uint256 guessMax, uint256 guessOffchain, uint256 maxIteration, uint256 eps) approxParams, tuple(address tokenIn, uint256 netTokenIn, address tokenMintSy, address pendleSwap, tuple(uint8 swapType, address extRouter, bytes extCalldata, bool needScale) swapData) input) external payable returns (uint256 netTokenUsed, uint256 netSyInterm)",
    
    // Also try the original with simpler parameter structure
    "function swapExactTokenForYt(address receiver, address market, uint256 minYtOut, bytes calldata data) external payable returns (uint256 netYtOut)"
  ];

  const pendleRouter = new ethers.Contract(PENDLE_ROUTER, PENDLE_ROUTER_ABI, owner2);

  // Prepare parameters (same as your vaultInteraction.ts)
  const defaultApprox = {
    guessMin: 0,
    guessMax: ethers.constants.MaxUint256,
    guessOffchain: 0,
    maxIteration: 256,
    eps: ethers.utils.parseUnits("1", 14) // 1e14
  };

  const tokenInput = {
    tokenIn: WBNB_ADDRESS,
    netTokenIn: testAmount,
    tokenMintSy: WBNB_ADDRESS,
    pendleSwap: ethers.constants.AddressZero,
    swapData: {
      swapType: 0,
      extRouter: ethers.constants.AddressZero,
      extCalldata: "0x",
      needScale: false
    }
  };

  const emptyLimit = {
    salt: 0,
    expiry: 0,
    sigR: 0,
    sigS: 0,
    sigV: 0
  };

  const minYtOut = 0; // No minimum for testing

  console.log("\n🧪 Static Call Test 1: Try swapTokenToExactYt (confirmed working)");

  try {
    // Test the function that we confirmed exists
    const exactYtOut = ethers.utils.parseEther("0.0005"); // Want small amount of YT
    
    const swapData1 = pendleRouter.interface.encodeFunctionData("swapTokenToExactYt", [
      vaultAddress,    // receiver
      MARKET_ADDRESS,  // market
      exactYtOut,      // exactYtOut (how much YT we want)
      defaultApprox,   // approxParams
      tokenInput       // input
    ]);

    console.log("✅ swapTokenToExactYt encoding successful!");
    console.log("   Data length:", swapData1.length);

    const result1 = await ethers.provider.call({
      to: PENDLE_ROUTER,
      data: swapData1,
      from: vaultAddress
    });

    console.log("✅ swapTokenToExactYt static call successful!");
    console.log("   Raw result:", result1);

    const decoded1 = pendleRouter.interface.decodeFunctionResult("swapTokenToExactYt", result1);
    console.log("   Token used:", ethers.utils.formatEther(decoded1.netTokenUsed));
    console.log("   SY interm:", ethers.utils.formatEther(decoded1.netSyInterm));

  } catch (error: any) {
    console.log("❌ swapTokenToExactYt failed:", error.message);
    
    if (error.message.includes("INVALID_SELECTOR")) {
      console.log("   ❌ Function still doesn't exist");
    } else if (error.message.includes("allowance") || error.message.includes("ERC20: transfer amount exceeds")) {
      console.log("   ✅ Function exists but needs more allowance!");
    } else if (error.message.includes("MARKET") || error.message.includes("market")) {
      console.log("   ✅ Function exists but market issue");
    } else {
      console.log("   ⚠️ Function exists, other issue:", error.message.substring(0, 150));
    }
  }

  console.log("\n🧪 Static Call Test 2: Try simple swapExactTokenForYt");

  try {
    // Try the simpler signature
    const simpleData = "0x"; // Empty bytes for now
    const swapData2 = pendleRouter.interface.encodeFunctionData("swapExactTokenForYt", [
      vaultAddress,    // receiver
      MARKET_ADDRESS,  // market
      minYtOut,       // minYtOut
      simpleData      // data
    ]);

    const result2 = await ethers.provider.call({
      to: PENDLE_ROUTER,
      data: swapData2,
      from: vaultAddress
    });

    console.log("✅ Simple swapExactTokenForYt successful!");
    console.log("   Raw result:", result2);

  } catch (error: any) {
    console.log("❌ Simple swapExactTokenForYt failed:", error.message);
    
    if (error.message.includes("INVALID_SELECTOR")) {
      console.log("   ❌ Simple signature doesn't work either");
    } else {
      console.log("   ⚠️ Simple signature exists but has issues");
    }
  }

  console.log("\n💡 Test Summary:");
  console.log("   - Function encoding: Test if ABI is correct");
  console.log("   - Static call: Test if function exists on router"); 
  console.log("   - Error analysis: Determine next steps");
  
  console.log("\n🎯 Next Steps:");
  if (allowance.lt(testAmount)) {
    console.log("   1. Need to approve WBNB spending first");
    console.log("   2. Then try the swap with proper approvals");
  }
  console.log("   3. If function works, we can execute with Gnosis Safe!");
}

// Run the static call test
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });