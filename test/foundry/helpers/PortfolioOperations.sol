// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {Permit2Helper, IAllowanceTransfer} from "./Permit2Helper.sol";

import {IPortfolio} from "../../../contracts/core/interfaces/IPortfolio.sol";

import {IERC20} from "../interfaces/IERC20.sol";

import "forge-std/console.sol";

contract PortfolioOperations is Permit2Helper {
  IPortfolio portfolio;

  uint256 public ownerPrivateKey;
  address public owner;

  uint256 public nonOwnerPrivateKey;
  address public nonOwner;

  uint256[] totalAmountDepositedOwner;
  uint256[] totalAmountDepositedNonOwner;

  function _mintTokensForUser(
    address _token,
    address _user,
    uint256 _amount
  ) internal {
    IERC20(_token).mint(_user, _amount);
  }

  function approveAllPortfolioToken(address _approver) internal {
    address[] memory portfolioTokens = portfolio.getTokens();
    uint256 portfolioTokensLength = portfolioTokens.length;

    vm.startPrank(_approver);
    for (uint256 i; i < portfolioTokensLength; i++) {
      IERC20(portfolioTokens[i]).approve(UNISWAP_PERMIT2, type(uint256).max);
    }

    vm.stopPrank();
  }

  function depositChecks(
    address _depositor,
    address[] memory portfolioTokens,
    uint256 portfolioTokensLength,
    uint256[] memory tokenAmountsBefore,
    uint256 userBalanceBefore,
    uint256 supplyBefore
  ) internal {
    uint256 supplyAfter = portfolio.totalSupply();
    uint256 userBalanceAfter = portfolio.balanceOf(_depositor);

    assertGt(supplyAfter, supplyBefore);
    assertGt(userBalanceAfter, userBalanceBefore);

    console.log("Minted amount: ", userBalanceAfter - userBalanceBefore);

    uint256[] memory tokenAmountsAfter = getTokenBalances(
      portfolioTokens,
      _depositor
    );

    for (uint256 i; i < portfolioTokensLength; i++) {
      uint256 depositAmount = tokenAmountsBefore[i] - tokenAmountsAfter[i];

      if (_depositor == owner) {
        totalAmountDepositedOwner[i] += depositAmount;
        console.log(
          "total amount deposited owner",
          totalAmountDepositedOwner[i]
        );
      } else if (_depositor == nonOwner) {
        totalAmountDepositedNonOwner[i] += depositAmount;
        console.log(
          "total amount deposited non-owner",
          totalAmountDepositedNonOwner[i]
        );
      }
    }
  }

  function _depositFor(
    address _depositor,
    address _depositInBehalfOf,
    uint256[] memory _depositAmounts,
    uint256 minMintAmount
  ) internal {
    if (_depositInBehalfOf == owner) {
      console.log("--- DEPOSIT OWNER ---");
    } else if (_depositInBehalfOf == nonOwner) {
      console.log("--- DEPOSIT NON-OWNER ---");
    }
    uint256 supplyBefore = portfolio.totalSupply();
    uint256 userBalanceBefore = portfolio.balanceOf(_depositInBehalfOf);

    address[] memory portfolioTokens = portfolio.getTokens();
    uint256 portfolioTokensLength = portfolioTokens.length;

    vm.startPrank(_depositor);

    for (uint256 i; i < portfolioTokensLength; i++) {
      _mintTokensForUser(portfolioTokens[i], _depositor, _depositAmounts[i]);
    }

    // Approve tokens for the portfolio contract
    uint256 depositAmountsLength = _depositAmounts.length;
    for (uint256 i; i < depositAmountsLength; i++) {
      IERC20(portfolioTokens[i]).approve(
        address(portfolio),
        _depositAmounts[i]
      );
    }

    uint256[] memory tokenAmountsBefore = getTokenBalances(
      portfolioTokens,
      _depositor
    );

    portfolio.multiTokenDepositFor(
      _depositInBehalfOf,
      _depositAmounts,
      minMintAmount
    );

    vm.stopPrank();

    depositChecks(
      _depositInBehalfOf,
      portfolioTokens,
      portfolioTokensLength,
      tokenAmountsBefore,
      userBalanceBefore,
      supplyBefore
    );
  }

  function _deposit(
    address _depositor,
    uint256 _privateKey,
    uint256[] memory _depositAmounts,
    uint256 minMintAmount
  ) internal {
    if (_depositor == owner) {
      console.log("--- DEPOSIT OWNER ---");
    } else if (_depositor == nonOwner) {
      console.log("--- DEPOSIT NON-OWNER ---");
    }
    uint256 supplyBefore = portfolio.totalSupply();
    uint256 userBalanceBefore = portfolio.balanceOf(_depositor);

    address[] memory portfolioTokens = portfolio.getTokens();
    uint256 portfolioTokensLength = portfolioTokens.length;
    uint48[] memory nonces = new uint48[](portfolioTokensLength);

    vm.startPrank(_depositor);

    for (uint256 i; i < portfolioTokensLength; i++) {
      address portfolioToken = portfolioTokens[i];
      (, , uint48 nonce) = permit2.allowance(
        _depositor,
        portfolioToken,
        address(portfolio)
      );

      nonces[i] = nonce;
    }

    IAllowanceTransfer.PermitBatch
      memory permit = defaultERC20PermitBatchAllowance(
        portfolioTokens,
        _depositAmounts,
        uint48(block.timestamp + 100),
        nonces,
        address(portfolio)
      );
    bytes memory sig = getPermitBatchSignature(
      permit,
      _privateKey,
      DOMAIN_SEPARATOR
    );

    for (uint256 i; i < portfolioTokensLength; i++) {
      _mintTokensForUser(portfolioTokens[i], _depositor, _depositAmounts[i]);
    }

    uint256[] memory tokenAmountsBefore = getTokenBalances(
      portfolioTokens,
      _depositor
    );

    portfolio.multiTokenDeposit(_depositAmounts, minMintAmount, permit, sig);

    vm.stopPrank();

    depositChecks(
      _depositor,
      portfolioTokens,
      portfolioTokensLength,
      tokenAmountsBefore,
      userBalanceBefore,
      supplyBefore
    );
  }

  function _withdrawFor(
    address _withdrawer,
    address _withdrawInBehalfOf,
    address _tokenReceiver,
    uint256 _withdrawAmount
  ) internal {
    if (_withdrawer == owner) {
      console.log("---- WITHDRAWAL OWNER ---");
    } else if (_withdrawer == nonOwner) {
      console.log("--- WITHDRAWAL NON-OWNER ---");
    }

    address[] memory portfolioTokens = portfolio.getTokens();

    uint256[] memory tokenAmountsBefore = getTokenBalances(
      portfolioTokens,
      _tokenReceiver
    );

    vm.startPrank(_withdrawInBehalfOf);
    portfolio.approve(_withdrawer, _withdrawAmount);
    vm.stopPrank();

    vm.startPrank(_withdrawer);
    portfolio.multiTokenWithdrawalFor(
      _withdrawInBehalfOf,
      _tokenReceiver,
      _withdrawAmount
    );
    vm.stopPrank();

    uint256[] memory tokenAmountsAfter = getTokenBalances(
      portfolioTokens,
      _tokenReceiver
    );

    uint256 portfolioTokensLength = portfolioTokens.length;
    for (uint256 i; i < portfolioTokensLength; i++) {
      assertTrue(
        tokenAmountsAfter[i] > tokenAmountsBefore[i],
        string(
          abi.encodePacked(
            "Token balance of the following token does not increase after withdrawal: ",
            portfolioTokens[i]
          )
        )
      );

      console.log(
        "withdrawal amount",
        portfolioTokens[i],
        tokenAmountsAfter[i] - tokenAmountsBefore[i]
      );
    }
  }

  function _withdraw(address _withdrawer, uint256 _withdrawAmount) internal {
    if (_withdrawer == owner) {
      console.log("---- WITHDRAWAL OWNER ---");
    } else if (_withdrawer == nonOwner) {
      console.log("--- WITHDRAWAL NON-OWNER ---");
    }

    address[] memory portfolioTokens = portfolio.getTokens();

    uint256[] memory tokenAmountsBefore = getTokenBalances(
      portfolioTokens,
      _withdrawer
    );

    vm.startPrank(_withdrawer);

    portfolio.multiTokenWithdrawal(_withdrawAmount);

    vm.stopPrank();

    uint256[] memory tokenAmountsAfter = getTokenBalances(
      portfolioTokens,
      _withdrawer
    );

    uint256 portfolioTokensLength = portfolioTokens.length;
    for (uint256 i; i < portfolioTokensLength; i++) {
      assertTrue(
        tokenAmountsAfter[i] > tokenAmountsBefore[i],
        string(
          abi.encodePacked(
            "Token balance of the following token does not increase after withdrawal: ",
            portfolioTokens[i]
          )
        )
      );

      console.log(
        "withdrawal amount",
        portfolioTokens[i],
        tokenAmountsAfter[i] - tokenAmountsBefore[i]
      );
    }
  }

  function getTokenBalances(
    address[] memory portfolioTokens,
    address _holder
  ) internal view returns (uint256[] memory tokenAmountsBefore) {
    uint256 portfolioTokensLength = portfolioTokens.length;
    tokenAmountsBefore = new uint256[](portfolioTokensLength);
    for (uint256 i; i < portfolioTokensLength; i++) {
      tokenAmountsBefore[i] = IERC20(portfolioTokens[i]).balanceOf(_holder);
    }
  }
}
