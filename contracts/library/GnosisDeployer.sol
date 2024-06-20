// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {VelvetSafeModule} from "../vault/VelvetSafeModule.sol";
import {ErrorLibrary} from "./ErrorLibrary.sol";
import {IMultiSend} from "../core/interfaces/IMultiSend.sol";
import {IGnosisSafe} from "../core/interfaces/IGnosisSafe.sol";

import {FunctionParameters} from "../FunctionParameters.sol";

library GnosisDeployer {
  function _deployGnosisSafeAndModule(
    FunctionParameters.SafeAndModuleDeploymentParams memory params
  ) internal returns (address gnosisSafe, address velvetModule) {
    GnosisSafeProxyFactory gnosisSafeProxyFactory = GnosisSafeProxyFactory(
      params._gnosisSafeProxyFactory
    );
    GnosisSafe _safe = GnosisSafe(
      payable(
        gnosisSafeProxyFactory.createProxy(params._gnosisSingleton, bytes(""))
      )
    );
    VelvetSafeModule _gnosisModule = VelvetSafeModule(
      Clones.clone(params._baseGnosisModule)
    );

    //
    bytes memory _enableSafeModule = abi.encodeCall(
      IGnosisSafe.enableModule,
      address(_gnosisModule)
    );
    bytes memory _enableVelvetMultisend = abi.encodePacked(
      uint8(0),
      _safe,
      uint256(0),
      uint256(_enableSafeModule.length),
      bytes(_enableSafeModule)
    );

    bytes memory _multisendAction = abi.encodeCall(
      IMultiSend.multiSend,
      _enableVelvetMultisend
    );

    _safe.setup(
      params._owners,
      params._threshold,
      params._gnosisMultisendLibrary,
      _multisendAction,
      params._gnosisFallbackLibrary,
      address(0),
      0,
      payable(address(0))
    );
    gnosisSafe = address(_safe);
    velvetModule = address(_gnosisModule);

    if (!_safe.isModuleEnabled(velvetModule)) {
      revert ErrorLibrary.ModuleNotInitialised();
    }
    return (gnosisSafe, velvetModule);
  }
}
