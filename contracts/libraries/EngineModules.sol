//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/libraries/Storage.sol";
import {Util} from "contracts/libraries/GameUtil.sol";
import {BASE_NAME, TROOP_NAME, Base, GameState, Player, Position, TERRAIN, Tile, Troop, TroopType, Army, WorldConstants} from "contracts/libraries/Types.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

/// @title EngineModules library
/// @notice Composable parts for engine functions
/// functions generally do not verify correctness of conditions. Make sure to verify in higher-level checkers.
/// Note: This file should not have any occurrences of `msg.sender`. Pass in player addresses to use them.

library EngineModules {
    using SafeMath for uint256;

    function gs() internal pure returns (GameState storage) {
        return LibStorage.gameStorage();
    }

    // ----------------------------------------------------------------------
    // MODULES FOR MARCH
    // ----------------------------------------------------------------------

    function _moveArmy(
        address _player,
        uint256 armyId,
        Position memory _targetPos
    ) public {
        Army memory _army = Util._getArmy(armyId);

        // uint256 _movementCooldown = Util._getArmyMovementCooldown(_army.troopIds);
        // require((block.timestamp - _army.lastMoved) >= _movementCooldown, "CURIO: Moved too recently");

        // state change
        gs().map[_targetPos.x][_targetPos.y].occupantId = armyId;
        gs().armyIdMap[armyId].pos = _targetPos;
        gs().armyIdMap[armyId].lastMoved = block.timestamp;
        gs().map[_army.pos.x][_army.pos.y].occupantId = _NULL(); // clear source tile's occupant ID

        Util._updatePlayerBalances(_player);
    }

    function _battleBase(
        address _player,
        uint256 _armyId,
        Position memory _targetPos
    ) public {
        Army memory _army = gs().armyIdMap[_armyId];
        require(Util._withinDist(_army.pos, _targetPos, 1), "CURIO: Target not in firing range");
        gs().armyIdMap[_armyId].lastLargeActionTaken = block.timestamp;

        Tile memory _targetTile = Util._getTileAt(_targetPos);
        require(_targetTile.baseId != _NULL(), "CURIO: No target to attack");
        Base memory _targetBase = gs().baseIdMap[_targetTile.baseId];

        require(_targetBase.owner != _player, "CURIO: Cannot attack own base");

        // Exchange fire until one side dies
        uint256 _salt = 1;
        uint256 _armyHealth = Util._getArmyHealth(_army.troopIds);

        while (_armyHealth > 0) {
            // Troop attacks target
            _salt++;
            if (Util._strike(_targetBase.attackFactor, _salt)) {
                Util._updatePlayerBalances(_player);
                uint256 _damagePerHit;
                if (Util._isDebuffed(_player)) {
                    _damagePerHit = Util._getDebuffedArmyDamagePerHit(_army.troopIds);
                } else {
                    _damagePerHit = Util._getArmyDamagePerHit(_army.troopIds);
                }

                if (_damagePerHit < _targetBase.health) {
                    _targetBase.health -= _damagePerHit;
                } else {
                    _targetBase.health = 0;
                }
            }

            if (_targetBase.health == 0) break; // target cannot attack back if it has zero health

            // Target attacks troop
            _salt++;
            if (Util._strike(_targetBase.defenseFactor, _salt)) {
                if (_armyHealth > 100) {
                    _armyHealth -= 100;
                } else {
                    _armyHealth = 0;
                    Util._removeArmyWithTroops(_armyId);
                    emit Util.ArmyDeath(_player, _armyId);
                }
            }
        }

        if (_targetBase.health == 0) {
            // Target base dies
            address _targetPlayer = _targetBase.owner;
            gs().baseIdMap[_targetTile.baseId].health = 0;

            uint256 _damageToDistribute = Util._getArmyHealth(_army.troopIds) - _armyHealth;
            Util._damageArmy(_damageToDistribute, _army.troopIds);

            // Capture and move onto base if troop is infantry or if base is oil well
            require(Util._getPlayer(_player).numOwnedBases < gs().worldConstants.maxBaseCountPerPlayer, "CURIO: Max base count exceeded");

            _targetBase = Util._getBase(_targetTile.baseId);
            gs().baseIdMap[_targetTile.baseId].owner = _player;
            gs().baseIdMap[_targetTile.baseId].health = 800;

            Util._updatePlayerBalances(_targetPlayer);
            Util._updatePlayerBalances(_player);
            if (_targetPlayer != _NULL_ADRRESS()) {
                gs().playerMap[_targetPlayer].numOwnedBases--;
                gs().playerMap[_targetPlayer].totalGoldGenerationPerUpdate -= _targetBase.goldGenerationPerSecond;
                gs().playerMap[_targetPlayer].totalOilGenerationPerUpdate -= _targetBase.oilGenerationPerSecond;
            }
            gs().playerMap[_player].numOwnedBases++;
            gs().playerMap[_player].totalGoldGenerationPerUpdate += _targetBase.goldGenerationPerSecond;
            gs().playerMap[_player].totalOilGenerationPerUpdate += _targetBase.oilGenerationPerSecond;

            // Move
            _moveArmy(_player, _armyId, _targetPos);
        } else {
            // Troop dies
            gs().baseIdMap[_targetTile.baseId].health = _targetBase.health;
            _targetBase = Util._getBase(_targetTile.baseId);
        }

        _updateAttackedArmy(_player, _armyId, _armyId);
        _baseUpdate(_player, _targetTile.baseId);
    }

    function _baseUpdate(address _owner, uint256 _baseId) public {
        Base memory _base = Util._getBase(_baseId);

        emit Util.BaseInfo(_owner, _baseId, _base);
    }

    function _battleArmy(
        address _player,
        uint256 _armyId,
        Position memory _targetPos
    ) public {
        Army memory _army = gs().armyIdMap[_armyId];
        require(Util._withinDist(_army.pos, _targetPos, 1), "CURIO: Target not in firing range");
        gs().armyIdMap[_armyId].lastLargeActionTaken = block.timestamp;

        Tile memory _targetTile = Util._getTileAt(_targetPos);
        Army memory _targetArmy = gs().armyIdMap[_targetTile.occupantId];
        require(_targetArmy.owner != _player, "CURIO: Cannot attack own troop");

        uint256 _armyHealth = Util._getArmyHealth(_army.troopIds);
        uint256 _targetHealth = Util._getArmyHealth(_targetArmy.troopIds);

        // Exchange fire until one side dies
        uint256 _salt = 0;
        uint256 _damagePerHit;
        while (_armyHealth > 0) {
            // Troop attacks target
            _salt += 1;
            if (Util._strike(Util._getArmyAttackFactor(_targetArmy.troopIds), _salt)) {
                if (Util._isDebuffed(_player)) {
                    _damagePerHit = Util._getDebuffedArmyDamagePerHit(_army.troopIds);
                } else {
                    _damagePerHit = Util._getArmyDamagePerHit(_army.troopIds);
                }

                if (_damagePerHit < _targetHealth) {
                    _targetHealth -= _damagePerHit;
                } else {
                    _targetHealth = 0;
                    Util._removeArmyWithTroops(_targetTile.occupantId);
                    emit Util.ArmyDeath(_targetArmy.owner, _targetTile.occupantId);
                }
            }

            if (_targetHealth == 0) break; // target cannot attack back if it has zero health

            // Target attacks Army
            _salt += 1;
            if (Util._strike(Util._getArmyDefenseFactor(_targetArmy.troopIds), _salt)) {
                if (Util._isDebuffed(_player)) {
                    _damagePerHit = Util._getDebuffedArmyDamagePerHit(_army.troopIds);
                } else {
                    _damagePerHit = Util._getArmyDamagePerHit(_army.troopIds);
                }

                if (_damagePerHit < _armyHealth) {
                    _armyHealth -= _damagePerHit;
                } else {
                    _armyHealth = 0;
                    Util._removeArmyWithTroops(_armyId);
                    emit Util.ArmyDeath(_player, _armyId);
                }
            }
        }

        // enemy army died
        if (_targetHealth == 0) {
            uint256 _damageToDistribute = Util._getArmyHealth(_army.troopIds) - _armyHealth;
            Util._damageArmy(_damageToDistribute, _army.troopIds);

            _army = Util._getArmy(_armyId);
            _targetArmy = Util._getArmy(_targetTile.occupantId);
        } else {
            uint256 _damageToDistribute = Util._getArmyHealth(_targetArmy.troopIds) - _targetHealth;
            Util._damageArmy(_damageToDistribute, _targetArmy.troopIds);

            _army = Util._getArmy(_armyId);
            _targetArmy = Util._getArmy(_targetTile.occupantId);
        }

        _updateAttackedArmy(_player, _armyId, _targetTile.occupantId);
    }

    // emits the necessary events to update the army
    function _updateAttackedArmy(
        address _player,
        uint256 _army1Id,
        uint256 _army2Id
    ) public {
        (Army memory _army1, Troop[] memory _troops1) = _getArmyAndTroops(_army1Id);
        (Army memory _army2, Troop[] memory _troops2) = _getArmyAndTroops(_army2Id);

        emit Util.AttackedArmy(_player, _army1Id, _army1, _troops1, _army2Id, _army2, _troops2);
    }

    function _getArmyAndTroops(uint256 _armyId) public view returns (Army memory, Troop[] memory) {
        Army memory _army = Util._getArmy(_armyId);

        Troop[] memory _troops = new Troop[](_army.troopIds.length);
        for (uint256 i = 0; i < _army.troopIds.length; i++) {
            _troops[i] = Util._getTroop(_army.troopIds[i]);
        }

        return (_army, _troops);
    }

    // Check if all troops in army are compatible with tile terrain
    function _geographicCheckArmy(uint256 _armyId, Tile memory _tile) public view returns (bool) {
        Army memory _army = Util._getArmy(_armyId);

        if (_tile.terrain == TERRAIN.WATER) return true; // water tiles are accessible to any troop
        if (_tile.baseId != _NULL() && Util._getBase(_tile.baseId).name == BASE_NAME.PORT) return true; // ports are accessible to any troop

        for (uint256 i = 0; i < _army.troopIds.length; i++) {
            if (Util._getTroopName(Util._getTroop(_army.troopIds[i]).troopTypeId) != TROOP_NAME.INFANTRY) return false;
        }

        return true;
    }

    // Check if troop is compatible with tile terrain
    function _geographicCheckTroop(uint256 _troopTypeId, Tile memory _tile) public view returns (bool) {
        if (_tile.terrain == TERRAIN.WATER) return true; // water tiles are accessible to any troop
        if (_tile.baseId != _NULL() && Util._getBase(_tile.baseId).name == BASE_NAME.PORT) return true; // ports are accessible to any troop
        if (Util._getTroopName(_troopTypeId) == TROOP_NAME.INFANTRY) return true; // infantries can move anywhere

        return false;
    }

    // ----------------------------------------------------------------------
    // MODULES FOR MOVE TROOP
    // ----------------------------------------------------------------------

    function _moveTroopToArmy(uint256 _mainArmyId, uint256 _joiningTroopId) public {
        Troop memory _joiningTroop = Util._getTroop(_joiningTroopId);

        // movementCooldown check and update
        // Army memory _sourceArmy = Util._getArmy(_joiningTroop.armyId);
        // uint256 _movementCooldown = Util._getArmyMovementCooldown(_sourceArmy.troopIds);
        // require((block.timestamp - _sourceArmy.lastMoved) >= _movementCooldown, "CURIO: Moved too recently");
        gs().armyIdMap[_joiningTroop.armyId].lastMoved = block.timestamp;

        gs().troopIdMap[_joiningTroopId].armyId = _mainArmyId;
        gs().armyIdMap[_mainArmyId].troopIds.push(_joiningTroopId);
    }

    // does not clear out source tile
    function _moveNewArmyToEmptyTile(uint256 _newArmyId, Position memory _targetPos) public {
        // Army memory _army = Util._getArmy(_newArmyId);
        // uint256 _movementCooldown = Util._getArmyMovementCooldown(_army.troopIds);
        // require((block.timestamp - _army.lastMoved) >= _movementCooldown, "CURIO: Moved too recently");

        // state change
        gs().map[_targetPos.x][_targetPos.y].occupantId = _newArmyId;
        gs().armyIdMap[_newArmyId].pos = _targetPos;
        gs().armyIdMap[_newArmyId].lastMoved = block.timestamp;
    }

    function _clearTroopFromSourceArmy(uint256 _sourceArmyId, uint256 _troopId) public {
        // state changes for source army: clean up leaving troops
        Army memory _sourceArmy = Util._getArmy(_sourceArmyId);
        uint256 _index = 0;
        while (_index < _sourceArmy.troopIds.length) {
            if (_sourceArmy.troopIds[_index] == _troopId) break;
            _index++;
        }
        gs().armyIdMap[_sourceArmyId].troopIds[_index] = _sourceArmy.troopIds[_sourceArmy.troopIds.length - 1];
        gs().armyIdMap[_sourceArmyId].troopIds.pop();
        // deal with when _sourceArmy is empty
        if (gs().armyIdMap[_sourceArmyId].troopIds.length == 0) {
            Util._removeArmy(_sourceArmyId);
        }
    }

    function _NULL() internal pure returns (uint256) {
        return 0;
    }

    function _NULL_ADRRESS() internal pure returns (address) {
        return address(0);
    }
}
