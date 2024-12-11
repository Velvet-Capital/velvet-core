// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../library/ErrorLibrary.sol";

import {IPortfolio} from "../core/interfaces/IPortfolio.sol";
import {IAccessController} from "../access/IAccessController.sol";
import {IProtocolConfig} from "../config/protocol/IProtocolConfig.sol";
import {IAssetManagementConfig} from "../config/assetManagement/IAssetManagementConfig.sol";

import {ITokenExclusionManager} from "../core/interfaces/ITokenExclusionManager.sol";

import {AccessRoles} from "../access/AccessRoles.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

import {TokenBalanceLibrary} from "../core/calculations/TokenBalanceLibrary.sol";

/**
 * @title RebalancingConfig
 * @notice Provides auxiliary functions to support the RebalancingCore contract operations, including balance checks and validator checks.
 * @dev This contract includes helper functions for rebalancing operations such as validating handler, checking token balances, and initial setup.
 */

contract RebalancingConfig is AccessRoles, Initializable, TokenBalanceLibrary {
  IPortfolio public portfolio;
  IAccessController public accessController;
  IProtocolConfig public protocolConfig;
  IAssetManagementConfig public assetManagementConfig;
  ITokenExclusionManager internal tokenExclusionManager;
  address internal _vault;

  /**
   * @notice Initializes the contract with portfolio, access controller, protocol and asset management configuration.
   * @param _portfolio Address of the Portfolio contract.
   * @param _accessController Address of the AccessController.
   */
  function __RebalancingHelper_init(
    address _portfolio,
    address _accessController
  ) internal onlyInitializing {
    if (_portfolio == address(0) || _accessController == address(0))
      revert ErrorLibrary.InvalidAddress();

    portfolio = IPortfolio(_portfolio);
    accessController = IAccessController(_accessController);
    protocolConfig = IProtocolConfig(portfolio.protocolConfig());
    assetManagementConfig = IAssetManagementConfig(
      portfolio.assetManagementConfig()
    );
    tokenExclusionManager = ITokenExclusionManager(
      portfolio.tokenExclusionManager()
    );
    _vault = portfolio.vault();
  }

  /**
   * @dev Ensures that the function is only called by an asset manager.
   */
  modifier onlyAssetManager() {
    if (!accessController.hasRole(ASSET_MANAGER, msg.sender)) {
      revert ErrorLibrary.CallerNotAssetManager();
    }
    _;
  }

  /**
   * @notice Verifies that a list of tokens is present and has non-zero balances.
   * @dev Uses a 256-slot bitmap to efficiently track up to 65,536 unique token addresses.
   *      Each token address is mapped to a unique bit position in the bitmap using keccak256 hashing.
   * @param _ensoBuyTokens Array of tokens expected to be present in the bitmap.
   * @param _newTokens Array of new tokens to validate and mark in the bitmap.
   */
  function _verifyNewTokenList(
    address[] memory _ensoBuyTokens,
    address[] memory _newTokens
  ) internal view {
    // Initialize a bitmap with 256 slots to handle up to 65,536 unique bit positions
    uint256[256] memory tokenBitmap;

    unchecked {
      // Mark each token in _newTokens in the bitmap and ensure non-zero balance
      for (uint256 i; i < _newTokens.length; i++) {
        address token = _newTokens[i];

        // Verify that the token balance is non-zero
        if (_getTokenBalanceOf(token, _vault) == 0)
          revert ErrorLibrary.BalanceOfVaultCannotNotBeZero(token);

        // Calculate a unique bit position for this token
        uint256 bitPos = uint256(keccak256(abi.encodePacked(token))) % 65536; // Hash to get a unique bit position in the range 0-65,535
        uint256 index = bitPos / 256; // Determine the specific uint256 slot in the array (0 to 255)
        uint256 offset = bitPos % 256; // Determine the bit position within that uint256 slot (0 to 255)

        // Set the bit in the bitmap for this token
        tokenBitmap[index] |= (1 << offset);
      }

      // Verify that each token in _ensoBuyTokens is marked in the bitmap
      for (uint256 i; i < _ensoBuyTokens.length; i++) {
        uint256 bitPos = uint256(
          keccak256(abi.encodePacked(_ensoBuyTokens[i]))
        ) % 65536;
        uint256 index = bitPos / 256;
        uint256 offset = bitPos % 256;

        // Check if the bit for this token is set; if not, revert
        if ((tokenBitmap[index] & (1 << offset)) == 0) {
          revert ErrorLibrary.InvalidBuyTokenList();
        }
      }
    }
  }

  /**
   * @notice The function is used to get tokens from portfolio
   * @return Array of token returned
   */
  function _getCurrentTokens() internal view returns (address[] memory) {
    return portfolio.getTokens();
  }

  /**
   * @notice Checks if a token is part of the current portfolio token list.
   * @param _token The address of the token to check.
   * @return bool Returns true if the token is part of the portfolio, false otherwise.
   */
  function _isPortfolioToken(
    address _token,
    address[] memory currentTokens
  ) internal pure returns (bool) {
    bool result;
    assembly {
      // Get the length of the currentTokens array
      let len := mload(currentTokens)

      // Get the pointer to the start of the array data
      let dataPtr := add(currentTokens, 0x20)

      // Loop through the array
      for {
        let i := 0
      } lt(i, len) {
        i := add(i, 1)
      } {
        // Check if the current token matches _token
        if eq(mload(add(dataPtr, mul(i, 0x20))), _token) {
          // If found, set result to true
          result := 1
          // Break the loop
          i := len
        }
      }
    }
    return result;
  }
}
