// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../../contracts/fee/FeeModule.sol";

contract TestFeeModule is FeeModule {
  // Wrapper for _mintFees
  function MintFees(address _to, uint256 _amount) public returns (uint256) {
    return _mintFees(_to, _amount);
  }

  // Wrapper for _setLastFeeCharged
  function SetLastFeeCharged() public {
    _setLastFeeCharged();
  }

  // Wrapper for _mintProtocolAndManagementFees
  function MintProtocolAndManagementFees(
    uint256 assetManagerFeeToMint,
    uint256 _protocolFeeToMint
  ) public {
    _mintProtocolAndManagementFees(assetManagerFeeToMint, _protocolFeeToMint);
  }

  // Wrapper for _calculateStreamingFees
  // function  CalculateStreamingFees(uint256 _totalSupply) public returns (uint256, uint256) {
  //     return _calculateStreamingFees(_totalSupply);
  // }

  // Wrapper for _calculateProtocolAndManagementFees
  // function  CalculateProtocolAndManagementFees() public returns (uint256, uint256) {
  //     return _calculateProtocolAndManagementFees();
  //}

  // Wrapper for _calculateStreamingFee
  // function CalculateStreamingFee(
  //   uint256 _totalSupply,
  //   uint256 _lastCharged,
  //   uint256 _fee
  // ) public returns (uint256) {
  //   return _calculateStreamingFee(_totalSupply, _lastCharged, _fee);
  // }

  // Wrapper for calculateEntryAndExitFee
  function CalculateEntryAndExitFee(
    uint256 _fee,
    uint256 _tokenAmount
  ) public pure returns (uint256) {
    return _calculateEntryOrExitFee(_fee, _tokenAmount);
  }

  // Wrapper for feeSplitter
  function FeeSplitter(
    uint256 _fee,
    uint256 _protocolFee
  ) public pure returns (uint256, uint256) {
    return _splitFee(_fee, _protocolFee);
  }
}
