import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { chainIdToAddresses } from "../../scripts/networkVariables";
import {
  IERC20Upgradeable__factory,
  ProtocolConfig,
  AccessController,
  VelvetSafeModule,
  PriceOracle,
} from "../../typechain";

let protocolConfig: ProtocolConfig;
let accessController: AccessController;
let priceOracle: PriceOracle;
let owner: SignerWithAddress;
let treasury: SignerWithAddress;
let wbnbAddress: string;
let busdAddress: string;
let daiAddress: string;
let ethAddress: string;
let btcAddress: string;
let dogeAddress: string;
let linkAddress: string;
let cakeAddress: string;
let usdtAddress: string;
let usdcAddress: string;
let accounts;
let velvetSafeModule: VelvetSafeModule;

const forkChainId: any = process.env.FORK_CHAINID;
const chainId: any = forkChainId ? forkChainId : 56;
const addresses = chainIdToAddresses[chainId];

export type IAddresses = {
  wbnbAddress: string;
  busdAddress: string;
  daiAddress: string;
  ethAddress: string;
  btcAddress: string;
  dogeAddress: string;
  linkAddress: string;
  cakeAddress: string;
  usdtAddress: string;
  usdcAddress: string;
};

export async function tokenAddresses(): Promise<IAddresses> {
  let Iaddress: IAddresses;

  const wbnbInstance = new ethers.Contract(
    addresses.WETH_Address,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  wbnbAddress = wbnbInstance.address;

  const busdInstance = new ethers.Contract(
    addresses.BUSD,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  busdAddress = busdInstance.address;

  const daiInstance = new ethers.Contract(
    addresses.DAI_Address,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  daiAddress = daiInstance.address;

  const ethInstance = new ethers.Contract(
    addresses.ETH_Address,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  ethAddress = ethInstance.address;

  const btcInstance = new ethers.Contract(
    addresses.BTC_Address,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  btcAddress = btcInstance.address;

  const dogeInstance = new ethers.Contract(
    addresses.DOGE_Address,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  dogeAddress = dogeInstance.address;

  const linkInstance = new ethers.Contract(
    addresses.LINK_Address,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  linkAddress = linkInstance.address;

  const cakeInstance = new ethers.Contract(
    addresses.CAKE_Address,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  cakeAddress = cakeInstance.address;

  const usdcInstance = new ethers.Contract(
    addresses.USDC_Address,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  usdcAddress = usdcInstance.address;

  const usdtInstance = new ethers.Contract(
    addresses.USDT,
    IERC20Upgradeable__factory.abi,
    ethers.getDefaultProvider(),
  );
  usdtAddress = usdtInstance.address;

  Iaddress = {
    wbnbAddress,
    busdAddress,
    daiAddress,
    ethAddress,
    btcAddress,
    dogeAddress,
    linkAddress,
    cakeAddress,
    usdtAddress,
    usdcAddress,
  };

  return Iaddress;
}

before(async () => {
  accounts = await ethers.getSigners();
  [owner, treasury] = accounts;

  const provider = ethers.getDefaultProvider();

  const AccessController = await ethers.getContractFactory("AccessController");
  accessController = await AccessController.deploy();
  await accessController.deployed();

  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  priceOracle = await PriceOracle.deploy(
    "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
  );
  await priceOracle.deployed();

  await priceOracle.setFeeds(
    [
      addresses.WBNB,
      addresses.BUSD,
      addresses.DAI_Address,
      addresses.ETH_Address,
      "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c",
      addresses.ETH_Address,
      "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c",
      addresses.BUSD,
      addresses.DOGE_Address,
      addresses.LINK_Address,
      addresses.CAKE_Address,
      addresses.USDT,
      "0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63",
      addresses.USDC_Address,
      addresses.ADA,
      addresses.BAND,
      addresses.DOT,
    ],
    [
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      "0x0000000000000000000000000000000000000348",
      addresses.WBNB,
      addresses.ETH_Address,
      addresses.WBNB,
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
      "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE",
      "0xcBb98864Ef56E9042e7d2efef76141f15731B82f",
      "0x132d3C0B1D2cEa0BC552588063bdBb210FDeecfA",
      "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e",
      "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE",
      "0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf",
      "0x63D407F32Aa72E63C7209ce1c2F5dA40b3AaE726",
      "0xf1769eB4D1943AF02ab1096D7893759F6177D6B8",
      "0x87Ea38c9F24264Ec1Fff41B04ec94a97Caf99941",
      "0x3AB0A0d137D4F946fBB19eecc6e92E64660231C8",
      "0xca236E327F629f9Fc2c30A4E95775EbF0B89fac8",
      "0xB6064eD41d4f67e353768aA239cA86f4F73665a1",
      "0xB97Ad0E74fa7d920791E90258A6E2085088b4320",
      "0xBF63F430A79D4036A5900C19818aFf1fa710f206",
      "0x51597f405303C4377E36123cBc172b13269EA163",
      "0xa767f745331D267c7751297D982b050c93985627",
      "0xC78b99Ae87fF43535b0C782128DB3cB49c74A4d3",
      "0xC333eb0086309a16aa7c8308DfD32c8BBA0a2592",
    ],
  );
});

export { protocolConfig, accessController, priceOracle };
