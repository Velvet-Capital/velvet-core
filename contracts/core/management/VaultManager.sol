// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/token/ERC20/IERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/security/ReentrancyGuardUpgradeable.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import {IVelvetSafeModule} from "../../vault/IVelvetSafeModule.sol";

import {IPortfolio} from "../interfaces/IPortfolio.sol";

import {FeeManager} from "./FeeManager.sol";
import {VaultConfig, ErrorLibrary} from "../config/VaultConfig.sol";
import {VaultCalculations, Dependencies} from "../calculations/VaultCalculations.sol";
import {MathUtils} from "../calculations/MathUtils.sol";
import {PortfolioToken} from "../token/PortfolioToken.sol";
import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";

/**
 * @title VaultManager
 * @dev Extends functionality for managing deposits and withdrawals in the vault.
 * Combines configurations, calculations, fee handling, and token operations.
 */
abstract contract VaultManager is
  VaultConfig,
  VaultCalculations,
  FeeManager,
  PortfolioToken,
  ReentrancyGuardUpgradeable
{
  IAllowanceTransfer public immutable permit2 =
    IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

  /**
   * @notice Initializes the VaultManager contract.
   * @dev This function sets up the ReentrancyGuard by calling its initializer. It's designed to be called
   *      during the contract initialization process to ensure that the non-reentrant modifier can be used
   *      safely in functions to prevent reentrancy attacks. This is a standard part of setting up contracts
   *      that handle external calls or token transfers, providing an additional layer of security.
   */
  function __VaultManager_init() internal onlyInitializing {
    __ReentrancyGuard_init();
  }

  /**
   * @notice Allows the sender to deposit tokens into the fund through a multi-token deposit.
   *         The deposited tokens are added to the vault, and the user is minted portfolio tokens representing their share.
   * @param depositAmounts An array of amounts corresponding to each token the user wishes to deposit.
   * @param _minMintAmount The minimum amount of portfolio tokens the user expects to receive for their deposit, protecting against slippage.
   * @param _permit Batch permit data for token allowance.
   * @param _signature Signature corresponding to the permit batch.
   * @dev This function facilitates the process for the sender to deposit multiple tokens into the vault.
   *      It updates the vault and mints new portfolio tokens for the user.
   *      The nonReentrant modifier is used to prevent reentrancy attacks.
   */
  function multiTokenDeposit(
    uint256[] calldata depositAmounts,
    uint256 _minMintAmount,
    IAllowanceTransfer.PermitBatch calldata _permit,
    bytes calldata _signature
  ) external virtual nonReentrant {
    _multiTokenDepositWithPermit(
      msg.sender,
      depositAmounts,
      _minMintAmount,
      _permit,
      _signature
    );
  }

  /**
   * @notice Allows a specified depositor to deposit tokens into the fund through a multi-token deposit.
   *         The deposited tokens are added to the vault, and the user is minted portfolio tokens representing their share.
   * @param _depositFor The address of the user the deposit is being made for.
   * @param depositAmounts An array of amounts corresponding to each token the user wishes to deposit.
   * @param _minMintAmount The minimum amount of portfolio tokens the user expects to receive for their deposit, protecting against slippage.
   * @dev This function ensures that the depositor is making a multi-token deposit on behalf of another user.
   *      It handles the deposit process, updates the vault, and mints new portfolio tokens for the user.
   *      The nonReentrant modifier is used to prevent reentrancy attacks.
   */
  function multiTokenDepositFor(
    address _depositFor,
    uint256[] calldata depositAmounts,
    uint256 _minMintAmount
  ) external virtual nonReentrant {
    _multiTokenDeposit(_depositFor, depositAmounts, _minMintAmount);
  }

  /**
   * @notice Allows an approved user to withdraw portfolio tokens on behalf of another user.
   * @param _withdrawFor The address of the user for whom the withdrawal is being made.
   * @param _tokenReceiver The address of the user who receives the withdrawn tokens.
   * @param _portfolioTokenAmount The amount of portfolio tokens to withdraw.
   */
  function multiTokenWithdrawalFor(
    address _withdrawFor,
    address _tokenReceiver,
    uint256 _portfolioTokenAmount
  ) external virtual nonReentrant {
    _spendAllowance(_withdrawFor, msg.sender, _portfolioTokenAmount);
    _multiTokenWithdrawal(_withdrawFor, _tokenReceiver, _portfolioTokenAmount);
  }

  /**
   * @notice Allows users to withdraw their deposit from the fund, receiving the underlying tokens.
   * @param _portfolioTokenAmount The amount of portfolio tokens to withdraw.
   */
  function multiTokenWithdrawal(
    uint256 _portfolioTokenAmount
  ) external virtual nonReentrant {
    _multiTokenWithdrawal(msg.sender, msg.sender, _portfolioTokenAmount);
  }

  /**
   * @notice Allows the rebalancer contract to pull tokens from the vault.
   * @dev Wrapper function for `_pullFromVault` ensuring only the rebalancer contract can call it.
   * @param _token The token to be pulled from the vault.
   * @param _amount The amount of the token to pull.
   * @param _to The destination address for the tokens.
   */
  function pullFromVault(
    address _token,
    uint256 _amount,
    address _to
  ) external onlyRebalancerContract {
    _pullFromVault(_token, _amount, _to);
  }

  /**
   * @dev Claims rewards for a target address by executing a transfer through the safe module.
   * Only the rebalancer contract is allowed to call this function.
   * @param _target The address where the rewards are claimed from
   * @param _claimCalldata The calldata to be used for the claim.
   */
  function claimRewardTokens(
    address _target,
    bytes memory _claimCalldata
  ) external onlyRebalancerContract {
    // Execute the transfer through the safe module and check for success
    (, bytes memory data) = IVelvetSafeModule(safeModule).executeWallet(
      _target,
      _claimCalldata
    );

    // Ensure the transfer was successful; revert if not
    if (!(data.length == 0 || abi.decode(data, (bool)))) {
      revert ErrorLibrary.ClaimFailed();
    }
  }

  /**
   * @notice Internal function to handle the multi-token deposit logic.
   * @param _depositFor The address of the user the deposit is being made for.
   * @param depositAmounts An array of amounts corresponding to each token the user wishes to deposit.
   * @param _minMintAmount The minimum amount of portfolio tokens the user expects to receive for their deposit, protecting against slippage.
   * @param _permit Batch permit data for token allowance.
   * @param _signature Signature corresponding to the permit batch.
   */
  function _multiTokenDepositWithPermit(
    address _depositFor,
    uint256[] calldata depositAmounts,
    uint256 _minMintAmount,
    IAllowanceTransfer.PermitBatch calldata _permit,
    bytes calldata _signature
  ) internal virtual {
    if (_permit.spender != address(this)) revert ErrorLibrary.InvalidSpender();

    // Verify that the user is allowed to deposit and that the system is not paused.
    _beforeDepositCheck(_depositFor, tokens.length);
    // Charge any applicable fees.
    _chargeFees(_depositFor);

    // Process the multi-token deposit, adjusting for vault token ratios.
    uint256 _depositRatio = _multiTokenTransferWithPermit(
      depositAmounts,
      _permit,
      _signature,
      msg.sender
    );
    _depositAndMint(_depositFor, _minMintAmount, _depositRatio);
  }

  /**
   * @notice Internal function to handle the multi-token deposit logic.
   * @param _depositFor The address of the user the deposit is being made for.
   * @param depositAmounts An array of amounts corresponding to each token the user wishes to deposit.
   * @param _minMintAmount The minimum amount of portfolio tokens the user expects to receive for their deposit, protecting against slippage.
   */
  function _multiTokenDeposit(
    address _depositFor,
    uint256[] calldata depositAmounts,
    uint256 _minMintAmount
  ) internal virtual {
    // Verify that the user is allowed to deposit and that the system is not paused.
    _beforeDepositCheck(_depositFor, tokens.length);
    // Charge any applicable fees.
    _chargeFees(_depositFor);

    // Process the multi-token deposit, adjusting for vault token ratios.
    uint256 _depositRatio = _multiTokenTransfer(msg.sender, depositAmounts);
    _depositAndMint(_depositFor, _minMintAmount, _depositRatio);
  }

  /**
   * @notice Handles the deposit and minting process for a given user.
   * @param _depositFor The address for which the deposit is made.
   * @param _minMintAmount The minimum amount of portfolio tokens to mint for the user.
   * @param _depositRatio The ratio used to calculate the amount of tokens to mint based on the deposit.
   */
  function _depositAndMint(
    address _depositFor,
    uint256 _minMintAmount,
    uint256 _depositRatio
  ) internal {
    uint256 _totalSupply = totalSupply();

    uint256 tokenAmount;

    // If the total supply is zero, this is the first deposit, and tokens are minted based on the initial amount.
    if (_totalSupply == 0) {
      tokenAmount = assetManagementConfig().initialPortfolioAmount();
      // Reset the high watermark to zero if it's not the first deposit.
      feeModule().updateHighWaterMark(0);
    } else {
      // Calculate the amount of portfolio tokens to mint based on the deposit.
      tokenAmount = _getTokenAmountToMint(_depositRatio, _totalSupply);
    }

    // Ensure the minted amount meets the user's minimum expectation to mitigate slippage.
    _verifyUserMintedAmount(tokenAmount, _minMintAmount);

    // Mint the calculated portfolio tokens to the user, applying any cooldown periods.
    tokenAmount = _mintTokenAndSetCooldown(_depositFor, tokenAmount);

    uint256 userBalanceAfterDeposit = balanceOf(_depositFor);
    // Notify listeners of the deposit event.
    emit Deposited(
      address(this),
      _depositFor,
      tokenAmount,
      userBalanceAfterDeposit
    );
  }

  /**
   * @notice Internal function to handle the multi-token withdrawal logic.
   * @param _withdrawFor The address of the user making the withdrawal.
   * @param _portfolioTokenAmount The amount of portfolio tokens to burn for withdrawal.
   */
  function _multiTokenWithdrawal(
    address _withdrawFor,
    address _tokenReceiver,
    uint256 _portfolioTokenAmount
  ) internal virtual {
    // Perform pre-withdrawal checks, including balance and cooldown verification.
    _beforeWithdrawCheck(
      _withdrawFor,
      IPortfolio(address(this)),
      _portfolioTokenAmount
    );
    // Validate the cooldown period of the user.
    _checkCoolDownPeriod(_withdrawFor);

    // Charge any applicable fees before withdrawal.
    _chargeFees(_withdrawFor);

    // Calculate the total supply of portfolio tokens for proportion calculations.
    uint256 totalSupplyPortfolio = totalSupply();
    // Burn the user's portfolio tokens and calculate the adjusted withdrawal amount post-fees.
    _portfolioTokenAmount = _burnWithdraw(_withdrawFor, _portfolioTokenAmount);

    // Retrieve the list of tokens currently in the portfolio.
    address[] memory portfolioTokens = tokens;
    // Calculate and transfer each token's proportional amount back to the user.
    uint256 portfolioTokenLength = portfolioTokens.length;
    //Array to store, users withdrawal amounts
    uint256[] memory userWithdrawalAmounts = new uint256[](
      portfolioTokenLength
    );
    for (uint256 i; i < portfolioTokenLength; i++) {
      address _token = portfolioTokens[i];
      // Calculate the proportion of each token to return based on the burned portfolio tokens.
      uint256 tokenBalance = _getTokenBalanceOf(_token, vault);
      tokenBalance =
        (tokenBalance * _portfolioTokenAmount) /
        totalSupplyPortfolio;

      if (tokenBalance == 0) revert ErrorLibrary.WithdrawalAmountIsSmall();

      userWithdrawalAmounts[i] = tokenBalance;
      // Transfer each token's proportional amount from the vault to the user.
      _pullFromVault(_token, tokenBalance, _tokenReceiver);
    }

    uint256 userBalanceAfterWithdrawal = balanceOf(_withdrawFor);

    // Notify listeners of the withdrawal event.
    emit Withdrawn(
      _withdrawFor,
      _portfolioTokenAmount,
      address(this),
      userBalanceAfterWithdrawal,
      userWithdrawalAmounts
    );
  }

  /**
   * @notice Transfers specified token amount from the vault to a given address.
   * @dev Executes a token transfer via the VelvetSafeModule, ensuring secure transaction execution.
   * @param _token The token address to transfer.
   * @param _amount The amount of tokens to transfer.
   * @param _to The recipient address of the tokens.
   */
  function _pullFromVault(
    address _token,
    uint256 _amount,
    address _to
  ) internal {
    // Prepare the data for ERC20 token transfer
    bytes memory inputData = abi.encodeWithSelector(
      IERC20Upgradeable.transfer.selector,
      _to,
      _amount
    );

    // Execute the transfer through the safe module and check for success
    (, bytes memory data) = IVelvetSafeModule(safeModule).executeWallet(
      _token,
      inputData
    );

    // Ensure the transfer was successful; revert if not
    if (!(data.length == 0 || abi.decode(data, (bool)))) {
      revert ErrorLibrary.TransferFailed();
    }
  }

  /**
   * @notice Transfers tokens from the user to the vault using permit2 transferfrom.
   * @dev Utilizes `TransferHelper` for secure token transfer from user to vault.
   * @param _token Address of the token to be transferred.
   * @param _depositAmount Amount of the token to be transferred.
   */
  function _transferToVaultWithPermit(
    address _from,
    address _token,
    uint256 _depositAmount
  ) internal {
    permit2.transferFrom(_from, vault, uint160(_depositAmount), _token);
  }

  /**
   * @notice Transfers tokens from the user to the vault.
   * @dev Utilizes `TransferHelper` for secure token transfer from user to vault.
   * @param _token Address of the token to be transferred.
   * @param _depositAmount Amount of the token to be transferred.
   */
  function _transferToVault(
    address _from,
    address _token,
    uint256 _depositAmount
  ) internal {
    TransferHelper.safeTransferFrom(_token, _from, vault, _depositAmount);
  }

  /**
   * @notice Processes multi-token deposits by calculating the minimum deposit ratio.
   * @dev Ensures that the deposited token amounts align with the current vault token ratios.
   * @param depositAmounts Array of amounts for each token the user wants to deposit.
   * @return The minimum deposit ratio after deposits.
   */
  function _multiTokenTransferWithPermit(
    uint256[] calldata depositAmounts,
    IAllowanceTransfer.PermitBatch calldata _permit,
    bytes calldata _signature,
    address _from
  ) internal returns (uint256) {
    // Validate deposit amounts and get initial token balances
    (
      uint256 amountLength,
      address[] memory portfolioTokens,
      uint256[] memory tokenBalancesBefore
    ) = _validateAndGetBalances(depositAmounts);

    permit2.permit(msg.sender, _permit, _signature);

    // Handles the token transfer and minRatio calculations
    return
      _handleTokenTransfer(
        _from,
        amountLength,
        depositAmounts,
        portfolioTokens,
        tokenBalancesBefore,
        true
      );
  }

  /**
   * @notice Processes multi-token deposits by calculating the minimum deposit ratio.
   * @dev Ensures that the deposited token amounts align with the current vault token ratios.
   * @param depositAmounts Array of amounts for each token the user wants to deposit.
   * @return The minimum deposit ratio after deposits.
   */
  function _multiTokenTransfer(
    address _from,
    uint256[] calldata depositAmounts
  ) internal returns (uint256) {
    // Validate deposit amounts and get initial token balances
    (
      uint256 amountLength,
      address[] memory portfolioTokens,
      uint256[] memory tokenBalancesBefore
    ) = _validateAndGetBalances(depositAmounts);

    // Handles the token transfer and minRatio calculations
    return
      _handleTokenTransfer(
        _from,
        amountLength,
        depositAmounts,
        portfolioTokens,
        tokenBalancesBefore,
        false
      );
  }

  /**
   * @notice Validates deposit amounts and retrieves initial token balances.
   * @param depositAmounts Array of deposit amounts for each token.
   * @return amountLength The length of the deposit amounts array.
   * @return portfolioTokens Array of portfolio tokens.
   * @return tokenBalancesBefore Array of token balances before transfer.
   */
  function _validateAndGetBalances(
    uint256[] calldata depositAmounts
  ) internal view returns (uint256, address[] memory, uint256[] memory) {
    uint256 amountLength = depositAmounts.length;
    address[] memory portfolioTokens = tokens;

    // Validate the deposit amounts match the number of tokens in the vault
    if (amountLength != portfolioTokens.length) {
      revert ErrorLibrary.InvalidDepositInputLength();
    }

    // Get current token balances in the vault for ratio calculations
    uint256[] memory tokenBalancesBefore = getTokenBalancesOf(
      portfolioTokens,
      vault
    );

    return (amountLength, portfolioTokens, tokenBalancesBefore);
  }

  /**
   * @notice Handles the token transfer and minRatio calculations.
   * @param _from Address from which tokens are transferred.
   * @param amountLength The length of the deposit amounts array.
   * @param depositAmounts Array of deposit amounts for each token.
   * @param portfolioTokens Array of portfolio tokens.
   * @param tokenBalancesBefore Array of token balances before transfer.
   * @param usePermit Boolean flag to use permit for transfer.
   * @return The minimum ratio after transfer.
   */
  function _handleTokenTransfer(
    address _from,
    uint256 amountLength,
    uint256[] calldata depositAmounts,
    address[] memory portfolioTokens,
    uint256[] memory tokenBalancesBefore,
    bool usePermit
  ) internal returns (uint256) {
    //Array to store deposited amouts of user
    uint256[] memory depositedAmounts = new uint256[](amountLength);

    // If the vault is empty, accept the deposits and return zero as the initial ratio
    if (totalSupply() == 0) {
      for (uint256 i; i < amountLength; i++) {
        uint256 depositAmount = depositAmounts[i];
        depositedAmounts[i] = depositAmount;
        if (depositAmount == 0) revert ErrorLibrary.AmountCannotBeZero();
        if (usePermit) {
          _transferToVaultWithPermit(_from, portfolioTokens[i], depositAmount);
        } else {
          _transferToVault(_from, portfolioTokens[i], depositAmount);
        }
      }
      return 0;
    }

    // Calculate the minimum ratio to maintain proportional token balances in the vault
    uint256 _minRatio = _getDepositToVaultBalanceRatio(
      depositAmounts[0],
      tokenBalancesBefore[0]
    );
    for (uint256 i = 1; i < amountLength; i++) {
      uint256 _currentRatio = _getDepositToVaultBalanceRatio(
        depositAmounts[i],
        tokenBalancesBefore[i]
      );
      _minRatio = MathUtils._min(_currentRatio, _minRatio);
    }

    uint256 transferAmount;
    uint256 _minRatioAfterTransfer = type(uint256).max;
    // Adjust token deposits to match the minimum ratio and update the vault balances
    for (uint256 i; i < amountLength; i++) {
      address token = portfolioTokens[i];
      uint256 tokenBalanceBefore = tokenBalancesBefore[i];
      transferAmount = (_minRatio * tokenBalanceBefore) / ONE_ETH_IN_WEI;
      depositedAmounts[i] = transferAmount;
      if (usePermit) {
        _transferToVaultWithPermit(_from, token, transferAmount);
      } else {
        _transferToVault(_from, token, transferAmount);
      }

      _minRatioAfterTransfer = _getMinDepositToVaultBalanceRatio(
        tokenBalanceBefore,
        _getTokenBalanceOf(token, vault),
        _minRatioAfterTransfer
      );
    }
    emit UserDepositedAmounts(depositedAmounts);
    return _minRatioAfterTransfer;
  }
}
