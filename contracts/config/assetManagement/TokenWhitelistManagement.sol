// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {AssetManagerCheck} from "./AssetManagerCheck.sol";
import {IProtocolConfig} from "../../config/protocol/IProtocolConfig.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

/**
 * @title TokenWhitelistManagement
 * @dev Manages the whitelisting of tokens, determining which tokens are authorized for use within the system.
 * This enables control over the tokens that can participate in the platform, enhancing security and compliance.
 */
abstract contract TokenWhitelistManagement is AssetManagerCheck, Initializable {
  // Reference to the protocol configuration contract
  IProtocolConfig private protocolConfig;

  // Mapping to track whitelisted tokens.
  mapping(address => bool) public whitelistedTokens;

  // Flag to indicate if token whitelisting is enabled.
  bool public tokenWhitelistingEnabled;

  // Events for logging changes to the whitelist.
  event TokenWhitelisted(address[] tokens);
  event TokensRemovedFromWhitelist(address[] tokens);

  /**
   * @dev Initializes the contract with a list of tokens to be whitelisted and sets the whitelisting enabled flag.
   * @param _whitelistTokens Initial list of tokens to whitelist.
   * @param _tokenWhitelistingEnabled Flag indicating if token whitelisting is enabled.
   */
  function __TokenWhitelistManagement_init(
    address[] calldata _whitelistTokens,
    bool _tokenWhitelistingEnabled,
    address _protocolConfig
  ) internal onlyInitializing {
    if (_protocolConfig == address(0)) revert ErrorLibrary.InvalidAddress();
    protocolConfig = IProtocolConfig(_protocolConfig);
    tokenWhitelistingEnabled = _tokenWhitelistingEnabled;
    if (tokenWhitelistingEnabled) {
      if (_whitelistTokens.length == 0)
        revert ErrorLibrary.InvalidTokenWhitelistLength();

      _addTokensToWhitelist(_whitelistTokens);
    }
  }

  /**
   * @dev Internal function to add tokens to the whitelist.
   * @param _tokens Array of token addresses to whitelist.
   */
  function _addTokensToWhitelist(address[] calldata _tokens) internal {
    uint256 tokensLength = _tokens.length;
    if (tokensLength > protocolConfig.whitelistLimit())
      revert ErrorLibrary.InvalidWhitelistLimit();
    for (uint256 i; i < tokensLength; i++) {
      address _token = _tokens[i];
      if (_token == address(0)) {
        revert ErrorLibrary.InvalidAddress();
      }
      whitelistedTokens[_token] = true;
    }
    emit TokenWhitelisted(_tokens);
  }
}
