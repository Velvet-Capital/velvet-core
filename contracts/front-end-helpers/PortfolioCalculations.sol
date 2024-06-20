// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {IPortfolio} from "../core/interfaces/IPortfolio.sol";
import {IFeeModule} from "../fee/IFeeModule.sol";
import {IAssetManagementConfig} from "../config/assetManagement/IAssetManagementConfig.sol";
import {IProtocolConfig} from "../config/protocol/IProtocolConfig.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ErrorLibrary} from "../library/ErrorLibrary.sol";

contract PortfolioCalculations {
  uint256 internal constant ONE_ETH_IN_WEI = 10 ** 18;
  uint256 constant MIN_MINT_FEE = 1_000_000;

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
}
