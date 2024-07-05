// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {IPortfolio} from "../core/interfaces/IPortfolio.sol";
import {ITokenExclusionManager} from "../core/interfaces/ITokenExclusionManager.sol";
import {IFeeModule} from "../fee/IFeeModule.sol";
import {IAssetManagementConfig} from "../config/assetManagement/IAssetManagementConfig.sol";
import {IProtocolConfig} from "../config/protocol/IProtocolConfig.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IPriceOracle} from "../../contracts/oracle/IPriceOracle.sol";

import {ErrorLibrary} from "../library/ErrorLibrary.sol";

contract PortfolioCalculations {
  uint256 internal constant ONE_ETH_IN_WEI = 10 ** 18;
  uint256 constant MIN_MINT_FEE = 1_000_000;
  uint256 public constant TOTAL_WEIGHT = 10_000;

  function getTokenBalancesAndDecimals(
    address _portfolio
  ) public view returns (uint256[] memory, uint8[] memory) {
    require(_portfolio != address(0), "Invalid portfolio address");

    IPortfolio portfolio = IPortfolio(_portfolio);
    address vault = portfolio.vault();
    address[] memory tokens = portfolio.getTokens();
    uint256[] memory tokenBalances = new uint256[](tokens.length);
    uint8[] memory tokenDecimals = new uint8[](tokens.length);
    if (portfolio.totalSupply() > 0) {
      for (uint256 i = 0; i < tokens.length; i++) {
        tokenBalances[i] = IERC20Upgradeable(tokens[i]).balanceOf(vault);
        tokenDecimals[i] = IERC20MetadataUpgradeable(tokens[i]).decimals();
      }
      return (tokenBalances, tokenDecimals);
    } else {
      return (new uint256[](0), new uint8[](0));
    }
  }

  function getPortfolioData(
    address _portfolio
  )
    public
    view
    returns (
      uint256[] memory tokenAmountArray,
      uint8[] memory tokenDecimalArray,
      address[] memory indexTokens,
      uint256 totalSupply
    )
  {
    require(_portfolio != address(0), "Invalid portfolio address");

    IPortfolio portfolio = IPortfolio(_portfolio);

    (tokenAmountArray, tokenDecimalArray) = getTokenBalancesAndDecimals(
      _portfolio
    );
    indexTokens = portfolio.getTokens();
    totalSupply = portfolio.totalSupply();
  }

  function getPortfolioDataByte(
    address _portfolio
  ) external view returns (bytes memory) {
    require(_portfolio != address(0), "Invalid portfolio address");

    (
      uint256[] memory tokenAmountArray,
      uint8[] memory tokenDecimalArray,
      address[] memory indexTokens,
      uint256 totalSupply
    ) = getPortfolioData(_portfolio);

    return
      abi.encode(tokenAmountArray, tokenDecimalArray, indexTokens, totalSupply);
  }

  function getExpectedMintAmount(
    address _portfolio,
    uint256 _userShare
  ) external view returns (uint256) {
    require(_portfolio != address(0), "Invalid portfolio address");
    require(_userShare > 0 && _userShare < 10_000, "Invalid user share");

    IPortfolio portfolio = IPortfolio(_portfolio);

    uint256 totalSupply = portfolio.totalSupply();
    IFeeModule _feeModule = IFeeModule(portfolio.feeModule());
    uint256 expectedMintAmount = (_userShare * totalSupply) / (1 - _userShare);

    uint256 entryFee = _feeModule.entryFee();
    if (entryFee > 0) {
      expectedMintAmount = (expectedMintAmount * (1e4 - entryFee)) / 1e4;
    }

    return expectedMintAmount;
  }

  /**
   * @dev This function takes value of portfolio token amounts from user as input and returns the lowest amount possible to deposit to get the exact ratio of token amounts
   * @notice This function is helper function for user to get the correct amount/ratio of tokens to deposit
   * @param userAmounts array of amounts of portfolio tokens
   */
  function getUserAmountToDeposit(
    uint256[] memory userAmounts,
    address _portfolio
  ) external view returns (uint256[] memory, uint256 _desiredShare) {
    IPortfolio portfolio = IPortfolio(_portfolio);

    uint256[] memory vaultBalance = portfolio.getTokenBalancesOf(
      portfolio.getTokens(),
      portfolio.vault()
    );
    uint256 vaultTokenLength = vaultBalance.length;

    // Validate that none of the vault balances are zero
    for (uint256 i = 0; i < vaultTokenLength; i++) {
      if (vaultBalance[i] == 0) revert ErrorLibrary.BalanceOfVaultIsZero();
    }

    // Validate that the lengths of the input arrays match
    if (userAmounts.length != vaultTokenLength)
      revert ErrorLibrary.InvalidLength();

    uint256[] memory newAmounts = new uint256[](vaultTokenLength);
    uint256 leastPercentage = (userAmounts[0] * ONE_ETH_IN_WEI) /
      vaultBalance[0];
    _desiredShare =
      (userAmounts[0] * ONE_ETH_IN_WEI) /
      (vaultBalance[0] + userAmounts[0]);
    for (uint256 i = 1; i < vaultTokenLength; i++) {
      uint256 tempPercentage = (userAmounts[i] * ONE_ETH_IN_WEI) /
        vaultBalance[i];
      if (leastPercentage > tempPercentage) {
        leastPercentage = tempPercentage;
        _desiredShare =
          (userAmounts[i] * ONE_ETH_IN_WEI) /
          (vaultBalance[i] + userAmounts[i]);
      }
    }
    for (uint256 i; i < vaultTokenLength; i++) {
      newAmounts[i] = (vaultBalance[i] * leastPercentage) / ONE_ETH_IN_WEI;
    }
    return (newAmounts, _desiredShare);
  }

  /**
   * @dev This function takes portfolioAmount and returns the expected amounts of portfolio token, considering management fee and exit fee
   * @notice This function is helper function for user to get the expected amount of portfolio tokens
   * @param _portfolioTokenAmount amount of vault token
   */
  function getWithdrawalAmounts(
    uint256 _portfolioTokenAmount,
    address _portfolio
  ) external view returns (uint256[] memory) {
    IPortfolio portfolio = IPortfolio(_portfolio);

    address[] memory tokens = portfolio.getTokens();
    uint256 tokensLength = tokens.length;
    address _vault = portfolio.vault();

    uint256[] memory withdrawalAmount = new uint256[](tokensLength);

    IFeeModule _feeModule = IFeeModule(portfolio.feeModule());

    IAssetManagementConfig _assetManagementConfig = IAssetManagementConfig(
      portfolio.assetManagementConfig()
    );

    IProtocolConfig _protocolConfig = IProtocolConfig(
      portfolio.protocolConfig()
    );

    uint256 _userPortfolioTokenAmount = _portfolioTokenAmount;
    uint256 totalSupplyPortfolio = portfolio.totalSupply();

    (uint256 assetManagerFeeToMint, uint256 protocolFeeToMint) = _getFeeAmount(
      _assetManagementConfig,
      _protocolConfig,
      _feeModule,
      totalSupplyPortfolio
    );

    totalSupplyPortfolio = _modifyTotalSupply(
      assetManagerFeeToMint,
      protocolFeeToMint,
      totalSupplyPortfolio
    );

    uint256 afterFeeAmount = _userPortfolioTokenAmount;
    if (_assetManagementConfig.exitFee() > 0) {
      uint256 entryOrExitFee = _calculateEntryOrExitFee(
        _assetManagementConfig.exitFee(),
        _userPortfolioTokenAmount
      );
      (uint256 protocolFee, uint256 assetManagerFee) = _splitFee(
        entryOrExitFee,
        _protocolConfig.protocolFee()
      );
      if (protocolFee > MIN_MINT_FEE) {
        afterFeeAmount -= protocolFee;
      }
      if (assetManagerFee > MIN_MINT_FEE) {
        afterFeeAmount -= assetManagerFee;
      }
    }

    for (uint256 i = 0; i < tokensLength; i++) {
      address _token = tokens[i];
      // Calculate the proportion of each token to return based on the burned portfolio tokens.
      uint256 tokenBalance = IERC20Upgradeable(_token).balanceOf(_vault);
      tokenBalance = (tokenBalance * afterFeeAmount) / totalSupplyPortfolio;

      if (tokenBalance == 0) revert();

      withdrawalAmount[i] = tokenBalance;
      // Transfer each token's proportional amount from the vault to the user.
    }
    return withdrawalAmount;
  }

  function _calculateEntryOrExitFee(
    uint256 _feePercentage,
    uint256 _tokenAmount
  ) internal pure returns (uint256) {
    return (_tokenAmount * _feePercentage) / 10_000;
  }

  function _splitFee(
    uint256 _feeAmount,
    uint256 _protocolFeePercentage
  ) internal pure returns (uint256 protocolFeeAmount, uint256 assetManagerFee) {
    if (_feeAmount == 0) {
      return (0, 0);
    }
    protocolFeeAmount = (_feeAmount * _protocolFeePercentage) / 10_000;
    assetManagerFee = _feeAmount - protocolFeeAmount;
  }

  function _calculateProtocolAndManagementFeesToMint(
    uint256 _managementFeePercentage,
    uint256 _protocolFeePercentage,
    uint256 _protocolStreamingFeePercentage,
    uint256 _totalSupply,
    uint256 _lastChargedManagementFee,
    uint256 _lastChargedProtocolFee,
    uint256 _currentTime
  )
    internal
    pure
    returns (uint256 managementFeeToMint, uint256 protocolFeeToMint)
  {
    // Calculate the mint amount for asset management streaming fees
    uint256 managementStreamingFeeToMint = _calculateMintAmountForStreamingFees(
      _totalSupply,
      _lastChargedManagementFee,
      _managementFeePercentage,
      _currentTime
    );

    // Calculate the mint amount for protocol streaming fees
    uint256 protocolStreamingFeeToMint = _calculateMintAmountForStreamingFees(
      _totalSupply,
      _lastChargedProtocolFee,
      _protocolStreamingFeePercentage,
      _currentTime
    );

    // Calculate the protocol's cut from the management streaming fee
    uint256 protocolCut;
    (protocolCut, managementFeeToMint) = _splitFee(
      managementStreamingFeeToMint,
      _protocolFeePercentage
    );

    // The total protocol fee to mint is the sum of the protocol's cut from the management fee plus the protocol streaming fee
    protocolFeeToMint = protocolCut + protocolStreamingFeeToMint;

    return (managementFeeToMint, protocolFeeToMint);
  }

  function _calculateMintAmountForStreamingFees(
    uint256 _totalSupply,
    uint256 _lastChargedTime,
    uint256 _feePercentage,
    uint256 _currentTime
  ) internal pure returns (uint256 tokensToMint) {
    if (_lastChargedTime >= _currentTime) {
      return 0;
    }

    uint256 streamingFees = _calculateStreamingFee(
      _totalSupply,
      _lastChargedTime,
      _feePercentage,
      _currentTime
    );

    // Calculates the share of the asset manager after minting
    uint256 feeReceiverShare = (streamingFees * ONE_ETH_IN_WEI) / _totalSupply;

    tokensToMint = _calculateMintAmount(feeReceiverShare, _totalSupply);
  }

  function _calculateStreamingFee(
    uint256 _totalSupply,
    uint256 _lastChargedTime,
    uint256 _feePercentage,
    uint256 _currentTime
  ) internal pure returns (uint256 streamingFee) {
    uint256 timeElapsed = _currentTime - _lastChargedTime;
    streamingFee =
      (_totalSupply * _feePercentage * timeElapsed) /
      365 days /
      10_000;
  }

  function _calculateMintAmount(
    uint256 _userShare,
    uint256 _totalSupply
  ) internal pure returns (uint256) {
    return (_userShare * _totalSupply) / ((10 ** 18) - _userShare);
  }

  function _modifyTotalSupply(
    uint256 _assetManagerFeeToMint,
    uint256 _protocolFeeToMint,
    uint256 totalSupply
  ) internal pure returns (uint256) {
    if (_assetManagerFeeToMint > MIN_MINT_FEE) {
      totalSupply += _assetManagerFeeToMint;
    }
    if (_protocolFeeToMint > MIN_MINT_FEE) {
      totalSupply += _protocolFeeToMint;
    }
    return totalSupply;
  }

  //Get Protocol And Management Fee
  function getProtocolAndManagementFee(
    address _portfolio
  )
    public
    view
    returns (uint256 assetManagerFeeToMint, uint256 protocolFeeToMint)
  {
    IPortfolio portfolio = IPortfolio(_portfolio);
    IFeeModule _feeModule = IFeeModule(portfolio.feeModule());

    IAssetManagementConfig _assetManagementConfig = IAssetManagementConfig(
      portfolio.assetManagementConfig()
    );

    IProtocolConfig _protocolConfig = IProtocolConfig(
      portfolio.protocolConfig()
    );

    uint256 totalSupplyPortfolio = portfolio.totalSupply();

    (assetManagerFeeToMint, protocolFeeToMint) = _getFeeAmount(
      _assetManagementConfig,
      _protocolConfig,
      _feeModule,
      totalSupplyPortfolio
    );

    if (assetManagerFeeToMint < MIN_MINT_FEE) {
      assetManagerFeeToMint = 0;
    }
    if (protocolFeeToMint < MIN_MINT_FEE) {
      protocolFeeToMint = 0;
    }
  }

  //Get Performance Fee
  function getPerformanceFee(
    address _portfolio
  ) public view returns (uint256 protocolFee, uint256 assetManagerFee) {
    IPortfolio portfolio = IPortfolio(_portfolio);

    IProtocolConfig _protocolConfig = IProtocolConfig(
      portfolio.protocolConfig()
    );

    uint256 totalSupply = portfolio.totalSupply();

    IFeeModule _feeModule = IFeeModule(portfolio.feeModule());

    IAssetManagementConfig _assetManagementConfig = IAssetManagementConfig(
      portfolio.assetManagementConfig()
    );

    uint256 vaultBalance = portfolio.getVaultValueInUSD(
      IPriceOracle(_protocolConfig.oracle()),
      portfolio.getTokens(),
      totalSupply,
      portfolio.vault()
    );
    uint256 currentPrice = _getCurrentPrice(vaultBalance, totalSupply);

    uint256 performanceFee = _calculatePerformanceFeeToMint(
      currentPrice,
      _feeModule.highWatermark(),
      totalSupply,
      vaultBalance,
      _assetManagementConfig.performanceFee()
    );

    (protocolFee, assetManagerFee) = _splitFee(
      performanceFee,
      _protocolConfig.protocolFee()
    );

    if (protocolFee < MIN_MINT_FEE) {
      protocolFee = 0;
    }
    if (assetManagerFee < MIN_MINT_FEE) {
      assetManagerFee = 0;
    }
  }

  function _getCurrentPrice(
    uint256 _vaultBalance,
    uint256 _totalSupply
  ) internal pure returns (uint256 currentPrice) {
    currentPrice = _totalSupply == 0
      ? 0
      : (_vaultBalance * ONE_ETH_IN_WEI) / _totalSupply;
  }

  function _calculatePerformanceFeeToMint(
    uint256 _currentPrice,
    uint256 _highWaterMark,
    uint256 _totalSupply,
    uint256 _vaultBalance,
    uint256 _feePercentage
  ) internal pure returns (uint256 tokensToMint) {
    if (_currentPrice <= _highWaterMark) {
      return 0; // No fee if current price is below or equal to high watermark
    }

    uint256 performanceIncrease = _currentPrice - _highWaterMark;
    uint256 performanceFee = ((performanceIncrease *
      _totalSupply *
      _feePercentage) * ONE_ETH_IN_WEI) / TOTAL_WEIGHT;

    tokensToMint =
      (performanceFee * _totalSupply) /
      (_vaultBalance - performanceFee);
  }

  function _getFeeAmount(
    IAssetManagementConfig _assetManagementConfig,
    IProtocolConfig _protocolConfig,
    IFeeModule _feeModule,
    uint256 totalSupplyPortfolio
  )
    internal
    view
    returns (uint256 assetManagerFeeToMint, uint256 protocolFeeToMint)
  {
    uint256 _managementFee = _assetManagementConfig.managementFee();
    uint256 _protocolFee = _protocolConfig.protocolFee();
    uint256 _protocolStreamingFee = _protocolConfig.protocolStreamingFee();

    (
      assetManagerFeeToMint,
      protocolFeeToMint
    ) = _calculateProtocolAndManagementFeesToMint(
      _managementFee,
      _protocolFee,
      _protocolStreamingFee,
      totalSupplyPortfolio,
      _feeModule.lastChargedManagementFee(),
      _feeModule.lastChargedProtocolFee(),
      block.timestamp
    );
  }

  function getUserTokenClaimBalance(
    address _portfolio,
    address user,
    uint256 startId,
    uint256 endId
  ) external view returns (uint256[] memory) {
    IPortfolio portfolio = IPortfolio(_portfolio);
    ITokenExclusionManager tokenExclusionManager = ITokenExclusionManager(
      portfolio.tokenExclusionManager()
    );

    uint256 _currentId = tokenExclusionManager._currentSnapshotId();

    // If there are less than two snapshots, no tokens have been removed
    if (_currentId < 2) revert ErrorLibrary.NoTokensRemoved();

    if (startId > endId || endId >= _currentId) revert ErrorLibrary.InvalidId();

    //Adding 1 to endId, to run loop till endId
    uint256 _lastId = endId + 1;

    uint256[] memory claimBalances = new uint256[](_lastId - startId);
    uint256 i = 0;

    for (uint256 id = startId; id < _lastId; id++) {
      (bool isValid, uint256 balance) = tokenExclusionManager.getDataAtId(
        user,
        id
      );
      if (isValid && balance > 0) {
        (
          address token,
          address vault,
          uint256 _totalSupply
        ) = tokenExclusionManager.removedToken(id);
        // Calculate the user's share of the removed token
        uint256 currentVaultBalance = IERC20Upgradeable(token).balanceOf(vault);
        uint256 _balance = (currentVaultBalance * balance) / _totalSupply;
        claimBalances[i] = _balance;
      } else {
        claimBalances[i] = 0;
      }
      i++;
    }
    return claimBalances;
  }
}
