// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// Import interfaces for various configurations and modules.
import {IAssetManagementConfig} from "../../config/assetManagement/IAssetManagementConfig.sol";
import {IProtocolConfig} from "../../config/protocol/IProtocolConfig.sol";
import {IFeeModule} from "../../fee/IFeeModule.sol";

/**
 * @title Dependencies
 * @dev Abstract contract providing a framework for accessing configurations and modules across the platform.
 * This contract defines virtual functions to be implemented by inheriting contracts for accessing shared resources,
 * such as configuration settings and fee mechanisms.
 */
abstract contract Dependencies {
  /**
   * @notice Virtual function to retrieve the asset management configuration interface.
   * @dev This function should be overridden in derived contracts to return the the Portfolio Contract.
   * @return The interface of the asset management configuration contract.
   */
  function assetManagementConfig()
    public
    view
    virtual
    returns (IAssetManagementConfig);

  /**
   * @notice Virtual function to retrieve the protocol configuration interface.
   * @dev This function should be overridden in derived contracts to return the Portfolio Contract.
   * @return The interface of the protocol configuration contract.
   */
  function protocolConfig() public view virtual returns (IProtocolConfig);

  /**
   * @notice Virtual function to retrieve the fee module interface.
   * @dev This function should be overridden in derived contracts to return the Portfolio Contract.
   * @return The interface of the fee module contract.
   */
  function feeModule() public view virtual returns (IFeeModule);
}
