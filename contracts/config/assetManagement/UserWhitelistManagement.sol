// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {AssetManagerCheck} from "./AssetManagerCheck.sol";
import {IProtocolConfig} from "../../config/protocol/IProtocolConfig.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";

/**
 * @title UserWhitelistManagement
 * @dev Manages user whitelisting, allowing for flexible access control.
 */
abstract contract UserWhitelistManagement is AssetManagerCheck, Initializable {
  // Reference to the protocol configuration contract
  IProtocolConfig private protocolConfig;

  mapping(address => bool) public whitelistedUsers;

  event UserWhitelisted(address[] users);
  event UserRemovedFromWhitelist(address[] users);

  function __UserWhitelistManagement_init(
    address _protocolConfig
  ) internal onlyInitializing {
    if (_protocolConfig == address(0)) revert ErrorLibrary.InvalidAddress();
    protocolConfig = IProtocolConfig(_protocolConfig);
  }

  /**
   * @notice This function whitelists users which can deposit in a particular portfolio
   * @param users Array of user addresses to be whitelisted by the asset manager
   */
  function whitelistUser(
    address[] calldata users
  ) external virtual onlyWhitelistManager {
    uint256 len = users.length;
    if (len > protocolConfig.whitelistLimit())
      revert ErrorLibrary.InvalidWhitelistLimit();
    for (uint256 i; i < len; i++) {
      address _user = users[i];
      if (_user == address(0)) revert ErrorLibrary.InvalidAddress();
      whitelistedUsers[_user] = true;
    }
    emit UserWhitelisted(users);
  }

  /**
   * @notice This function removes a previously whitelisted user
   * @param users Array of user addresses to be removed from whiteist by the asset manager
   */
  function removeWhitelistedUser(
    address[] calldata users
  ) external virtual onlyWhitelistManager {
    uint256 len = users.length;
    for (uint256 i; i < len; i++) {
      if (users[i] == address(0)) revert ErrorLibrary.InvalidAddress();
      whitelistedUsers[users[i]] = false;
    }
    emit UserRemovedFromWhitelist(users);
  }
}
