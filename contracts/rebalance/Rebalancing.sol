// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/interfaces/IERC20Upgradeable.sol";
import {ErrorLibrary} from "../library/ErrorLibrary.sol";
import {IIntentHandler} from "../handler/IIntentHandler.sol";
import {RebalancingConfig} from "./RebalancingConfig.sol";
import {FunctionParameters} from "../FunctionParameters.sol";

/**
 * @title RebalancingCore
 * @dev Manages the rebalancing operations for Portfolio contracts, ensuring asset managers can update token weights and swap tokens as needed.
 * Inherits RebalancingConfig for auxiliary functions like checking token balances.
 */
contract Rebalancing is
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable,
  RebalancingConfig
{
  /// @notice Emitted when weights are successfully updated after a swap operation.
  event UpdatedWeights();
  event UpdatedTokens(address[] newTokens);
  event PortfolioTokenRemoved(
    address indexed token,
    address indexed vault,
    uint256 indexed balance,
    uint256 atSnapshotId
  );

  uint256 public constant TOTAL_WEIGHT = 10_000; // Represents 100% in basis points.

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initializes the Rebalancing contract.
   * @param _portfolio Address of the Portfolio contract.
   * @param _accessController Address of the AccessController.
   */
  function init(
    address _portfolio,
    address _accessController
  ) external initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();
    __RebalancingHelper_init(_portfolio, _accessController);
  }

  /**
   * @notice Allows an asset manager to propose new weights for tokens in the portfolio.
   * @param _sellTokens Array of tokens to sell.
   * @param _sellAmounts Corresponding amounts of each token to sell.
   * @param _handler Address of the swap handler.
   * @param _callData Encoded swap call data.
   */
  function updateWeights(
    address[] calldata _sellTokens,
    uint256[] calldata _sellAmounts,
    address _handler,
    bytes memory _callData
  ) external virtual nonReentrant onlyAssetManager {
    // Extra Parameter to define assetManager intent(which token to sell and which to buy) + Check for it
    //Check for not selling the whole amount

    _updateWeights(
      _sellTokens,
      _getCurrentTokens(),
      _sellAmounts,
      _handler,
      _callData
    );

    emit UpdatedWeights();
  }

  /**
   * @dev Internal function to handle the logic of updating weights.
   * @param _sellTokens Tokens to be sold.
   * @param _newTokens New set of tokens after rebalancing.
   * @param _sellAmounts Amounts of each sell token.
   * @param _handler The handler to execute swaps.
   * @param _callData Swap details.
   */
  function _updateWeights(
    address[] calldata _sellTokens,
    address[] memory _newTokens,
    uint256[] calldata _sellAmounts,
    address _handler,
    bytes memory _callData
  ) private protocolNotPaused {
    if (!protocolConfig.isSolver(_handler)) revert ErrorLibrary.InvalidSolver();

    // Pull tokens to be completely removed from portfolio to handler for swapping.
    uint256 sellTokenLength = _sellTokens.length;
    uint256 sellAmountLength = _sellAmounts.length;

    if (sellAmountLength != sellTokenLength) {
      revert ErrorLibrary.InvalidLength();
    }

    for (uint256 i; i < sellTokenLength; i++) {
      address sellToken = _sellTokens[i];
      if (sellToken == address(0)) revert ErrorLibrary.InvalidAddress();
      portfolio.pullFromVault(sellToken, _sellAmounts[i], _handler);
    }

    // Execute the swap using the handler.
    address[] memory ensoBuyTokens = IIntentHandler(_handler)
      .multiTokenSwapAndTransfer(_vault, _callData);

    // Verify that all specified sell tokens have been completely sold by the handler.
    for (uint256 i; i < sellTokenLength; i++) {
      uint256 dustValue = (_sellAmounts[i] *
        protocolConfig.allowedDustTolerance()) / TOTAL_WEIGHT;
      if (_getTokenBalanceOf(_sellTokens[i], _handler) > dustValue)
        revert ErrorLibrary.BalanceOfHandlerShouldNotExceedDust();
    }

    // Ensure that each token bought by the solver is in the portfolio list.
    _verifyNewTokenList(ensoBuyTokens, _newTokens);
  }

  /**
   * @notice Updates the token list and adjusts weights based on provided rebalance data.
   * @dev This function is called by the asset manager to rebalance the portfolio.
   * @param rebalanceData The data required for rebalancing, including tokens to sell, new tokens, sell amounts, handler, and call data.
   */
  function updateTokens(
    FunctionParameters.RebalanceIntent calldata rebalanceData
  ) external virtual nonReentrant onlyAssetManager {
    address[] calldata _sellTokens = rebalanceData._sellTokens;
    address[] calldata _newTokens = rebalanceData._newTokens;
    address[] memory _tokens = _getCurrentTokens();

    //Need a check here to confirm _newTokens has buyTokens in it
    portfolio.updateTokenList(_newTokens);

    // Initialize a bitmap with 256 slots to handle up to 65,536 unique bit positions
    uint256[256] memory tokenBitmap;
    uint256 tokenLength = _tokens.length;
    uint256[] memory initialBalances = new uint256[](tokenLength);

    unchecked{
     // Populate the bitmap with current tokens and store their initial balances
      for (uint256 i; i < tokenLength; i++) {
        address token = _tokens[i];

        // Store the current balance of the token for later verification
        initialBalances[i] = _getTokenBalanceOf(token, _vault);

        // Calculate a unique bit position for this token
        uint256 bitPos = uint256(keccak256(abi.encodePacked(token))) % 65536; // Hash to get a unique bit position in the range 0-65,535
        uint256 index = bitPos / 256; // Determine the specific uint256 slot in the array (0 to 255)
        uint256 offset = bitPos % 256; // Determine the bit position within that uint256 slot (0 to 255)

        // Set the bit for this token in the bitmap to mark it as present
        tokenBitmap[index] |= (1 << offset);
      } 
    }

    // Perform token update and weights adjustment based on provided rebalance data.
    _updateWeights(
      _sellTokens,
      _newTokens,
      rebalanceData._sellAmounts,
      rebalanceData._handler,
      rebalanceData._callData
    );

    unchecked {
      // Populate the bitmap with current tokens and store their initial balances
      for (uint256 i; i < tokenLength; i++) {
        address token = _tokens[i];

        // Store the current balance of the token for later verification
        initialBalances[i] = _getTokenBalanceOf(token, _vault);

        // Calculate a unique bit position for this token
        uint256 bitPos = uint256(keccak256(abi.encodePacked(token))) % 65536; // Hash to get a unique bit position in the range 0-65,535
        uint256 index = bitPos / 256; // Determine the specific uint256 slot in the array (0 to 255)
        uint256 offset = bitPos % 256; // Determine the bit position within that uint256 slot (0 to 255)

        // Set the bit for this token in the bitmap to mark it as present
        tokenBitmap[index] |= (1 << offset);
      }

      // Remove new tokens from the bitmap to avoid unnecessary balance checks
      for (uint256 i; i < _newTokens.length; i++) {
        uint256 bitPos = uint256(keccak256(abi.encodePacked(_newTokens[i]))) %
          65536;
        uint256 index = bitPos / 256;
        uint256 offset = bitPos % 256;

        // Clear the bit for each new token to mark it as excluded from checks
        tokenBitmap[index] &= ~(1 << offset);
      }

      // Verify balances for remaining tokens in the bitmap
      uint256 dustTolerance = protocolConfig.allowedDustTolerance();
      for (uint256 i; i < tokenLength; i++) {
        address token = _tokens[i];

        // Calculate the bit position for this token to verify its presence
        uint256 bitPos = uint256(keccak256(abi.encodePacked(token))) % 65536;
        uint256 index = bitPos / 256;
        uint256 offset = bitPos % 256;

        // Check if the bit for this token is still set in the bitmap
        if ((tokenBitmap[index] & (1 << offset)) != 0) {
          // Calculate the allowable "dust" amount based on the initial balance
          uint256 dustValue = (initialBalances[i] * dustTolerance) /
            TOTAL_WEIGHT;

          // Verify that the token's balance does not exceed the allowable dust tolerance
          if (_getTokenBalanceOf(token, _vault) > dustValue)
            revert ErrorLibrary.NonPortfolioTokenBalanceIsNotZero();
        }
      }
    }

    emit UpdatedTokens(_newTokens);
  }

  /**
   * @notice Removes an portfolio token from the portfolio. Can only be called by the asset manager.
   * @param _token The address of the token to be removed from the portfolio.
   */
  function removePortfolioToken(
    address _token
  ) external onlyAssetManager nonReentrant protocolNotPaused {

    address[] memory currentTokens = _getCurrentTokens();    
    if (!_isPortfolioToken(_token,currentTokens)) revert ErrorLibrary.NotPortfolioToken();

    // Generate a new token list excluding the token to be removed
    uint256 tokensLength = currentTokens.length;
    address[] memory newTokens = new address[](tokensLength - 1);
    uint256 j = 0;
    for (uint256 i; i < tokensLength; i++) {
      address token = currentTokens[i];
      if (token != _token) {
        newTokens[j++] = token;
      }
    }

    portfolio.updateTokenList(newTokens);

    uint256 tokenBalance = IERC20Upgradeable(_token).balanceOf(_vault);
    _tokenRemoval(_token, tokenBalance);
  }

  /**
   * @notice Removes a non-portfolio token from the portfolio. Can only be called by the asset manager.
   * @param _token The address of the token to be removed.
   */
  function removeNonPortfolioToken(
    address _token
  ) external onlyAssetManager protocolNotPaused nonReentrant {
    if (_isPortfolioToken(_token,_getCurrentTokens())) revert ErrorLibrary.IsPortfolioToken();

    uint256 tokenBalance = IERC20Upgradeable(_token).balanceOf(_vault);
    _tokenRemoval(_token, tokenBalance);
  }

  /**
   * @notice Removes a portion of a portfolio token from the portfolio. Can only be called by the asset manager.
   * @param _token The address of the token to be partially removed from the portfolio.
   * @param _percentage The percentage of the token balance to be removed from the portfolio.
   * @dev This function allows the asset manager to remove a specified percentage of a token from the portfolio.
   * It reverts if the token is not part of the portfolio.
   */
  function removePortfolioTokenPartially(
    address _token,
    uint256 _percentage
  ) external onlyAssetManager protocolNotPaused nonReentrant {
    if (!_isPortfolioToken(_token,_getCurrentTokens())) revert ErrorLibrary.NotPortfolioToken();

    uint256 tokenBalanceToRemove = _getTokenBalanceForPartialRemoval(
      _token,
      _percentage
    );

    _tokenRemoval(_token, tokenBalanceToRemove);
  }

  /**
   * @notice Removes a non-portfolio token partially from the portfolio. Can only be called by the asset manager.
   * @param _token The address of the token to be removed.
   */
  function removeNonPortfolioTokenPartially(
    address _token,
    uint256 _percentage
  ) external onlyAssetManager protocolNotPaused nonReentrant {
    if (_isPortfolioToken(_token,_getCurrentTokens())) revert ErrorLibrary.IsPortfolioToken();

    uint256 tokenBalanceToRemove = _getTokenBalanceForPartialRemoval(
      _token,
      _percentage
    );

    _tokenRemoval(_token, tokenBalanceToRemove);
  }

  function _getTokenBalanceForPartialRemoval(
    address _token,
    uint256 _percentage
  ) internal view returns (uint256 tokenBalanceToRemove) {
    if (_percentage >= TOTAL_WEIGHT)
      revert ErrorLibrary.InvalidTokenRemovalPercentage();

    uint256 tokenBalance = IERC20Upgradeable(_token).balanceOf(_vault);
    tokenBalanceToRemove = (tokenBalance * _percentage) / TOTAL_WEIGHT;
  }

  /**
   * @dev Handles the removal of a token and transfers its balance out of the vault.
   * @param _token The address of the token to be removed.
   */
  function _tokenRemoval(address _token, uint256 _tokenBalance) internal {
    if (_tokenBalance == 0) revert ErrorLibrary.BalanceOfVaultIsZero();

    // Snapshot for record-keeping before removing the token
    uint256 currentId = tokenExclusionManager.snapshot();

    // Deploy a new token removal vault for the token to remove
    address tokenRemovalVault = tokenExclusionManager.deployTokenRemovalVault();

    // Transfer the token balance from the vault to the token exclusion manager
    portfolio.pullFromVault(_token, _tokenBalance, tokenRemovalVault);

    // Record the removal details in the token exclusion manager
    tokenExclusionManager.setTokenAndSupplyRecord(
      currentId - 1,
      _token,
      tokenRemovalVault,
      portfolio.totalSupply()
    );

    // Log the token removal event
    emit PortfolioTokenRemoved(
      _token,
      tokenRemovalVault,
      _tokenBalance,
      currentId - 1
    );
  }

  /**
   * @dev This function allows the asset manager to claim reward tokens, which might be accumulated
   * from various activities like staking, liquidity provision, or participation in DeFi protocols.
   * The function ensures the safety and correctness of the operation by verifying that the
   * reward token's balance in the vault increases as a result of the claim. It also checks
   * that no other token balances in the vault have been unexpectedly reduced, which could
   * indicate an issue such as a bug in the target contract or malicious interference.
   *
   * Before executing the claim, the function stores the current balances of all tokens in the vault.
   * After executing the claim via a call to an external contract, it checks the new balances.
   * If the reward token's balance does not increase or if any other token's balance decreases,
   * the transaction is reverted to prevent potential losses.
   *
   * @param _tokenToBeClaimed The address of the reward token that the asset manager aims to claim.
   * @param _target The contract address that will process the claim. This contract is expected to
   * hold the reward logic and tokens.
   * @param _claimCalldata The calldata necessary to execute the claim function on the target contract.
   * This includes the method signature and parameters for the claim operation.
   */

  function claimRewardTokens(
    address _tokenToBeClaimed,
    address _target,
    bytes memory _claimCalldata
  ) external onlyAssetManager protocolNotPaused nonReentrant {
    if (!protocolConfig.isRewardTargetEnabled(_target))
      revert ErrorLibrary.RewardTargetNotEnabled();

    // Retrieve the list of all tokens in the portfolio and their balances before the claim operation
    address[] memory tokens = portfolio.getTokens();
    uint256[] memory tokenBalancesInVaultBefore = getTokenBalancesOf(
      tokens,
      _vault
    );

    uint256 rewardTokenBalanceBefore = _getTokenBalanceOf(
      _tokenToBeClaimed,
      _vault
    );

    // Execute the claim operation using the provided calldata on the target contract
    portfolio.claimRewardTokens(_target, _claimCalldata);

    uint256[] memory tokenBalancesInVaultAfter = getTokenBalancesOf(
      tokens,
      _vault
    );

    // Fetch the new balance of the reward token in the vault after the claim operation
    uint256 rewardTokenBalanceAfter = _getTokenBalanceOf(
      _tokenToBeClaimed,
      _vault
    );

    // Ensure the reward token balance has increased, otherwise revert the transaction
    if (rewardTokenBalanceAfter <= rewardTokenBalanceBefore)
      revert ErrorLibrary.ClaimFailed();

    // Check that no other token balances have decreased, ensuring the integrity of the vault's assets
    uint256 tokensLength = tokens.length;
    for (uint256 i; i < tokensLength; i++) {
      if (tokenBalancesInVaultAfter[i] < tokenBalancesInVaultBefore[i])
        revert ErrorLibrary.ClaimFailed();
    }
  }

  /**
   * @notice Authorizes contract upgrade by the contract owner.
   * @param _newImplementation Address of the new contract implementation.
   */
  function _authorizeUpgrade(
    address _newImplementation
  ) internal override onlyOwner {
    // Intentionally left empty as required by an abstract contract
  }

  /**
   * @notice Modifier to restrict function if protocol is paused.
   * Uses the `isProtocolPaused` function to determine the protocol pause status.
   * @dev Reverts with a ProtocolIsPaused error if the protocol is paused.
   */
  modifier protocolNotPaused() {
    if (protocolConfig.isProtocolPaused())
      revert ErrorLibrary.ProtocolIsPaused();
    _; // Continues function execution if the protocol is not paused
  }
}