// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {AssetManagerCheck} from "./AssetManagerCheck.sol";
import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {IProtocolConfig} from "../../config/protocol/IProtocolConfig.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

import {IFeeModule} from "../../fee/IFeeModule.sol";

/**
 * @title FeeManagement
 * @notice Manages the configuration and updating of fees within the protocol, such as management, performance, entry, and exit fees.
 * Allows asset managers to propose new fees, which can be updated upon reaching consensus or after a certain period.
 * @dev Utilizes AssetManagerCheck for access control and ensures proposed fees comply with protocol constraints.
 */
abstract contract FeeManagement is AssetManagerCheck, Initializable {
  // Reference to the protocol configuration contract
  IProtocolConfig private protocolConfig;
  // Reference to the fee module contract
  IFeeModule private feeModule;

  // Current active fees
  uint256 public managementFee;
  uint256 public performanceFee;
  uint256 public entryFee;
  uint256 public exitFee;

  // Proposed new fees
  uint256 public newManagementFee;
  uint256 public newPerformanceFee;
  uint256 public newEntryFee;
  uint256 public newExitFee;

  // Timestamps when the new fees were proposed
  uint256 public proposedManagementFeeTime;
  uint256 public proposedPerformanceFeeTime;
  uint256 public proposedEntryAndExitFeeTime;

  // Events for tracking fee management actions
  event ProposeManagementFee(uint256 indexed newManagementFee);
  event ProposePerformanceFee(uint256 indexed newPerformanceFee);
  event ProposeEntryAndExitFee(
    uint256 indexed newEntryFee,
    uint256 indexed newExitFee
  );
  event UpdateManagementFee(uint256 indexed newManagementFee);
  event UpdatePerformanceFee(uint256 indexed newPerformanceFee);
  event UpdateEntryAndExitFee(
    uint256 indexed newEntryFee,
    uint256 indexed newExitFee
  );
  event DeleteProposedManagementFee();
  event DeleteProposedPerformanceFee();
  event DeleteProposedEntryAndExitFee();

  /**
   * @dev Initializes the contract with protocol configuration and sets the initial fees.
   * Validates that the initial fees do not exceed the protocol's maximum allowed values.
   * @param _protocolConfig Address of the protocol configuration contract.
   * @param _managementFee Initial management fee rate.
   * @param _performanceFee Initial performance fee rate.
   * @param _entryFee Initial entry fee rate.
   * @param _exitFee Initial exit fee rate.
   */
  function __FeeManagement_init(
    address _protocolConfig,
    uint256 _managementFee,
    uint256 _performanceFee,
    uint256 _entryFee,
    uint256 _exitFee,
    address _feeModule
  ) internal onlyInitializing {
    if (_protocolConfig == address(0)) revert ErrorLibrary.InvalidAddress();
    protocolConfig = IProtocolConfig(_protocolConfig);

    if (
      _managementFee > protocolConfig.maxManagementFee() ||
      _performanceFee > protocolConfig.maxPerformanceFee() ||
      _entryFee > protocolConfig.maxEntryFee() ||
      _exitFee > protocolConfig.maxExitFee()
    ) revert ErrorLibrary.InvalidFee();

    managementFee = _managementFee;
    performanceFee = _performanceFee;
    entryFee = _entryFee;
    exitFee = _exitFee;
    feeModule = IFeeModule(_feeModule);
  }

  /**
   * @notice Proposes a new management fee, starting a timer for when the change can be finalized.
   * @dev Only callable by the asset manager. Validates against the protocol's maximum fee.
   * @param _newManagementFee The proposed new management fee.
   */
  function proposeNewManagementFee(
    uint256 _newManagementFee
  ) external onlyAssetManager {
    if (_newManagementFee > protocolConfig.maxManagementFee())
      revert ErrorLibrary.InvalidFee();
    newManagementFee = _newManagementFee;
    proposedManagementFeeTime = block.timestamp;
    emit ProposeManagementFee(_newManagementFee);
  }

  /**
   * @notice Deletes the proposed management fee, resetting the proposal.
   * @dev Only callable by the asset manager.
   */
  function deleteProposedManagementFee() external onlyAssetManager {
    if (proposedManagementFeeTime == 0) revert ErrorLibrary.NoNewFeeSet();
    newManagementFee = 0;
    proposedManagementFeeTime = 0;
    emit DeleteProposedManagementFee();
  }

  /**
   * @notice Updates the management fee to the previously proposed fee, after a waiting period.
   * @dev Only callable by the asset manager and after the proposal has matured.
   */
  function updateManagementFee() external onlyAssetManager {
    if (proposedManagementFeeTime == 0) revert ErrorLibrary.NoNewFeeSet();

    if (block.timestamp < (proposedManagementFeeTime + 28 days))
      revert ErrorLibrary.TimePeriodNotOver();

    managementFee = newManagementFee;
    proposedManagementFeeTime = 0;

    feeModule.chargeProtocolAndManagementFees();

    emit UpdateManagementFee(newManagementFee);
  }

  /**
   * @notice Proposes a new performance fee, starting a timer for when the change can be finalized.
   * @dev Only callable by the asset manager. Validates against the protocol's maximum fee.
   * @param _newPerformanceFee The proposed new performance fee.
   */
  function proposeNewPerformanceFee(
    uint256 _newPerformanceFee
  ) external onlyAssetManager {
    if (_newPerformanceFee > protocolConfig.maxPerformanceFee())
      revert ErrorLibrary.InvalidFee();
    newPerformanceFee = _newPerformanceFee;
    proposedPerformanceFeeTime = block.timestamp;
    emit ProposePerformanceFee(_newPerformanceFee);
  }

  /**
   * @notice Deletes the proposed performance fee, resetting the proposal.
   * @dev Only callable by the asset manager.
   */
  function deleteProposedPerformanceFee() external onlyAssetManager {
    if (proposedPerformanceFeeTime == 0) revert ErrorLibrary.NoNewFeeSet();

    newPerformanceFee = 0;
    proposedPerformanceFeeTime = 0;
    emit DeleteProposedPerformanceFee();
  }

  /**
   * @notice Updates the performance fee to the previously proposed fee, after a waiting period.
   * @dev Only callable by the asset manager and after the proposal has matured.
   */
  function updatePerformanceFee() external onlyAssetManager {
    if (proposedPerformanceFeeTime == 0) revert ErrorLibrary.NoNewFeeSet();

    if (block.timestamp < (proposedPerformanceFeeTime + 28 days))
      revert ErrorLibrary.TimePeriodNotOver();

    performanceFee = newPerformanceFee;
    proposedPerformanceFeeTime = 0;

    emit UpdatePerformanceFee(newPerformanceFee);
  }

  /**
   * @notice Proposes new entry and exit fees, starting a timer for when the changes can be finalized.
   * @dev Only callable by the asset manager. Validates against the protocol's maximum fees.
   * @param _newEntryFee The proposed new entry fee.
   * @param _newExitFee The proposed new exit fee.
   */
  function proposeNewEntryAndExitFee(
    uint256 _newEntryFee,
    uint256 _newExitFee
  ) external onlyAssetManager {
    if (
      _newEntryFee > protocolConfig.maxEntryFee() ||
      _newExitFee > protocolConfig.maxExitFee()
    ) revert ErrorLibrary.InvalidFee();
    newEntryFee = _newEntryFee;
    newExitFee = _newExitFee;
    proposedEntryAndExitFeeTime = block.timestamp;
    emit ProposeEntryAndExitFee(_newEntryFee, _newExitFee);
  }

  /**
   * @notice Deletes the proposed entry and exit fees, resetting the proposal.
   * @dev Only callable by the asset manager.
   */
  function deleteProposedEntryAndExitFee() external onlyAssetManager {
    if (proposedEntryAndExitFeeTime == 0) revert ErrorLibrary.NoNewFeeSet();

    newEntryFee = 0;
    newExitFee = 0;
    proposedEntryAndExitFeeTime = 0;
    emit DeleteProposedEntryAndExitFee();
  }

  /**
   * @notice Updates the entry and exit fees to the previously proposed fees, after a waiting period.
   * @dev Only callable by the asset manager and after the proposal has matured.
   */
  function updateEntryAndExitFee() external onlyAssetManager {
    if (proposedEntryAndExitFeeTime == 0) revert ErrorLibrary.NoNewFeeSet();

    if (block.timestamp < (proposedEntryAndExitFeeTime + 28 days))
      revert ErrorLibrary.TimePeriodNotOver();

    entryFee = newEntryFee;
    exitFee = newExitFee;
    proposedEntryAndExitFeeTime = 0;

    emit UpdateEntryAndExitFee(newEntryFee, newExitFee);
  }
}
