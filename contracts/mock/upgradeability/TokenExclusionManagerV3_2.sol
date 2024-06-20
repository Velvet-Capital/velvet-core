// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/UUPSUpgradeable.sol";
import {IProtocolConfig} from "../../config/protocol/IProtocolConfig.sol";
import {AccessController} from "../../access/AccessController.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import {ErrorLibrary} from "../../library/ErrorLibrary.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-4.9.6/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title TokenExclusionManager
 * @dev Manages the exclusion of tokens from the platform, specifically in cases where tokens are removed from indices due to various reasons, e.g., lack of liquidity.
 * This contract allows tracking of user balances and interactions over time, enabling users to claim their share of removed tokens accurately.
 */
contract TokenExclusionManagerV3_2 is
  OwnableUpgradeable,
  UUPSUpgradeable,
  ReentrancyGuardUpgradeable
{
  AccessController public accessController;
  IProtocolConfig public protocolConfig;

  // Tracks the current snapshot ID, incremented each time a new snapshot is created.
  uint256 public _currentSnapshotId;

  uint256 public _newSnapShotId;

  // Stores user balance information and interaction status for each snapshot ID.
  struct UserRecordData {
    uint256 portfolioBalance;
    bool hasInteractedWithId;
  }

  // Stores information about tokens removed at each snapshot, including the token's address and its balance at the time of removal.
  struct RemovedTokenRecord {
    address token;
    uint256 balanceAtRemoval;
  }

  // Maps user addresses to their record data for each snapshot ID.
  mapping(address => mapping(uint256 => UserRecordData)) public userRecord;

  // Tracks the last snapshot ID for which users have claimed their share of removed tokens.
  mapping(address => uint256) public lastClaimedRemovedTokenId;

  // Maps each snapshot ID to the total supply of the portfolio at that point.
  mapping(uint256 => uint256) public totalSupplyRecord;

  // Maps each snapshot ID to its corresponding removed token record.
  mapping(uint256 => RemovedTokenRecord) public removedToken;

  // Event emitted when a user's record is updated.
  event UserRecordUpdated(
    address user,
    uint256 portfolioBalance,
    uint256 atSnapshotId
  );
  // Event emitted when a token's removal record is updated.
  event TokenRecordUpdated(
    address token,
    uint256 tokenBalance,
    uint256 totalSupply,
    uint256 atSnapshotId
  );
  // Event emitted when a new snapshot is created.
  event SnapShotCreated(uint256 snapshotId);
  // Event emitted when a user claims their share of removed tokens.
  event UserClaimedToken(address user, uint256 claimedTill);

  // Modifier to restrict function access to the portfolio manager only.
  modifier onlyPortfolioManager() {
    if (!_checkRole("PORTFOLIO_MANAGER_ROLE", msg.sender)) {
      revert ErrorLibrary.CallerNotPortfolioManager();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initializes the contract with the given access controller and protocol configuration addresses.
   * @param _accessController Address of the AccessController contract.
   * @param _protocolConfig Address of the ProtocolConfig contract.
   */
  function init(
    address _accessController,
    address _protocolConfig
  ) external initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
    if (_accessController == address(0) || _protocolConfig == address(0)) {
      revert ErrorLibrary.InvalidAddress();
    }

    accessController = AccessController(_accessController);
    protocolConfig = IProtocolConfig(_protocolConfig);
    _currentSnapshotId++;
  }

  /**
   * @notice Creates a new snapshot and increments the snapshot ID.
   * @return The new snapshot ID.
   */
  function snapshot() external onlyPortfolioManager returns (uint256) {
    _currentSnapshotId++;
    emit SnapShotCreated(_currentSnapshotId);
    return _currentSnapshotId;
  }

  /**
   * Token Removal Claim Functionality
   * @notice Allows users to claim their share of tokens that have been removed from the portfolio due to certain events (e.g., lack of liquidity).
   * @dev This function iterates through snapshot IDs from the user's last claimed ID to the current ID to calculate and distribute shares of removed tokens.
   * It uses historical balance data and interaction flags to accurately compute each user's share.
   */
  function claimRemovedTokens(address user) external nonReentrant {
    if (user == address(0)) revert ErrorLibrary.InvalidAddress();
    // Retrieve the current snapshot ID for processing
    uint256 _currentId = _currentSnapshotId;
    // If there are less than two snapshots, no tokens have been removed
    if (_currentId < 2) revert ErrorLibrary.NoTokensRemoved();

    // Fetch the last snapshot ID for which the user claimed removed tokens
    uint256 lastClaimedUserId = lastClaimedRemovedTokenId[user];

    // Initialize variable to keep track of the user's balance at the last valid snapshot ID
    uint256 _balanceOfLastValidId;

    // Iterate over snapshot IDs from the last claimed to the current ID
    for (uint256 id = lastClaimedUserId + 1; id < _currentId; id++) {
      // Retrieve total supply and details of the removed token at the current snapshot ID
      uint256 totalSupply = totalSupplyRecord[id];
      address currentRemovedToken = removedToken[id].token;
      uint256 tokenBalanceAtRemoval = removedToken[id].balanceAtRemoval;

      // Fetch user data for the current snapshot ID
      UserRecordData memory userData = userRecord[user][id];

      // Update _balanceOfLastValidId with current snapshot balance and clean up user record if user interacted with this ID
      if (userData.hasInteractedWithId) {
        _balanceOfLastValidId = userData.portfolioBalance;
        delete userRecord[user][id];
      }

      // Attempt to claim the user's share of the removed token based on their portfolio balance (if > 0) at the last valid snapshot
      attemptClaim(
        currentRemovedToken,
        user,
        _balanceOfLastValidId,
        tokenBalanceAtRemoval,
        totalSupply
      );
    }

    // Update user's record for the current snapshot with the last known balance if they haven't interacted with it
    if (!userRecord[user][_currentId].hasInteractedWithId) {
      _setUserRecord(user, _balanceOfLastValidId);
    }

    // Update the last claimed snapshot ID for the user
    _setLastClaimedId(user, _currentId - 1);

    // Emit an event indicating the user has claimed their share of the removed token
    emit UserClaimedToken(user, _currentId - 1);
  }

  /**
   * @notice Attempts to transfer the user's share of a removed token to them.
   * @dev Calculates the user's share based on their portfolio token balance at the time of removal and transfers it.
   * @param _removedToken Address of the removed token.
   * @param _user address of user to claim removed token
   * @param _portfolioTokenBalance User's balance of portfolio tokens at the last valid snapshot ID.
   * @param _balanceAtRemoval Total balance of the removed token at the time of removal.
   * @param _totalSupply Total supply of portfolio tokens at the snapshot ID.
   */
  function attemptClaim(
    address _removedToken,
    address _user,
    uint256 _portfolioTokenBalance,
    uint256 _balanceAtRemoval,
    uint256 _totalSupply
  ) private {
    if (_portfolioTokenBalance > 0) {
      // Calculate the user's share of the removed token
      uint256 balance = (_balanceAtRemoval * _portfolioTokenBalance) /
        _totalSupply;
      // Transfer the calculated share to the user
      TransferHelper.safeTransfer(_removedToken, _user, balance);
    }
  }

  /**
   * @notice This function sets/updates user record at currentSnapshotID
   * @param _user address of _user to set record
   * @param _userBalance portfolio/portfolio balance of user at _currentSnapShotID
   */
  function setUserRecord(
    address _user,
    uint256 _userBalance
  ) external onlyPortfolioManager {
    _setUserRecord(_user, _userBalance);
    emit UserRecordUpdated(_user, _userBalance, _currentSnapshotId);
  }

  /**
   * @notice This function is helper function of setUserRecord
   * @param _user address of _user to set record
   * @param _userBalance portfolio/portfolio balance of user at _currentSnapShotID
   */
  function _setUserRecord(address _user, uint256 _userBalance) internal {
    userRecord[_user][_currentSnapshotId].portfolioBalance = _userBalance;
    userRecord[_user][_currentSnapshotId].hasInteractedWithId = true;
  }

  /**
   * @notice This function set token and totalSupply record at removal by assetManager
   * @param _snapShotId snapshotId at which token is removed
   * @param _balanceAtRemoval balance of token at removal
   * @param _tokenRemoved address of token removed at snapshot
   * @param _totalSupply portfolio/portfolio total supply at removal
   */
  function setTokenAndSupplyRecord(
    uint256 _snapShotId,
    uint256 _balanceAtRemoval,
    address _tokenRemoved,
    uint256 _totalSupply
  ) external onlyPortfolioManager {
    removedToken[_snapShotId].token = _tokenRemoved;
    removedToken[_snapShotId].balanceAtRemoval = _balanceAtRemoval;
    totalSupplyRecord[_snapShotId] = _totalSupply;

    emit TokenRecordUpdated(
      _tokenRemoved,
      _balanceAtRemoval,
      _totalSupply,
      _snapShotId
    );
  }

  /**
   * @notice This function is helper function to update user last claimed id
   * @param _user address of user
   * @param _snapShotId last snapshotId, user has claimed their token
   */
  function _setLastClaimedId(address _user, uint256 _snapShotId) internal {
    lastClaimedRemovedTokenId[_user] = _snapShotId;
  }

  /**
   * @notice This internal function check for role
   */
  function _checkRole(
    bytes memory _role,
    address user
  ) internal view returns (bool) {
    return accessController.hasRole(keccak256(_role), user);
  }

  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyOwner {
    // Intentionally left empty as required by an abstract contract
  }
}
