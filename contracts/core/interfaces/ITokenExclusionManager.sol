// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface ITokenExclusionManager {
  function init(
    address _accessController,
    address _protocolConfig,
    address _baseTokenRemovalVaultImplementation
  ) external;

  function snapshot() external returns (uint256);

  function _currentSnapshotId() external view returns (uint256);

  function claimRemovedTokens(
    address user,
    uint256 startId,
    uint256 endId
  ) external;

  function setUserRecord(address _user, uint256 _userBalance) external;

  function setTokenAndSupplyRecord(
    uint256 _snapShotId,
    address _tokenRemoved,
    address _vault,
    uint256 _totalSupply
  ) external;

  function claimTokenAtId(address user, uint256 id) external;

  function getDataAtId(
    address user,
    uint256 id
  ) external view returns (bool, uint256);

  function userRecord(
    address user,
    uint256 snapshotId
  ) external view returns (uint256 portfolioBalance, bool hasInteractedWithId);

  function deployTokenRemovalVault() external returns (address);

  function removedToken(
    uint256 id
  )
    external
    view
    returns (address token, address vault, uint256 totalSupply);
}
