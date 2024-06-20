// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

contract FeeEvents {
  event FeesToBeMinted(
    address indexed assetManagementTreasury,
    address indexed protocolTreasury,
    uint256 indexed protocolFeeAmount,
    uint256 managerFeeAmount
  );

  event ManagementFeeCalculated(
    uint256 indexed protocolStreamingFeeAmount,
    uint256 indexed managementFeeAmount,
    uint256 indexed protocolFeeCutAmount
  );

  event EntryExitFeeCharged(
    uint256 indexed entryExitProtocolFeeAmount,
    uint256 indexed entryExitAssetManagerFeeAmount
  );

  event PerformanceFeeCalculated(
    uint256 indexed performanceFeeProtocolAmount,
    uint256 indexed performanceFeeAssetManagerAmount,
    uint256 indexed currentPrice
  );
}
