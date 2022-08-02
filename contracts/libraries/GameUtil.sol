//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/libraries/Storage.sol";
import {BASE_NAME, TROOP_NAME, Base, GameState, Player, Position, TERRAIN, Tile, Troop, Army, WorldConstants, TroopType} from "contracts/libraries/Types.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

/// @title Util library
/// @notice Contains all events as well as lower-level setters and getters
/// Util functions generally do not verify correctness of conditions. Make sure to verify in higher-level functions such as those in Engine.
/// Note: This file should not have any occurrences of `msg.sender`. Pass in player addresses to use them.

library Util {
    using SafeMath for uint256;

    function gs() internal pure returns (GameState storage) {
        return LibStorage.gameStorage();
    }

    // ----------------------------------------------------------
    // EVENTS
    // ----------------------------------------------------------

    event MovedArmy(address _player, uint256 timestamp, Position _startPos, uint256 _startTileArmyId, Army _startTileArmy, Position _endPos, uint256 _targetTileArmyId, Army _targetTileArmy);
    event NewTroop(address _player, uint256 _troopId, Troop _troop, uint256 _armyId, Army _army);
    event NewPlayer(address _player, Position _pos);
    event PlayerInfo(address _addr, Player _player);
    event ArmyDeath(address _player, uint256 _armyId);
    event AttackedArmy(address _player, uint256 _armyId, Army _armyInfo, Troop[] _armyTroops, uint256 _targetArmy, Army _targetArmyInfo, Troop[] _targetArmyTroops);
    event TroopDeath(address _player, uint256 _troopId);
    event BaseInfo(address _player, uint256 _baseId, Base _Base);

    event PlayerReactivated(address _player);
    event GamePaused();
    event GameResumed();

    // ----------------------------------------------------------
    // SETTERS
    // ----------------------------------------------------------

    function _initializeTile(Position memory _pos) public {
        WorldConstants memory _worldConstants = gs().worldConstants;
        uint256 _batchSize = _worldConstants.initBatchSize;
        uint256 _numInitTerrainTypes = _worldConstants.numInitTerrainTypes;

        uint256 _encodedCol = gs().encodedColumnBatches[_pos.x][_pos.y / _batchSize] % (_numInitTerrainTypes**((_pos.y % _batchSize) + 1));
        uint256 _divFactor = _numInitTerrainTypes**(_pos.y % _batchSize);
        uint256 _terrainId = _encodedCol / _divFactor;

        if (_terrainId >= 3) {
            BASE_NAME _baseName = BASE_NAME(_terrainId - 3);
            _addBase(_pos, _baseName);

            if (BASE_NAME(_terrainId - 3) == BASE_NAME.OIL_WELL) {
                _terrainId = 1;
            } else {
                _terrainId -= 3;
            }
        }

        gs().map[_pos.x][_pos.y].isInitialized = true;
        gs().map[_pos.x][_pos.y].terrain = TERRAIN(_terrainId);
    }

    function _updatePlayerBalances(address _addr) public {
        Player memory _player = gs().playerMap[_addr];
        uint256 _timeElapsed = block.timestamp - _player.balanceLastUpdated;

        // Update gold balance
        _player.goldBalance += _player.totalGoldGenerationPerUpdate * _timeElapsed;

        // Update debuff status based on oil rate
        if (_player.totalOilGenerationPerUpdate >= _player.totalOilConsumptionPerUpdate) {
            _player.isDebuffed = false;
        } else {
            _player.isDebuffed = true;
        }

        _player.balanceLastUpdated = block.timestamp;
        gs().playerMap[_addr] = _player;
    }

    function _removeArmyWithTroops(uint256 _armyId) public {
        Army memory _army = _getArmy(_armyId);
        address _owner = _army.owner;
        Position memory _pos = _army.pos;

        _updatePlayerBalances(_owner);
        gs().playerMap[_owner].numOwnedTroops -= _army.troopIds.length;
        gs().playerMap[_owner].totalOilConsumptionPerUpdate -= _getArmyOilConsumptionPerSecond(_army.troopIds);
        gs().map[_pos.x][_pos.y].occupantId = _NULL();

        uint256 _troopId;
        for (uint256 i = 0; i < _army.troopIds.length; i++) {
            _troopId = _army.troopIds[i];

            // Update player troops
            uint256[] memory _playerTroopIds = gs().playerTroopIdMap[_owner];
            uint256 _index = _getIndex(_troopId, _playerTroopIds);
            gs().playerTroopIdMap[_owner][_index] = _playerTroopIds[_playerTroopIds.length - 1];
            gs().playerTroopIdMap[_owner].pop();

            delete gs().troopIdMap[_troopId];
        }
        delete gs().armyIdMap[_armyId];
    }

    function _removeArmy(uint256 _armyId) public {
        // used when detaching army
        Army memory _army = _getArmy(_armyId);
        require(_army.troopIds.length == 0, "CURIO: Undefined behavior in _removeArmy");

        Position memory _pos = _army.pos;

        delete gs().armyIdMap[_armyId];

        gs().map[_pos.x][_pos.y].occupantId = _NULL();
    }

    function _damageArmy(uint256 _totalDamage, uint256[] memory _armyTroopIds) public {
        uint256 _individualDamage = _totalDamage / _armyTroopIds.length;
        uint256 _remainingDamage = _totalDamage % _armyTroopIds.length;

        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            uint256 _damage = _remainingDamage > 0 ? _individualDamage + 1 : _individualDamage;
            _damageTroop(_damage, _armyTroopIds[i]);
            if (_remainingDamage > 0) _remainingDamage--;
        }
    }

    function _removeTroop(uint256 _troopId) public {
        Troop memory _troop = _getTroop(_troopId);
        Army memory _army = _getArmy(_troop.armyId);

        address _owner = _army.owner;
        Position memory _pos = _army.pos;

        uint256 _numOwnedTroops = gs().playerMap[_owner].numOwnedTroops;
        uint256 _totalOilConsumptionPerUpdate = gs().playerMap[_owner].totalOilConsumptionPerUpdate;

        _numOwnedTroops--;
        _totalOilConsumptionPerUpdate -= _getOilConsumptionPerSecond(_troop.troopTypeId);
        delete gs().troopIdMap[_troopId];

        _updatePlayerBalances(_owner);
        gs().playerMap[_owner].numOwnedTroops = _numOwnedTroops;
        gs().playerMap[_owner].totalOilConsumptionPerUpdate = _totalOilConsumptionPerUpdate;

        // Update player troops
        uint256[] memory _playerTroopIds = gs().playerTroopIdMap[_owner];
        uint256 _index = _getIndex(_troopId, _playerTroopIds);
        gs().playerTroopIdMap[_owner][_index] = _playerTroopIds[_playerTroopIds.length - 1];
        gs().playerTroopIdMap[_owner].pop();

        // Update army troops
        _index = _getIndex(_troopId, _army.troopIds);
        gs().armyIdMap[_troop.armyId].troopIds[_index] = _army.troopIds[_army.troopIds.length - 1];
        gs().armyIdMap[_troop.armyId].troopIds.pop();

        // If army contains no troop, remove army from transport or tile
        if (gs().armyIdMap[_troop.armyId].troopIds.length == 0) {
            gs().map[_pos.x][_pos.y].occupantId = _NULL();
        }
    }

    function _damageTroop(uint256 _damage, uint256 _troopId) public {
        uint256 _health = gs().troopIdMap[_troopId].health;

        if (_damage >= _health) {
            _removeTroop(_troopId);
        } else {
            gs().troopIdMap[_troopId].health = _health - _damage;
        }
    }

    function _addTroop(
        address _owner,
        Position memory _pos,
        uint256 _troopTypeId
    ) public returns (uint256, Army memory) {
        require(_getPlayer(_owner).numOwnedTroops < gs().worldConstants.maxTroopCountPerPlayer, "CURIO: Max troop count exceeded");

        // Generate Troop and Army id
        uint256 _troopId = gs().troopNonce;
        gs().troopIds.push(_troopId);
        gs().troopNonce++;

        uint256 _armyId = gs().armyNonce;
        gs().armyIds.push(_armyId);
        gs().armyNonce++;
        gs().map[_pos.x][_pos.y].occupantId = _armyId;

        Troop memory _troop = Troop({armyId: _armyId, troopTypeId: _troopTypeId, health: _getMaxHealth(_troopTypeId)});

        uint256[] memory troopIds = new uint256[](1);
        troopIds[0] = _troopId;

        Army memory _army = Army({owner: _owner, troopIds: troopIds, lastMoved: block.timestamp, lastLargeActionTaken: block.timestamp, pos: _pos});

        gs().troopIdMap[_troopId] = _troop;
        gs().armyIdMap[_armyId] = _army;

        // Update balances
        _updatePlayerBalances(_owner);
        gs().playerMap[_owner].numOwnedTroops++;
        gs().playerMap[_owner].totalOilConsumptionPerUpdate += _getOilConsumptionPerSecond(_troopTypeId);
        gs().playerTroopIdMap[_owner].push(_troopId);

        emit NewTroop(_owner, _troopId, _troop, _armyId, _army);

        return (_armyId, _army);
    }

    function _createNewArmyFromTroop(
        address _owner,
        uint256 _troopID,
        Position memory _pos
    ) public returns (uint256) {
        require(_getPlayer(_owner).numOwnedTroops < gs().worldConstants.maxTroopCountPerPlayer, "CURIO: Max troop count exceeded");

        uint256 _armyId = gs().armyNonce;
        gs().armyIds.push(_armyId);
        gs().armyNonce++;

        uint256[] memory _armyTroopIds;
        Army memory _army = Army({owner: _owner, troopIds: _armyTroopIds, lastMoved: 0, lastLargeActionTaken: block.timestamp, pos: _pos});

        gs().armyIdMap[_armyId] = _army;
        gs().armyIdMap[_armyId].troopIds.push(_troopID);

        gs().troopIdMap[_troopID].armyId = _armyId;

        return _armyId;
    }

    function _addBase(Position memory _pos, BASE_NAME _baseName) public returns (uint256) {
        bool _isOilWell = _baseName == BASE_NAME.OIL_WELL;
        uint256 _goldGenerationPerSecond = _isOilWell ? 0 : gs().worldConstants.defaultBaseGoldGenerationPerSecond;
        uint256 _oilGenerationPerSecond = _isOilWell ? gs().worldConstants.defaultWellOilGenerationPerSecond : 0;

        Base memory _base = Base({
            owner: address(0),
            name: _baseName,
            attackFactor: 100,
            defenseFactor: 100,
            health: 150,
            goldGenerationPerSecond: _goldGenerationPerSecond,
            oilGenerationPerSecond: _oilGenerationPerSecond,
            pos: _pos //
        });

        uint256 _baseId = gs().baseNonce;
        gs().baseIds.push(_baseId);
        gs().baseIdMap[_baseId] = _base;
        gs().baseNonce += 1;
        gs().map[_pos.x][_pos.y].baseId = _baseId;

        return _baseId;
    }

    function _updateArmy(
        address _owner,
        Position memory _pos1,
        Position memory _pos2
    ) public {
        Tile memory _tile1 = _getTileAt(_pos1);
        Tile memory _tile2 = _getTileAt(_pos2);
        Army memory _army1 = _getArmy(_tile1.occupantId);
        Army memory _army2 = _getArmy(_tile2.occupantId);

        emit MovedArmy(_owner, block.timestamp, _pos1, _tile1.occupantId, _army1, _pos2, _tile2.occupantId, _army2);
    }

    function _emitPlayerInfo(address _player) public {
        Player memory _playerInfo = _getPlayer(_player);

        emit PlayerInfo(_player, _playerInfo);
    }

    // ----------------------------------------------------------
    // GETTERS
    // ----------------------------------------------------------

    function _isPlayerInitialized(address _player) public view returns (bool) {
        address[] memory _allPlayers = gs().players;
        for (uint256 i = 0; i < _allPlayers.length; i++) {
            if (_allPlayers[i] == _player) return true;
        }
        return false;
    }

    function _getPlayerCount() public view returns (uint256) {
        return gs().players.length;
    }

    function _getPlayer(address _player) public view returns (Player memory) {
        return gs().playerMap[_player];
    }

    function _isPlayerActive(address _player) public view returns (bool) {
        return gs().playerMap[_player].active;
    }

    function _getPlayerGoldBalance(address _player) public view returns (uint256) {
        return gs().playerMap[_player].goldBalance;
    }

    function _getTotalGoldGenerationPerUpdate(address _player) public view returns (uint256) {
        return gs().playerMap[_player].totalGoldGenerationPerUpdate;
    }

    function _isDebuffed(address _player) public view returns (bool) {
        return gs().playerMap[_player].isDebuffed;
    }

    function _getTroop(uint256 _troopId) public view returns (Troop memory) {
        return gs().troopIdMap[_troopId];
    }

    function _getArmy(uint256 _armyId) public view returns (Army memory) {
        return gs().armyIdMap[_armyId];
    }

    function _getDebuffedArmyDamagePerHit(uint256[] memory _armyTroopIds) public view returns (uint256) {
        uint256 _infantryPercentage = _getArmyInfantryPercentage(_armyTroopIds);
        uint256 _debuffFactor = (gs().worldConstants.debuffFactor * (100 - _infantryPercentage)) / 100; // Only non-infantries are debuffed
        return (_getArmyDamagePerHit(_armyTroopIds) * (100 - _debuffFactor)) / 100;
    }

    function _getArmyInfantryPercentage(uint256[] memory _armyTroopIds) public view returns (uint256) {
        require(_armyTroopIds.length > 0, "CURIO: Cannot calculate percentage for empty army");

        uint256 _percentagePerTroop = 100 / _armyTroopIds.length;
        uint256 _result = 0;

        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            if (_getTroopName(_armyTroopIds[i]) == TROOP_NAME.INFANTRY) {
                _result += _percentagePerTroop;
            }
        }

        return _result;
    }

    function _getOilConsumptionPerSecond(uint256 _troopTypeId) public view returns (uint256) {
        return gs().troopTypeIdMap[_troopTypeId].oilConsumptionPerSecond;
    }

    function _getArmyOilConsumptionPerSecond(uint256[] memory _armyTroopIds) public view returns (uint256) {
        uint256 _ArmyOilConsumptionPerSecond;
        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            Troop memory _troop = _getTroop(_armyTroopIds[i]);
            _ArmyOilConsumptionPerSecond += _getOilConsumptionPerSecond(_troop.troopTypeId);
        }
        return _ArmyOilConsumptionPerSecond;
    }

    function _getMaxHealth(uint256 _troopTypeId) public view returns (uint256) {
        return gs().troopTypeIdMap[_troopTypeId].maxHealth;
    }

    function _getTroopName(uint256 _troopTypeId) public view returns (TROOP_NAME) {
        return gs().troopTypeIdMap[_troopTypeId].name;
    }

    function _getTroopGoldPrice(uint256 _troopTypeId) public view returns (uint256) {
        return gs().troopTypeIdMap[_troopTypeId].goldPrice;
    }

    function _getDamagePerHit(uint256 _troopTypeId) public view returns (uint256) {
        return gs().troopTypeIdMap[_troopTypeId].damagePerHit;
    }

    function _getDefenseFactor(uint256 _troopTypeId) public view returns (uint256) {
        return gs().troopTypeIdMap[_troopTypeId].defenseFactor;
    }

    function _getAttackFactor(uint256 _troopTypeId) public view returns (uint256) {
        return gs().troopTypeIdMap[_troopTypeId].attackFactor;
    }

    function _getMovementCooldown(uint256 _troopTypeId) public view returns (uint256) {
        return gs().troopTypeIdMap[_troopTypeId].movementCooldown;
    }

    function _getLargeActionCooldown(uint256 _troopTypeId) public view returns (uint256) {
        return gs().troopTypeIdMap[_troopTypeId].largeActionCooldown;
    }

    function _getArmyHealth(uint256[] memory _armyTroopIds) public view returns (uint256) {
        // take the sum
        uint256 _totalHealth;

        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            _totalHealth += _getTroop(_armyTroopIds[i]).health;
        }

        return _totalHealth;
    }

    function _getArmyMovementCooldown(uint256[] memory _armyTroopIds) public view returns (uint256) {
        // take the longest cooldown
        uint256 _longestMovementCooldown;

        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            uint256 _troopMovementCooldown = _getMovementCooldown(_getTroop(_armyTroopIds[i]).troopTypeId);
            if (_troopMovementCooldown > _longestMovementCooldown) {
                _longestMovementCooldown = _troopMovementCooldown;
            }
        }
        return _longestMovementCooldown;
    }

    function _getArmyLargeActionCooldown(uint256[] memory _armyTroopIds) public view returns (uint256) {
        // take the longest cooldown
        uint256 _longestLargeActionCooldown;

        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            uint256 _troopLargeActionCooldown = _getLargeActionCooldown(_getTroop(_armyTroopIds[i]).troopTypeId);
            if (_troopLargeActionCooldown > _longestLargeActionCooldown) {
                _longestLargeActionCooldown = _troopLargeActionCooldown;
            }
        }

        return _longestLargeActionCooldown;
    }

    function _getArmyAttackFactor(uint256[] memory _armyTroopIds) public view returns (uint256) {
        // take the average
        uint256 _attackFactorSum;

        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            _attackFactorSum += _getAttackFactor(_getTroop(_armyTroopIds[i]).troopTypeId);
        }

        return _attackFactorSum / _armyTroopIds.length;
    }

    function _getArmyDefenseFactor(uint256[] memory _armyTroopIds) public view returns (uint256) {
        // take the average
        uint256 _defenseFactorSum;

        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            _defenseFactorSum += _getDefenseFactor(_getTroop(_armyTroopIds[i]).troopTypeId);
        }

        return _defenseFactorSum / _armyTroopIds.length;
    }

    function _getArmyDamagePerHit(uint256[] memory _armyTroopIds) public view returns (uint256) {
        // take the sum
        uint256 _totalDamagePerHit = 0;

        for (uint256 i = 0; i < _armyTroopIds.length; i++) {
            _totalDamagePerHit += _getDamagePerHit(_getTroop(_armyTroopIds[i]).troopTypeId);
        }

        return _totalDamagePerHit;
    }

    function _getBaseHealth(uint256 _baseId) public view returns (uint256) {
        return gs().baseIdMap[_baseId].health;
    }

    function _getBaseOwner(uint256 _baseId) public view returns (address) {
        return gs().baseIdMap[_baseId].owner;
    }

    function _getBase(uint256 _id) public view returns (Base memory) {
        return gs().baseIdMap[_id];
    }

    function _hasPort(Tile memory _tile) public view returns (bool) {
        return _tile.baseId != _NULL() && gs().baseIdMap[_tile.baseId].name == BASE_NAME.PORT;
    }

    function _getTileAt(Position memory _pos) public view returns (Tile memory) {
        return gs().map[_pos.x][_pos.y];
    }

    function _strike(uint256 _strikeFactor, uint256 _salt) public view returns (bool) {
        uint256 _rand = _random(100, _salt);
        return _rand * 100 < _strikeFactor * gs().worldConstants.combatEfficiency;
    }

    function _inBound(Position memory _p) public view returns (bool) {
        return _p.x >= 0 && _p.x < gs().worldConstants.worldWidth && _p.y >= 0 && _p.y < gs().worldConstants.worldHeight;
    }

    function _random(uint256 _max, uint256 _salt) public view returns (uint256) {
        return uint256(keccak256(abi.encode(block.timestamp, block.difficulty, _salt))) % _max;
    }

    function _samePos(Position memory _p1, Position memory _p2) public pure returns (bool) {
        return _p1.x == _p2.x && _p1.y == _p2.y;
    }

    // Note: The current version treats a diagonal movement as two movements.
    // For treating as one, use `xDist <= _dist && yDist <= _dist` as return condition.
    function _withinDist(
        Position memory _p1,
        Position memory _p2,
        uint256 _dist
    ) public pure returns (bool) {
        uint256 _xDist = _p1.x >= _p2.x ? _p1.x - _p2.x : _p2.x - _p1.x;
        uint256 _yDist = _p1.y >= _p2.y ? _p1.y - _p2.y : _p2.y - _p1.y;
        return (_xDist + _yDist) <= _dist;
    }

    function _NULL() internal pure returns (uint256) {
        return 0;
    }

    function _NULL_ADRESS() internal pure returns (address) {
        return address(0);
    }

    function _getIndex(uint256 _item, uint256[] memory _arr) internal pure returns (uint256) {
        uint256 _index = 0;
        while (_index < _arr.length) {
            if (_arr[_index] == _item) break;
            _index++;
        }
        return _index;
    }
}
