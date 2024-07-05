// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {IPortfolio} from "../../contracts/core/interfaces/IPortfolio.sol";
import {IPortfolioFactory} from "../../contracts/core/interfaces/IPortfolioFactory.sol";
import {IAllowanceTransfer} from "../../contracts/core/interfaces/IAllowanceTransfer.sol";
import {IRebalancing} from "../../contracts/rebalance/IRebalancing.sol";
import {Addresses} from "../foundry/utils/Addresses.sol";
import {PortfolioDeployment} from "./utils/PortfolioDeployment.s.sol";
import {FunctionParameters} from "../../contracts/FunctionParameters.sol";
import {ErrorLibrary} from "../../contracts/library/ErrorLibrary.sol";
import "./utils/AssetUtils.sol";

import {IPermit2} from "./interfaces/IPermit2.sol";

import {PortfolioOperations} from "./helpers/PortfolioOperations.sol";
import "forge-std/console.sol";

contract PortfolioFactory is PortfolioOperations, AssetUtils, Addresses {
  address tokenA;
  address tokenB;
  address tokenC;

  IRebalancing rebalance;

  function setUp() public {
    ownerPrivateKey = 0x12341234;
    owner = vm.addr(ownerPrivateKey);

    nonOwnerPrivateKey = 0x56785678;
    nonOwner = vm.addr(nonOwnerPrivateKey);

    tokenA = address(generateTestTokenByName("TokenA", 18));
    tokenB = address(generateTestTokenByName("TokenB", 10));
    tokenC = address(generateTestTokenByName("TokenC", 8));

    PortfolioDeployment portfolioDeployment = new PortfolioDeployment();

    address[] memory _whitelistedTokens = new address[](2);
    _whitelistedTokens[0] = tokenA;
    _whitelistedTokens[1] = tokenB;

    address assetManagerTreasury = makeAddr("assetManagerTreasury");

    (
      address portfolioAddress,
      IPortfolioFactory.PortfoliolInfo memory portfolioSwapInfo
    ) = portfolioDeployment.createNewPortfolio(
        FunctionParameters.PortfolioCreationInitData({
          _name: "INDEXLY",
          _symbol: "IDX",
          _managementFee: 1,
          _performanceFee: 2500,
          _entryFee: 0,
          _exitFee: 0,
          _initialPortfolioAmount: 10000000000000000,
          _minPortfolioTokenHoldingAmount: 10000000000000000,
          _assetManagerTreasury: assetManagerTreasury,
          _whitelistedTokens: _whitelistedTokens,
          _public: true,
          _transferable: true,
          _transferableToPublic: true,
          _whitelistTokens: false
        })
      );

    portfolio = IPortfolio(portfolioAddress);
    rebalance = IRebalancing(portfolioSwapInfo.rebalancing);

    permit2 = IPermit2(UNISWAP_PERMIT2);
    DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
  }

  function testFailInitTokenCrossMaxAssetLimit() public {
    address[] memory tokens = new address[](15);

    tokens[0] = tokenA;
    tokens[1] = tokenB;
    tokens[2] = tokenC;
    tokens[3] = BSC_ADA;
    tokens[4] = BSC_BAND;
    tokens[5] = BSC_BTC;
    tokens[6] = BSC_CAKE;
    tokens[7] = BSC_DAI;
    tokens[8] = BSC_DOT;
    tokens[9] = BSC_ETH;
    tokens[10] = BSC_ETH;
    tokens[11] = BSC_ETH;
    tokens[12] = BSC_ETH;
    tokens[13] = BSC_ETH;
    tokens[14] = BSC_ETH;
    tokens[15] = BSC_ETH;
    tokens[16] = BSC_ETH;

    vm.expectRevert(ErrorLibrary.TokenCountOutOfLimit.selector);
    portfolio.initToken(tokens);
  }

  function testInitTokenShouldFailCallFromNonOwner() public {
    address[] memory tokens = new address[](2);
    tokens[0] = tokenA;
    tokens[1] = tokenB;
    vm.prank(msg.sender);
    vm.expectRevert(ErrorLibrary.CallerNotSuperAdmin.selector);
    portfolio.initToken(tokens);
  }

  function initTestToken() public {
    address[] memory tokens = new address[](3);
    tokens[0] = tokenA;
    tokens[1] = tokenB;
    tokens[2] = tokenC;

    portfolio.initToken(tokens);

    uint256 portfolioTokenLength = portfolio.getTokens().length;
    totalAmountDepositedOwner = new uint256[](portfolioTokenLength);
    totalAmountDepositedNonOwner = new uint256[](portfolioTokenLength);
  }

  function testMultiTokenDeposit() public {
    initTestToken();

    address depositor = owner;
    uint256 privateKey = ownerPrivateKey;

    approveAllPortfolioToken(depositor);

    address[] memory portfolioTokens = portfolio.getTokens();
    uint256[] memory depositAmounts = new uint256[](3);
    depositAmounts[0] = 8 * getAssetUnit(portfolioTokens[0]);
    depositAmounts[1] = 9 * getAssetUnit(portfolioTokens[1]);
    depositAmounts[2] = 10 * getAssetUnit(portfolioTokens[2]);

    _deposit(depositor, privateKey, depositAmounts, 0);
  }

  function testMultiTokenDepositNonOwner() public {
    testMultiTokenDeposit();

    address depositor = nonOwner;
    uint256 privateKey = nonOwnerPrivateKey;

    approveAllPortfolioToken(depositor);

    address[] memory portfolioTokens = portfolio.getTokens();
    uint256[] memory depositAmounts = new uint256[](3);
    depositAmounts[0] = 16 * getAssetUnit(portfolioTokens[0]);
    depositAmounts[1] = 18 * getAssetUnit(portfolioTokens[1]);
    depositAmounts[2] = 20 * getAssetUnit(portfolioTokens[2]);

    _deposit(depositor, privateKey, depositAmounts, 0);
  }

  function testMultiTokenDepositForNonOwner() public {
    testMultiTokenDeposit();

    address depositor = owner;
    address depositFor = nonOwner;

    approveAllPortfolioToken(depositor);

    address[] memory portfolioTokens = portfolio.getTokens();
    uint256[] memory depositAmounts = new uint256[](3);
    depositAmounts[0] = 16 * getAssetUnit(portfolioTokens[0]);
    depositAmounts[1] = 18 * getAssetUnit(portfolioTokens[1]);
    depositAmounts[2] = 20 * getAssetUnit(portfolioTokens[2]);

    _depositFor(depositor, depositFor, depositAmounts, 0);
  }

  function testMultiTokenDeposit2() public {
    testMultiTokenDepositNonOwner();

    address depositor = owner;
    uint256 privateKey = ownerPrivateKey;

    address[] memory portfolioTokens = portfolio.getTokens();
    uint256[] memory depositAmounts = new uint256[](3);
    depositAmounts[0] = 32 * getAssetUnit(portfolioTokens[0]);
    depositAmounts[1] = 36 * getAssetUnit(portfolioTokens[1]);
    depositAmounts[2] = 40 * getAssetUnit(portfolioTokens[2]);

    _deposit(depositor, privateKey, depositAmounts, 0);
  }

  function testMultiTokenDepositNonOwner2() public {
    testMultiTokenDeposit2();

    address depositor = nonOwner;
    uint256 privateKey = nonOwnerPrivateKey;

    address[] memory portfolioTokens = portfolio.getTokens();

    uint256[] memory depositAmounts = new uint256[](3);
    depositAmounts[0] = 40 * getAssetUnit(portfolioTokens[0]);
    depositAmounts[1] = 45 * getAssetUnit(portfolioTokens[1]);
    depositAmounts[2] = 50 * getAssetUnit(portfolioTokens[2]);

    _deposit(depositor, privateKey, depositAmounts, 0);
  }

  function testWithdrawMultiToken() public {
    testMultiTokenDepositNonOwner2();

    vm.warp(block.timestamp + 24 hours);

    address withdrawer = owner;
    uint256 withdrawalAmount = portfolio.balanceOf(withdrawer);

    _withdraw(withdrawer, withdrawalAmount);

    totalAmountDepositedOwner[0] = 0;
    totalAmountDepositedOwner[1] = 0;
    totalAmountDepositedOwner[2] = 0;
  }

  function testWithdrawMultiTokenForNonOwner() public {
    testWithdrawMultiToken();

    vm.warp(block.timestamp + 24 hours);

    address withdrawer = owner;
    address withdrawFor = nonOwner;
    address tokenReceiver = owner;

    uint256 withdrawalAmount = portfolio.balanceOf(withdrawFor);

    _withdrawFor(withdrawer, withdrawFor, tokenReceiver, withdrawalAmount);

    totalAmountDepositedNonOwner[0] = 0;
    totalAmountDepositedNonOwner[1] = 0;
    totalAmountDepositedNonOwner[2] = 0;
  }

  function testMultiTokenDepositAfterWithdrawalAllUsers() public {
    testWithdrawMultiTokenForNonOwner();

    address depositor = owner;
    uint256 privateKey = ownerPrivateKey;

    address[] memory portfolioTokens = portfolio.getTokens();
    uint256[] memory depositAmounts = new uint256[](3);
    depositAmounts[0] = 8 * getAssetUnit(portfolioTokens[0]);
    depositAmounts[1] = 9 * getAssetUnit(portfolioTokens[1]);
    depositAmounts[2] = 10 * getAssetUnit(portfolioTokens[2]);

    _deposit(depositor, privateKey, depositAmounts, 0);
  }

  function testWithdrawMultiTokenAfterDeposit() public {
    testMultiTokenDepositAfterWithdrawalAllUsers();

    vm.warp(block.timestamp + 24 hours);

    address withdrawer = owner;
    uint256 withdrawalAmount = portfolio.balanceOf(withdrawer);

    _withdraw(withdrawer, withdrawalAmount);
  }
}
