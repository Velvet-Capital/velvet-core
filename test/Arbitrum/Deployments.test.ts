import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { chainIdToAddresses } from "../../scripts/networkVariables";
import {
  IERC20Upgradeable__factory,
  ProtocolConfig,
  Rebalancing,
  AccessController,
  AssetManagementConfig,
  FeeModule,
  PriceOracleL2,
} from "../../typechain";

let protocolConfig: ProtocolConfig;
let accessController: AccessController;
let priceOracle: PriceOracleL2;
let owner: SignerWithAddress;
let treasury: SignerWithAddress;
let wbnbAddress: string;
let busdAddress: string;
let daiAddress: string;
let dogeAddress: string;
let linkAddress: string;
let cakeAddress: string;
let usdtAddress: string;
let accounts;
let wethAddress: string;
let btcAddress: string;
let arbAddress: string;
const forkChainId: any = process.env.FORK_CHAINID;
const chainId: any = forkChainId ? forkChainId : 42161;
const addresses = chainIdToAddresses[chainId];
const assetManagerHash = ethers.utils.keccak256(
  ethers.utils.toUtf8Bytes("ASSET_MANAGER"),
);

export type IAddresses = {
  daiAddress: string;
  dogeAddress: string;
  linkAddress: string;
  cakeAddress: string;
  usdtAddress: string;
  wethAddress: string;
  btcAddress: string;
  arbAddress: string;
};

export async function tokenAddresses(addFeed: boolean): Promise<IAddresses> {
  let Iaddress: IAddresses;

  const daiInstance = new ethers.Contract(
    addresses.DAI,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  daiAddress = daiInstance.address;

  const btcInstance = new ethers.Contract(
    addresses.WBTC,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  btcAddress = btcInstance.address;

  const dogeInstance = new ethers.Contract(
    addresses.ADoge,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  dogeAddress = dogeInstance.address;

  const linkInstance = new ethers.Contract(
    addresses.LINK,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  linkAddress = linkInstance.address;

  const cakeInstance = new ethers.Contract(
    addresses.CAKE,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  cakeAddress = cakeInstance.address;

  const usdtInstance = new ethers.Contract(
    addresses.USDT,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  usdtAddress = usdtInstance.address;

  const wethInstance = new ethers.Contract(
    addresses.WETH,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  wethAddress = wethInstance.address;

  const arbInstance = new ethers.Contract(
    addresses.ARB,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  arbAddress = arbInstance.address;

  Iaddress = {
    daiAddress,
    dogeAddress,
    linkAddress,
    cakeAddress,
    usdtAddress,
    wethAddress,
    btcAddress,
    arbAddress,
  };

  if (!addFeed) return Iaddress;

  return Iaddress;
}

before(async () => {
  accounts = await ethers.getSigners();
  [owner, treasury] = accounts;

  const AccessController = await ethers.getContractFactory("AccessController");
  accessController = await AccessController.deploy();
  await accessController.deployed();

  const PriceOracleL2 = await ethers.getContractFactory("PriceOracleL2");
  priceOracle = await PriceOracleL2.deploy(
    addresses.WETH,
    addresses.SequencerUptimeFeed,
  );
  await priceOracle.deployed();

  await priceOracle.setFeeds(
    [
      addresses.WETH,
      addresses.WBTC,
      addresses.ARB,
      "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      addresses.USDT,
      addresses.DAI,
      addresses.USDCe,
      addresses.LINK,
      addresses.ADoge,
      addresses.USDC,
    ],
    [
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
    ],
    [
      "0x639fe6ab55c921f74e7fac1ee960c0b6293ba612",
      "0x6ce185860a4963106506c203335a2910413708e9",
      "0xb2a824043730fe05f3da2efafa1cbbe83fa548d6",
      "0x639fe6ab55c921f74e7fac1ee960c0b6293ba612",
      "0x3f3f5df88dc9f13eac63df89ec16ef6e7e25dde7",
      "0xc5c8e77b397e531b8ec06bfb0048328b30e9ecfb",
      "0x50834f3163758fcc1df9973b6e91f0f0f0434ad3",
      "0x86e53cf1b870786351da77a57575e79cb55812cb",
      "0x9a7fb1b3950837a8d9b40517626e11d4127c098c",
      "0x50834f3163758fcc1df9973b6e91f0f0f0434ad3",
    ],
  );
});

export async function RebalancingDeploy(
  portfolioAddress: string,
  tokenRegistryAddress: string,
  exchangeAddress: string,
  accessController: AccessController,
  ownerAddress: string,
  assetManagementConfig: AssetManagementConfig,
  feeModule: FeeModule,
): Promise<Rebalancing> {
  let rebalancing: Rebalancing;

  const res = await accessController.hasRole(
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    ownerAddress,
  );
  // Grant Portfolio portfolio manager role
  await accessController
    .connect(owner)
    .grantRole(
      "0x1916b456004f332cd8a19679364ef4be668619658be72c17b7e86697c4ae0f16",
      portfolioAddress,
    );

  const Rebalancing = await ethers.getContractFactory("Rebalancing", {});
  rebalancing = await Rebalancing.deploy();
  await rebalancing.deployed();
  rebalancing.init(portfolioAddress, accessController.address);

  // Grant owner asset manager admin role
  await accessController.grantRole(
    "0x15900ee5215ef76a9f5d2b8a5ec2fe469c362cbf4d7bef6646ab417b6d169e88",
    owner.address,
  );

  // Grant owner asset manager role
  await accessController.grantRole(assetManagerHash, owner.address);

  // Grant rebalancing portfolio manager role
  await accessController.grantRole(
    "0x1916b456004f332cd8a19679364ef4be668619658be72c17b7e86697c4ae0f16",
    rebalancing.address,
  );

  // Grant owner super admin
  await accessController.grantRole(
    "0xd980155b32cf66e6af51e0972d64b9d5efe0e6f237dfaa4bdc83f990dd79e9c8",
    owner.address,
  );

  // Granting owner portfolio manager role to swap eth to token
  await accessController.grantRole(
    "0x1916b456004f332cd8a19679364ef4be668619658be72c17b7e86697c4ae0f16",
    owner.address,
  );

  await accessController.grantRole(
    "0x516339d85ab12e7c2454a5a806ee27e82ad851d244092d49dc944d35f3f89061",
    exchangeAddress,
  );

  //Grant rebalancing rebalancer contract role
  await accessController.grantRole(
    "0x8e73530dd444215065cdf478f826e993aeb5e2798587f0bbf5a978bd97df63ea",
    rebalancing.address,
  );

  // grant fee module role for minting
  await accessController.grantRole(
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    feeModule.address,
  );

  return rebalancing;
}

export { protocolConfig, accessController, priceOracle };
