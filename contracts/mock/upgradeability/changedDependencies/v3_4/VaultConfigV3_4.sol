// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// Importing AccessModifiers for role-based access control.
import {AccessModifiers} from "../../../../core/access/AccessModifiers.sol";
// Importing ChecksAndValidations for performing various checks and validations across the system.
import {ChecksAndValidations} from "../../../../core/checks/ChecksAndValidations.sol";

// Importing ErrorLibrary for custom error messages.
import {ErrorLibrary} from "../../../../library/ErrorLibrary.sol";

/**
 * @title VaultConfig
 * @dev Inherits AccessModifiers and ChecksAndValidations to manage vault configurations.
 * Handles initialization and updating of _tokens within the vault. Maintains a list of _tokens
 * associated with the vault and provides mechanisms to update these _tokens securely.
 */
abstract contract VaultConfigV3_4 is AccessModifiers, ChecksAndValidations {
  mapping(address => bool) internal _newMappingUpgrade;
  mapping(address => uint256) internal _otherNewMappingUpgrade;

  // Array storing addresses of underlying _tokens in the vault.
  address[] internal tokens;

  // Addresses of the vault and associated safe module.
  address public vault;
  address public safeModule;

  // Current snapshot ID, used for versioning of token updates.
  uint256 public _currentSnapshotId;
  // Mapping to track tokens provided by asset managers during updates.
  mapping(address => bool) internal _previousToken;

  // Event emitted when public swap/trade is enabled for the vault.
  event PublicSwapEnabled();

  // Events for logging deposit and withdrawal operations.
  event Deposited(
    address indexed portfolio,
    address indexed user,
    uint256 mintedAmount
  );
  event Withdrawn(
    address indexed user,
    uint256 burnedAmount,
    address indexed portfolio
  );

  // Initializes the vault with addresses of the vault and safe module.
  function __VaultConfig_init(address _vault, address _safeModule) internal {
    vault = _vault;
    safeModule = _safeModule;
  }

  /**
   * @dev Initializes the vault with a set of _tokens.
   * @param _tokens Array of token addresses to initialize the vault.
   * Only callable by the super admin. Checks for the maximum asset limit and prevents re-initialization.
   */
  function initToken(address[] calldata _tokens) external onlySuperAdmin {
    uint256 _assetLimit = protocolConfig().assetLimit();
    uint256 tokensLength = _tokens.length;
    if (tokensLength > _assetLimit)
      revert ErrorLibrary.TokenCountOutOfLimit(_assetLimit);
    if (tokens.length != 0) {
      revert ErrorLibrary.AlreadyInitialized();
    }
    for (uint256 i; i < tokensLength; i++) {
      address token = _tokens[i];
      _beforeInitCheck(token);
      if (_previousToken[token]) {
        revert ErrorLibrary.TokenAlreadyExist();
      }
      _previousToken[token] = true;
      tokens.push(token);
    }
    _resetPreviousTokenList(_tokens);
    emit PublicSwapEnabled();
  }

  /**
   * @dev Updates the token list of the vault.
   * Can only be called by the rebalancer contract. Checks for the maximum asset limit.
   * @param _tokens New array of token addresses for the vault.
   */
  function updateTokenList(
    address[] calldata _tokens
  ) external onlyRebalancerContract {
    uint256 _assetLimit = protocolConfig().assetLimit();
    uint256 tokenLength = _tokens.length;

    if (tokenLength > _assetLimit)
      revert ErrorLibrary.TokenCountOutOfLimit(_assetLimit);

    for (uint256 i; i < tokenLength; i++) {
      address token = _tokens[i];
      _beforeInitCheck(token);
      if (_previousToken[token]) {
        revert ErrorLibrary.TokenAlreadyExist();
      }
      _previousToken[token] = true;
    }
    _resetPreviousTokenList(_tokens);
    tokens = _tokens;
  }

  /**
    @dev Resets token state to false for reuse by asset manager.
    @param _tokens Array of _tokens to reset.
  */
  function _resetPreviousTokenList(address[] calldata _tokens) internal {
    uint256 tokensLength = _tokens.length;
    for (uint256 i; i < tokensLength; i++) {
      _previousToken[_tokens[i]] = false;
    }
  }

  /**
    @dev Returns the current list of _tokens in the vault.
    @return Array of token addresses.
  */
  function getTokens() external view returns (address[] memory) {
    return tokens;
  }

  // Reserved storage gap to accommodate potential future layout adjustments.
  uint256[49] private __uint256GapVaultConfig;
}
