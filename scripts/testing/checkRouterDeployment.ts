// Check if Pendle router is actually deployed on BSC

const { ethers } = require("hardhat");

async function main(): Promise<void> {
  console.log("🔍 Checking Pendle Router Deployment on BSC");

  const PENDLE_ROUTER = "0x888888888889758f76e7103c6cbf23abbf58f946";
  
  console.log("Router Address:", PENDLE_ROUTER);
  
  // Check if contract has code
  const code = await ethers.provider.getCode(PENDLE_ROUTER);
  console.log("Contract code length:", code.length);
  console.log("Has code deployed:", code !== "0x");
  
  if (code !== "0x") {
    console.log("✅ Contract exists on BSC");
    console.log("Code preview:", code.substring(0, 50) + "...");
    
    // Check if it's a proxy
    if (code.includes("363d3d373d3d3d363d73")) {
      console.log("🔧 Appears to be a proxy contract");
    }
  } else {
    console.log("❌ No contract code found at this address on BSC");
    console.log("This explains the INVALID_SELECTOR errors!");
  }

  // Also check the other BSC Pendle addresses mentioned by agent
  const OTHER_PENDLE_ADDRESSES = [
    "0xb3ed0a426155b79b898849803e3b36552f7ed507", // PENDLE Token
    "0x3ae399eee439c00355b46456214cea80e9cf35e0"  // Another Pendle contract
  ];

  console.log("\n🔍 Checking other known Pendle addresses on BSC:");
  
  for (const addr of OTHER_PENDLE_ADDRESSES) {
    const otherCode = await ethers.provider.getCode(addr);
    console.log(`${addr}: ${otherCode !== "0x" ? "✅ Has code" : "❌ No code"}`);
  }

  console.log("\n💡 Recommendation:");
  console.log("If main router has no code, you need to:");
  console.log("1. Find the correct BSC router address");
  console.log("2. Use Pendle SDK instead");
  console.log("3. Or use direct token interactions (like you did with YT redemption)");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });