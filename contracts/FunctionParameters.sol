// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

/**
 * @title FunctionParameters
 * @notice A library for defining structured data passed across functions in DeFi protocols.
 * @dev This library encapsulates various structures used for initializing, configuring, and managing on-chain financial products.
 */
library FunctionParameters {
  /**
   * @notice Struct for initializing a new PortfolioFactory
   * @dev Encapsulates data necessary for deploying an PortfolioFactory and associated components.
   * @param _basePortfolioAddress Base Portfolio contract address for cloning
   * @param _baseTokenExclusionManagerAddress Base Token Exclusion address for cloning
   * @param _baseRebalancingAddress Base Rebalancing module address for cloning
   * @param _baseAssetManagementConfigAddress Base AssetManagement Config address for cloning
   * @param _feeModuleImplementationAddress Fee Module implementation contract address
   * @param  _baseTokenRemovalVaultImplementation Token Removal Vault implementation contract address
   * @param _baseVelvetGnosisSafeModuleAddress Base Gnosis-Safe module address for cloning
   * @param _gnosisSingleton Gnosis Singleton contract address
   * @param _gnosisFallbackLibrary Gnosis Fallback Library address
   * @param _gnosisMultisendLibrary Gnosis Multisend Library address
   * @param _gnosisSafeProxyFactory Gnosis Safe Proxy Factory address
   * @param _protocolConfig Protocol configuration contract address
   * @param _velvetProtocolFee Protocol fee percentage (in basis points)
   */
  struct PortfolioFactoryInitData {
    address _basePortfolioAddress;
    address _baseTokenExclusionManagerAddress;
    address _baseRebalancingAddres;
    address _baseAssetManagementConfigAddress;
    address _feeModuleImplementationAddress;
    address _baseTokenRemovalVaultImplementation;
    address _baseVelvetGnosisSafeModuleAddress;
    address _gnosisSingleton;
    address _gnosisFallbackLibrary;
    address _gnosisMultisendLibrary;
    address _gnosisSafeProxyFactory;
    address _protocolConfig;
  }

  /**
   * @notice Data for initializing the Portfolio module
   * @dev Used when setting up a new Portfolio instance.
   * @param _name Name of the Portfolio Fund
   * @param _symbol Symbol of the Portfolio Fund
   * @param _vault Vault address associated with the Portfolio Fund
   * @param _module Safe module address associated with the Portfolio Fund
   * @param _accessController Access Controller address for managing roles
   * @param _protocolConfig Protocol configuration contract address
   * @param _assetManagementConfig Asset Management configuration contract address
   * @param _feeModule Fee Module contract address
   */
  struct PortfolioInitData {
    string _name;
    string _symbol;
    address _vault;
    address _module;
    address _tokenExclusionManager;
    address _accessController;
    address _protocolConfig;
    address _assetManagementConfig;
    address _feeModule;
  }

  /**
   * @notice Data for initializing a new Portfolio Fund via the Factory
   * @dev Encapsulates settings and configurations for a newly created Portfolio Fund.
   * @param _assetManagerTreasury Treasury address for asset manager fee accumulation
   * @param _whitelistedTokens Array of token addresses permitted in the Portfolio Fund
   * @param _managementFee Management fee (annual, in basis points)
   * @param _performanceFee Performance fee (upon profit, in basis points)
   * @param _entryFee Fee for entering the fund (in basis points)
   * @param _exitFee Fee for exiting the fund (in basis points)
   * @param _initialPortfolioAmount Initial amount of the portfolio token
   * @param _minPortfolioTokenHoldingAmount Minimum amount of portfolio tokens that can be held and can be minted
   * @param _public Indicates if the fund is open to the public
   * @param _transferable Indicates if the fund's tokens are transferable
   * @param _transferableToPublic Indicates if the fund's tokens are transferable to the public
   * @param _whitelistTokens Indicates if only whitelisted tokens can be included in the fund
   * @param _name Name of the Portfolio Fund
   * @param _symbol Symbol of the Portfolio Fund
   */
  struct PortfolioCreationInitData {
    address _assetManagerTreasury;
    address[] _whitelistedTokens;
    uint256 _managementFee;
    uint256 _performanceFee;
    uint256 _entryFee;
    uint256 _exitFee;
    uint256 _initialPortfolioAmount;
    uint256 _minPortfolioTokenHoldingAmount;
    bool _public;
    bool _transferable;
    bool _transferableToPublic;
    bool _whitelistTokens;
    string _name;
    string _symbol;
  }

  /**
   * @notice Data for initializing the Asset Manager Config
   * @dev Used for setting up asset management configurations for an Portfolio Fund.
   * @param _managementFee Annual management fee (in basis points)
   * @param _performanceFee Performance fee (upon profit, in basis points)
   * @param _entryFee Entry fee (in basis points)
   * @param _exitFee Exit fee (in basis points)
   * @param _initialPortfolioAmount Initial amount of the portfolio token
   * @param _minPortfolioTokenHoldingAmount Minimum amount of portfolio tokens that can be held and can be minted
   * @param _protocolConfig Protocol configuration contract address
   * @param _accessController Access Controller contract address
   * @param _assetManagerTreasury Treasury address for asset manager fee accumulation
   * @param _whitelistedTokens Array of token addresses permitted in the Portfolio Fund
   * @param _publicPortfolio Indicates if the portfolio is open to public deposits
   * @param _transferable Indicates if the portfolio's tokens are transferable
   * @param _transferableToPublic Indicates if the portfolio's tokens are transferable to the public
   * @param _whitelistTokens Indicates if only whitelisted tokens can be included in the portfolio
   */
  struct AssetManagementConfigInitData {
    uint256 _managementFee;
    uint256 _performanceFee;
    uint256 _entryFee;
    uint256 _exitFee;
    uint256 _initialPortfolioAmount;
    uint256 _minPortfolioTokenHoldingAmount;
    address _protocolConfig;
    address _accessController;
    address _feeModule;
    address _assetManagerTreasury;
    address[] _whitelistedTokens;
    bool _publicPortfolio;
    bool _transferable;
    bool _transferableToPublic;
    bool _whitelistTokens;
  }

  /**
   * @notice Data structure for setting up roles during Portfolio Fund creation
   * @dev Used for assigning roles to various components of the Portfolio Fund ecosystem.
   * @param _portfolio Portfolio contract address
   * @param _protocolConfig Protocol configuration contract address
   * @param _portfolioCreator Address of the portfolio creator
   * @param _rebalancing Rebalancing module contract address
   * @param _feeModule Fee Module contract address
   */
  struct AccessSetup {
    address _portfolio;
    address _portfolioCreator;
    address _rebalancing;
    address _feeModule;
  }

  /**
   * @notice Struct for defining a rebalance intent
   * @dev Encapsulates the intent data for performing a rebalance operation.
   * @param _newTokens Array of new token addresses to be included in the Portfolio Fund
   * @param _sellTokens Array of token addresses to be sold during the rebalance
   * @param _sellAmounts Corresponding amounts of each token to sell
   * @param _handler Address of the intent handler for executing rebalance
   * @param _callData Encoded call data for the rebalance operation
   */
  struct RebalanceIntent {
    address[] _newTokens;
    address[] _sellTokens;
    uint256[] _sellAmounts;
    address _handler;
    bytes _callData;
  }

  /**
   * @notice Struct of batchHandler data
   * @dev Encapsulates the data needed to batch transaction.
   * @param _minMintAmount The minimum amount of portfolio tokens the user expects to receive for their deposit, protecting against slippage
   * @param _depositAmount Amount to token to swap to vailt tokens
   * @param _target Adress of portfolio contract to deposit
   * @param _depositToken Address of token that needed to be swapped
   * @param _callData Encoded call data for swap operation
   */
  struct BatchHandler {
    uint256 _minMintAmount;
    uint256 _depositAmount;
    address _target;
    address _depositToken;
    bytes[] _callData;
  }

  /**
   * @dev Struct to encapsulate the parameters required for deploying a Safe and its associated modules.
   * @param _gnosisSingleton Address of the Safe singleton contract.
   * @param _gnosisSafeProxyFactory Address of the Safe Proxy Factory contract.
   * @param _gnosisMultisendLibrary Address of the Multisend library contract.
   * @param _gnosisFallbackLibrary Address of the Fallback library contract.
   * @param _baseGnosisModule Address of the base module to be used.
   * @param _owners Array of addresses to be designated as owners of the Safe.
   * @param _threshold Number of owner signatures required to execute a transaction in the Safe.
   */
  struct SafeAndModuleDeploymentParams {
    address _gnosisSingleton;
    address _gnosisSafeProxyFactory;
    address _gnosisMultisendLibrary;
    address _gnosisFallbackLibrary;
    address _baseGnosisModule;
    address[] _owners;
    uint256 _threshold;
  }
}
