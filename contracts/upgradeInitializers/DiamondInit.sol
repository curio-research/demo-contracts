// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import {Base, TroopType, WorldConstants} from "contracts/libraries/Types.sol";
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";
import {IDiamondLoupe} from "contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "contracts/interfaces/IDiamondCut.sol";
import {IERC173} from "contracts/interfaces/IERC173.sol";
import {IERC165} from "contracts/interfaces/IERC165.sol";
import {Util} from "contracts/libraries/GameUtil.sol";
import "contracts/libraries/Storage.sol";

// It is expected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

// temporarily disable to test foundry test
contract DiamondInit is UseStorage {
    // You can add parameters to this function in order to pass in
    // data to set your own state variables
    function init(WorldConstants memory _worldConstants, TroopType[] memory _troopTypes) external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // add your own state variables
        // EIP-2535 specifies that the `diamondCut` function takes two optional
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface

        // set world constants
        gs().worldConstants = _worldConstants;

        // initialize troop types
        for (uint256 i = 0; i < _troopTypes.length; i++) {
            gs().troopTypeIds.push(i + 1);
            gs().troopTypeIdMap[i + 1] = _troopTypes[i];
        }

        // start troop nonce at 1. 0 denotes no troops
        gs().troopNonce++;

        // start base nonce at 1. 0 denotes no base
        gs().baseNonce++;
    }
}
