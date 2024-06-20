// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {IPermit2} from "../interfaces/IPermit2.sol";
import {IAllowanceTransfer} from "../../../contracts/core/interfaces/IAllowanceTransfer.sol";

contract Permit2Helper is Test {
  IPermit2 permit2;
  bytes32 DOMAIN_SEPARATOR;

  address constant UNISWAP_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
    keccak256(
      "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

  bytes32 public constant _PERMIT_BATCH_TYPEHASH =
    keccak256(
      "PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

  function getPermitBatchSignature(
    IAllowanceTransfer.PermitBatch memory permit,
    uint256 privateKey,
    bytes32 domainSeparator
  ) internal pure returns (bytes memory sig) {
    bytes32[] memory permitHashes = new bytes32[](permit.details.length);
    for (uint256 i; i < permit.details.length; ++i) {
      permitHashes[i] = keccak256(
        abi.encode(_PERMIT_DETAILS_TYPEHASH, permit.details[i])
      );
    }
    bytes32 msgHash = keccak256(
      abi.encodePacked(
        "\x19\x01",
        domainSeparator,
        keccak256(
          abi.encode(
            _PERMIT_BATCH_TYPEHASH,
            keccak256(abi.encodePacked(permitHashes)),
            permit.spender,
            permit.sigDeadline
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
    return bytes.concat(r, s, bytes1(v));
  }

  function defaultERC20PermitBatchAllowance(
    address[] memory tokens,
    uint256[] memory amount,
    uint48 expiration,
    uint48[] memory nonce,
    address _spender
  ) internal view returns (IAllowanceTransfer.PermitBatch memory) {
    IAllowanceTransfer.PermitDetails[]
      memory details = new IAllowanceTransfer.PermitDetails[](tokens.length);

    for (uint256 i; i < tokens.length; ++i) {
      details[i] = IAllowanceTransfer.PermitDetails({
        token: tokens[i],
        amount: uint160(amount[i]) * 2,
        expiration: expiration,
        nonce: nonce[i]
      });
    }

    return
      IAllowanceTransfer.PermitBatch({
        details: details,
        spender: _spender,
        sigDeadline: block.timestamp + 100
      });
  }
}
