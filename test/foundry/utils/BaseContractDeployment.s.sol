// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Script} from "forge-std/Script.sol";

import {PortfolioFactory} from "../../../../contracts/PortfolioFactory.sol";

import {Portfolio} from "../../../../contracts/core/Portfolio.sol";
import {TokenExclusionManager} from "../../../../contracts/core/management/TokenExclusionManager.sol";
import {Rebalancing} from "../../../../contracts/rebalance/Rebalancing.sol";
import {AssetManagementConfig} from "../../../../contracts/config/assetManagement/AssetManagementConfig.sol";

import {FeeModule} from "../../../../contracts/fee/FeeModule.sol";
import {VelvetSafeModule} from "../../../../contracts/vault/VelvetSafeModule.sol";
import {TokenRemovalVault} from "../../../../contracts/vault/TokenRemovalVault.sol";

contract BaseContractDeployment is Script {
  function deployBaseContracts()
    public
    returns (
      address indexFactory,
      address index,
      address tokenExclusionManager,
      address rebalancing,
      address assetManagementConfig,
      address feeModule,
      address tokenRemovalVault,
      address safe
    )
  {
    indexFactory = address(new PortfolioFactory());
    index = address(new Portfolio());
    tokenExclusionManager = address(new TokenExclusionManager());
    rebalancing = address(new Rebalancing());
    assetManagementConfig = address(new AssetManagementConfig());
    feeModule = address(new FeeModule());
    tokenRemovalVault = address(new TokenRemovalVault());
    safe = address(new VelvetSafeModule());
  }
}
