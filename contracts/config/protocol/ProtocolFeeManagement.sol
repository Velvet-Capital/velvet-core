// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {OwnableCheck} from "./OwnableCheck.sol";

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

/**
 * @title FeeManagement
 * @notice Allows configuration of fees within the platform, including protocol fees and streaming fees.
 * These fees are critical for the platform's economic model and compensating platform operators and participants.
 */
abstract contract ProtocolFeeManagement is OwnableCheck, Initializable {
  uint256 public maxManagementFee;
  uint256 public maxPerformanceFee;
  uint256 public maxEntryFee;
  uint256 public maxExitFee;
  uint256 public protocolFee;
  uint256 public protocolStreamingFee;

  event ProtocolFeeUpdated(uint256 indexed newProtocolFee);
  event ProtocolStreamingFeeUpdated(uint256 indexed newProtocolStreamingFee);

  /**
   * @dev Sets default fee percentages and system limits.
   */
  function __FeeManagement_init() internal onlyInitializing {
    protocolFee = 2500; // 25% of management fee
    protocolStreamingFee = 30; // 0.3% annual
    maxManagementFee = 1000; // 10% annual
    maxPerformanceFee = 3000; // 30% of profit
    maxEntryFee = 500; // 5%
    maxExitFee = 500; // 5%
  }

  function updateProtocolFee(
    uint256 _newProtocolFee
  ) external onlyProtocolOwner {
    if (_newProtocolFee > 5_000 || _newProtocolFee == protocolFee)
      revert ErrorLibrary.InvalidProtocolFee();
    protocolFee = _newProtocolFee;
    emit ProtocolFeeUpdated(_newProtocolFee);
  }

  function updateProtocolStreamingFee(
    uint256 _newProtocolStreamingFee
  ) external onlyProtocolOwner {
    if (
      _newProtocolStreamingFee > 100 ||
      _newProtocolStreamingFee == protocolStreamingFee
    ) revert ErrorLibrary.InvalidProtocolStreamingFee();

    protocolStreamingFee = _newProtocolStreamingFee;
    emit ProtocolStreamingFeeUpdated(_newProtocolStreamingFee);
  }
}
