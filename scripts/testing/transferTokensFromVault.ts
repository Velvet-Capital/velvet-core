// scripts/testing/transferTokensFromVault.ts

const { ethers } = require("hardhat");
import { deployedAddresses } from "./deployedAddresses";

async function main(): Promise<void> {
  let owner2;
  let accounts = await ethers.getSigners();
  [, owner2] = accounts;

  // Token addresses to transfer
  const YT_TOKEN = "0xbe436f6ed7ff7f747aae1912f88c59549df82158";
  const SLISBNB_TOKEN = "0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B";
  const RECIPIENT = "0xA9560340cA757d537E297c7Cf9416a586D217c07";
  const VAULT = deployedAddresses.vaultAddress;

  console.log("🚀 Transferring tokens from vault to wallet");
  console.log("Vault:", VAULT);
  console.log("Recipient:", RECIPIENT);

  // Gnosis Safe ABI
  const GnosisSafeABI = [
    "function execTransaction(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes calldata signatures) external returns (bool success)",
    "function isOwner(address owner) external view returns (bool)",
    "function nonce() external view returns (uint256)",
    "function getTransactionHash(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce) external view returns (bytes32)"
  ];

  const gnosisSafe = new ethers.Contract(VAULT, GnosisSafeABI, owner2);

  // ERC20 ABI
  const ERC20_ABI = [
    "function transfer(address to, uint256 amount) external returns (bool)",
    "function balanceOf(address account) external view returns (uint256)",
    "function symbol() external view returns (string)"
  ];

  // Transfer YT Token
  console.log("\n🔄 Transferring YT Token...");
  const ytToken = new ethers.Contract(YT_TOKEN, ERC20_ABI, owner2);
  const ytBalance = await ytToken.balanceOf(VAULT);
  const ytSymbol = await ytToken.symbol();
  
  console.log(`${ytSymbol} Balance:`, ethers.utils.formatEther(ytBalance));
  
  if (!ytBalance.eq(0)) {
    const transferData = ytToken.interface.encodeFunctionData("transfer", [RECIPIENT, ytBalance]);
    const nonce = await gnosisSafe.nonce();
    
    const txHash = await gnosisSafe.getTransactionHash(YT_TOKEN, 0, transferData, 0, 0, 0, 0, ethers.constants.AddressZero, ethers.constants.AddressZero, nonce);
    const signature = await owner2.signMessage(ethers.utils.arrayify(txHash));
    const sigBytes = ethers.utils.arrayify(signature);
    sigBytes[64] += 4;
    
    const tx = await gnosisSafe.execTransaction(YT_TOKEN, 0, transferData, 0, 0, 0, 0, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.utils.hexlify(sigBytes));
    await tx.wait();
    console.log("✅ YT Token transferred:", tx.hash);
  }

  // Transfer slisBNB Token
  console.log("\n🔄 Transferring slisBNB Token...");
  const slisToken = new ethers.Contract(SLISBNB_TOKEN, ERC20_ABI, owner2);
  const slisBalance = await slisToken.balanceOf(VAULT);
  const slisSymbol = await slisToken.symbol();
  
  console.log(`${slisSymbol} Balance:`, ethers.utils.formatEther(slisBalance));
  
  if (!slisBalance.eq(0)) {
    const transferData = slisToken.interface.encodeFunctionData("transfer", [RECIPIENT, slisBalance]);
    const nonce = await gnosisSafe.nonce();
    
    const txHash = await gnosisSafe.getTransactionHash(SLISBNB_TOKEN, 0, transferData, 0, 0, 0, 0, ethers.constants.AddressZero, ethers.constants.AddressZero, nonce);
    const signature = await owner2.signMessage(ethers.utils.arrayify(txHash));
    const sigBytes = ethers.utils.arrayify(signature);
    sigBytes[64] += 4;
    
    const tx = await gnosisSafe.execTransaction(SLISBNB_TOKEN, 0, transferData, 0, 0, 0, 0, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.utils.hexlify(sigBytes));
    await tx.wait();
    console.log("✅ slisBNB Token transferred:", tx.hash);
  }

  console.log("\n🎉 All tokens transferred successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });