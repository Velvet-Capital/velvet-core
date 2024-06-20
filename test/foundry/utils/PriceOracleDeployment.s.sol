// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Script} from "forge-std/Script.sol";

import {PriceOracle} from "../../..//contracts/oracle/PriceOracle.sol";

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

import {Addresses} from "./Addresses.sol";

contract PriceOracleDeployment is Script, Addresses {
  PriceOracle priceOracle;

  function addBaseTokens() internal {
    address[] memory baseAddresses = new address[](17);
    baseAddresses[0] = BSC_WBNB;
    baseAddresses[1] = BSC_BUSD;
    baseAddresses[2] = BSC_DAI;
    baseAddresses[3] = BSC_ETH;
    baseAddresses[4] = BSC_ETH_DEFAULT;
    baseAddresses[5] = BSC_BTC;
    baseAddresses[6] = BSC_DOGE;
    baseAddresses[7] = BSC_ETH;
    baseAddresses[8] = BSC_BTC;
    baseAddresses[9] = BSC_BUSD;
    baseAddresses[10] = BSC_ADA;
    baseAddresses[11] = BSC_BUSDT;
    baseAddresses[12] = BSC_BAND;
    baseAddresses[13] = BSC_CAKE;
    baseAddresses[14] = BSC_DOT;
    baseAddresses[15] = BSC_LINK;
    baseAddresses[16] = BSC_XVS;

    address[] memory quoteAddresses = new address[](17);
    quoteAddresses[0] = USD;
    quoteAddresses[1] = USD;
    quoteAddresses[2] = USD;
    quoteAddresses[3] = USD;
    quoteAddresses[4] = USD;
    quoteAddresses[5] = USD;
    quoteAddresses[6] = USD;
    quoteAddresses[7] = BSC_WBNB;
    quoteAddresses[8] = BSC_ETH;
    quoteAddresses[9] = BSC_WBNB;
    quoteAddresses[10] = USD;
    quoteAddresses[11] = USD;
    quoteAddresses[12] = USD;
    quoteAddresses[13] = USD;
    quoteAddresses[14] = USD;
    quoteAddresses[15] = USD;
    quoteAddresses[16] = USD;

    AggregatorV2V3Interface[]
      memory aggregatorAddresses = new AggregatorV2V3Interface[](17);
    aggregatorAddresses[0] = AggregatorV2V3Interface(
      0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
    );
    aggregatorAddresses[1] = AggregatorV2V3Interface(
      0xcBb98864Ef56E9042e7d2efef76141f15731B82f
    );
    aggregatorAddresses[2] = AggregatorV2V3Interface(
      0x132d3C0B1D2cEa0BC552588063bdBb210FDeecfA
    );
    aggregatorAddresses[3] = AggregatorV2V3Interface(
      0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e
    );
    aggregatorAddresses[4] = AggregatorV2V3Interface(
      0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
    );
    aggregatorAddresses[5] = AggregatorV2V3Interface(
      0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf
    );
    aggregatorAddresses[6] = AggregatorV2V3Interface(
      0x3AB0A0d137D4F946fBB19eecc6e92E64660231C8
    );
    aggregatorAddresses[7] = AggregatorV2V3Interface(
      0x63D407F32Aa72E63C7209ce1c2F5dA40b3AaE726
    );
    aggregatorAddresses[8] = AggregatorV2V3Interface(
      0xf1769eB4D1943AF02ab1096D7893759F6177D6B8
    );
    aggregatorAddresses[9] = AggregatorV2V3Interface(
      0x87Ea38c9F24264Ec1Fff41B04ec94a97Caf99941
    );
    aggregatorAddresses[10] = AggregatorV2V3Interface(
      0xa767f745331D267c7751297D982b050c93985627
    );
    aggregatorAddresses[11] = AggregatorV2V3Interface(
      0xcBb98864Ef56E9042e7d2efef76141f15731B82f
    );
    aggregatorAddresses[12] = AggregatorV2V3Interface(
      0xC78b99Ae87fF43535b0C782128DB3cB49c74A4d3
    );
    aggregatorAddresses[13] = AggregatorV2V3Interface(
      0xB6064eD41d4f67e353768aA239cA86f4F73665a1
    );
    aggregatorAddresses[14] = AggregatorV2V3Interface(
      0xC333eb0086309a16aa7c8308DfD32c8BBA0a2592
    );
    aggregatorAddresses[15] = AggregatorV2V3Interface(
      0xca236E327F629f9Fc2c30A4E95775EbF0B89fac8
    );
    aggregatorAddresses[16] = AggregatorV2V3Interface(
      0xBF63F430A79D4036A5900C19818aFf1fa710f206
    );

    priceOracle.setFeeds(baseAddresses, quoteAddresses, aggregatorAddresses);
  }

  function deployPriceOracle() public returns (PriceOracle) {
    vm.startPrank(msg.sender);

    priceOracle = new PriceOracle(BSC_WBNB);

    addBaseTokens();

    vm.stopPrank();

    return priceOracle;
  }
}
