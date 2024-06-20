// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface ITokenExclusionManager {
  function init(address _accessController, address _protocolConfig) external;

  function snapshot() external returns (uint256);

  function claimRemovedTokens(address user) external;

  function setUserRecord(address _user, uint256 _userBalance) external;

  function setTokenAndSupplyRecord(
    uint256 _snapShotId,
    uint256 _balanceAtRemoval,
    address _tokenRemoved,
    uint256 _totalSupply
  ) external;

  function lastClaimedRemovedTokenId(
    address user
  ) external view returns (uint256);

  function userRecord(
    address user,
    uint256 snapshotId
  ) external view returns (uint256 portfolioBalance, bool hasInteractedWithId);
}
