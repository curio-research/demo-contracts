// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GameState} from "contracts/libraries/Types.sol";

library LibStorage {
    bytes32 constant GAME_STORAGE_POSITION = keccak256("game.storage.game");

    function gameStorage() internal pure returns (GameState storage gs) {
        bytes32 position = GAME_STORAGE_POSITION;
        assembly {
            gs.slot := position
        }
    }
}

contract UseStorage {
    function gs() internal pure returns (GameState storage ret) {
        return LibStorage.gameStorage();
    }
}
