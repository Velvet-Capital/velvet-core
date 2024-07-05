// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {FunctionParameters} from "../../FunctionParameters.sol";

/**
 * @title IPortfolioFactory
 * @notice Interface for the PortfolioFactory contract, managing the creation and initialization of portfolios.
 */
interface IPortfolioFactory {
  struct PortfoliolInfo {
    address portfolioSwap;
    address tokenExclusionManager;
    address rebalancing;
    address owner;
    address assetManagementConfig;
    address feeModule;
    address vaultAddress;
    address gnosisModule;
  }

  /**
   * @notice Initializes the portfolio factory with the provided initialization data.
   * @param initData The initialization data for the portfolio factory.
   */
  function initialize(
    FunctionParameters.PortfolioFactoryInitData memory initData
  ) external;

  /**
   * @notice Creates a new non-custodial portfolio with the provided initialization data.
   * @param initData The initialization data for the new portfolio.
   */
  function createPortfolioNonCustodial(
    FunctionParameters.PortfolioCreationInitData memory initData
  ) external;

  /**
   * @notice Creates a new custodial portfolio with the provided initialization data.
   * @param initData The initialization data for the new portfolio.
   * @param _owners The list of owners for the custodial portfolio.
   * @param _threshold The threshold for the multisig functionality.
   */
  function createPortfolioCustodial(
    FunctionParameters.PortfolioCreationInitData memory initData,
    address[] memory _owners,
    uint256 _threshold
  ) external;

  /**
   * @notice This function returns the Portfolio address at the given portfolio id
   * @param portfoliofundId Integral id of the portfolio fund whose Portfolio address is to be retrieved
   * @return Return the Portfolio address of the fund
   */
  function getPortfolioList(uint256 portfoliofundId) external returns (address);

  /**
   * @notice Retrieves the information of a portfolio by its ID.
   * @param _portfolioId The ID of the portfolio to retrieve information for.
   * @return The PortfoliolInfo struct containing the portfolio information.
   */
  function PortfolioInfolList(
    uint256 _portfolioId
  ) external returns (PortfoliolInfo memory);

  function whitelistedPortfolioAddress(address) external view returns (bool);
}
