// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Script} from "forge-std/Script.sol";
import {Addresses} from "./Addresses.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ProtocolConfig} from "../../../contracts/config/protocol/ProtocolConfig.sol";
import {IProtocolConfig} from "../../../contracts/config/protocol/IProtocolConfig.sol";

contract ProtocolConfigDeployment is Script, Addresses {
  ERC1967Proxy protocolConfig;

  address velvetTreasury;
  address priceOracle;

  constructor(address _velvetTreasury, address _priceOracle) {
    velvetTreasury = _velvetTreasury;
    priceOracle = _priceOracle;
  }

  function deployProtocolConfig() public returns (address) {
    address protocolConfigBase = address(new ProtocolConfig());

    protocolConfig = new ERC1967Proxy(
      protocolConfigBase,
      abi.encodeWithSelector(
        ProtocolConfig.initialize.selector,
        3000000000000000000,
        120000000000000000000000,
        address(this), // to be changed
        BSC_WBNB
      )
    );

    IProtocolConfig(address(protocolConfig)).setCoolDownPeriod(10800); // 3h

    return address(protocolConfig);
  }
}
