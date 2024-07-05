// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable-4.9.6/proxy/utils/Initializable.sol";
import {IPortfolioFactory} from "../core/interfaces/IPortfolioFactory.sol";
import {ErrorLibrary} from "../library/ErrorLibrary.sol";

abstract contract TargetWhitelisting is Initializable {
  IPortfolioFactory public portfolioFactory;

  function __TargetWhitelisting_init(address _portfolioFactory) internal {
    portfolioFactory = IPortfolioFactory(_portfolioFactory);
  }

  function validateTargetWhitelisting(address _target) public view {
    if (!portfolioFactory.whitelistedPortfolioAddress(_target))
      revert ErrorLibrary.InvalidTargetAddress();
  }
}
