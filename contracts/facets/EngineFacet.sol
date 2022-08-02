//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/libraries/Storage.sol";
import {Util} from "contracts/libraries/GameUtil.sol";
import {EngineModules} from "contracts/libraries/EngineModules.sol";
import {Army, BASE_NAME, Base, GameState, Player, Position, TERRAIN, Tile, Troop, TroopType, WorldConstants} from "contracts/libraries/Types.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

/// @title Engine facet
/// @notice Contains player functions such as march, purchaseTroop, initializePlayer

contract EngineFacet is UseStorage {
    using SafeMath for uint256;
    uint256 NULL = 0;
    address NULL_ADDR = address(0);

    /**
     * March army to a target position (move, battle, or capture).
     * @param _armyId identifier for troop
     * @param _targetPos target position
     */
    function march(uint256 _armyId, Position memory _targetPos) external {
        // basic check
        require(!gs().isPaused, "CURIO: Game is paused");
        require(Util._isPlayerActive(msg.sender), "CURIO: Player is inactive");
        require(Util._inBound(_targetPos), "CURIO: Target out of bound");
        if (!Util._getTileAt(_targetPos).isInitialized) Util._initializeTile(_targetPos);

        Army memory _army = Util._getArmy(_armyId);
        require(_army.owner == msg.sender, "CURIO: Can only march own troop");
        require(!Util._samePos(_army.pos, _targetPos), "CURIO: Already at destination");
        require((block.timestamp - _army.lastLargeActionTaken) >= Util._getArmyLargeActionCooldown(_army.troopIds), "CURIO: Large action taken too recently");

        Tile memory _targetTile = Util._getTileAt(_targetPos);
        require(EngineModules._geographicCheckArmy(_armyId, _targetTile), "CURIO: Troops and land type not compatible");

        if (_targetTile.occupantId == NULL) {
            if (_targetTile.baseId == NULL) {
                // CaseI: move army when target tile has no base or army
                EngineModules._moveArmy(msg.sender, _armyId, _targetPos);
            } else {
                if (Util._getBaseOwner(_targetTile.baseId) == msg.sender) {
                    // CaseII: move army when target tile has your base but no army
                    EngineModules._moveArmy(msg.sender, _armyId, _targetPos);
                } else {
                    // CaseIII: attack base when target tile has enemy base but no army
                    EngineModules._battleBase(msg.sender, _armyId, _targetPos);
                }
            }
        } else {
            // CaseIV: battle enemy army when target tile has one
            require(gs().armyIdMap[_targetTile.occupantId].owner != msg.sender, "CURIO: Destination tile occupied");
            EngineModules._battleArmy(msg.sender, _armyId, _targetPos);
        }

        Util._updateArmy(msg.sender, _army.pos, _targetPos); // update army info on start tile and end tile
        Util._emitPlayerInfo(msg.sender); // updates player info
    }

    /**
     * Dispatch troop to a target position (_moveArmy, _loadTroop, _clearTroopFromSourceArmy etc.).
     * @param _troopId identifier for troop
     * @param _targetPos target position
     */
    function moveTroop(uint256 _troopId, Position memory _targetPos) public {
        // basic check
        require(!gs().isPaused, "CURIO: Game is paused");
        require(Util._isPlayerActive(msg.sender), "CURIO: Player is inactive");
        require(Util._inBound(_targetPos), "CURIO: Target out of bound");
        if (!Util._getTileAt(_targetPos).isInitialized) Util._initializeTile(_targetPos);

        Troop memory _troop = gs().troopIdMap[_troopId];
        Army memory _army = gs().armyIdMap[_troop.armyId];
        Position memory _startPos = _army.pos;
        Army memory _targetArmy;
        Tile memory _targetTile = Util._getTileAt(_targetPos);

        if (_targetTile.occupantId != NULL) {
            _targetArmy = Util._getArmy(_targetTile.occupantId);
            require(_targetArmy.owner == msg.sender, "CURIO: You can only combine with own troop");
        }

        require(Util._withinDist(_startPos, _targetPos, 1), "CURIO: You can only dispatch troop to the near tile");
        require(_army.owner == msg.sender, "CURIO: You can only dispatch own troop");
        require(!Util._samePos(_startPos, _targetPos), "CURIO: Already at destination");
        require((block.timestamp - _army.lastLargeActionTaken) >= Util._getArmyLargeActionCooldown(_army.troopIds), "CURIO: Large action taken too recently");

        require(EngineModules._geographicCheckTroop(_troop.troopTypeId, _targetTile), "CURIO: Troop and land type not compatible");

        if (_targetTile.occupantId == NULL) {
            // CaseI: Target Tile has no enemy base or enemy army
            require(Util._getBaseOwner(_targetTile.baseId) == msg.sender || _targetTile.baseId == NULL, "CURIO: Cannot directly attack with troops");

            uint256 _newArmyId = Util._createNewArmyFromTroop(msg.sender, _troopId, _startPos);
            EngineModules._moveNewArmyToEmptyTile(_newArmyId, _targetPos);
        } else {
            // CaseII: Target Tile has own army
            require(_targetArmy.troopIds.length + 1 <= 5, "CURIO: Army can have up to five troops, or two with one transport");
            EngineModules._moveTroopToArmy(_targetTile.occupantId, _troopId);
        }
        EngineModules._clearTroopFromSourceArmy(_troop.armyId, _troopId);

        Util._updateArmy(msg.sender, _startPos, _targetPos);
        Util._emitPlayerInfo(msg.sender);
    }

    /**
     * Purchase troop at a base.
     * @param _pos position of base
     * @param _troopTypeId identifier for selected troop type
     */
    function purchaseTroop(Position memory _pos, uint256 _troopTypeId) external {
        require(!gs().isPaused, "CURIO: Game is paused");
        require(Util._isPlayerActive(msg.sender), "CURIO: Player is inactive");

        require(Util._inBound(_pos), "CURIO: Out of bound");
        if (!Util._getTileAt(_pos).isInitialized) Util._initializeTile(_pos);

        Tile memory _tile = Util._getTileAt(_pos);
        require(_tile.baseId != NULL, "CURIO: No base found");
        require(_tile.occupantId == NULL, "CURIO: Base occupied by another troop");

        Base memory _base = Util._getBase(_tile.baseId);
        require(_base.owner == msg.sender, "CURIO: Can only purchase in own base");
        require(EngineModules._geographicCheckTroop(_troopTypeId, _tile), "CURIO: Base cannot purchase selected troop type");

        Util._addTroop(msg.sender, _pos, _troopTypeId);

        uint256 _troopPrice = Util._getTroopGoldPrice(_troopTypeId);
        Util._updatePlayerBalances(msg.sender);
        require(_troopPrice <= Util._getPlayerGoldBalance(msg.sender), "CURIO: Insufficient gold balance");
        gs().playerMap[msg.sender].goldBalance -= _troopPrice;

        Util._emitPlayerInfo(msg.sender);
    }

    /**
     * Delete an owned troop (often to reduce expense).
     * @param _troopId identifier for troop
     */
    function deleteTroop(uint256 _troopId) external {
        Troop memory _troop = Util._getTroop(_troopId);
        Army memory _army = Util._getArmy(_troop.armyId);
        require(_army.owner == msg.sender, "CURIO: Can only delete own troop");

        Util._removeTroop(_troopId);
        EngineModules._updateAttackedArmy(msg.sender, _troop.armyId, _troop.armyId);
    }

    /**
     * Initialize self as player at a selected position.
     * @param _pos position to initialize
     */
    function initializePlayer(Position memory _pos) external {
        require(!gs().isPaused, "CURIO: Game is paused");
        require(Util._getPlayerCount() < gs().worldConstants.maxPlayerCount, "CURIO: Max player count exceeded");
        require(!Util._isPlayerInitialized(msg.sender), "CURIO: Player already initialized");

        require(Util._inBound(_pos), "CURIO: Out of bound");
        if (!Util._getTileAt(_pos).isInitialized) Util._initializeTile(_pos);

        uint256 _baseId = Util._getTileAt(_pos).baseId;
        require(Util._getBaseOwner(_baseId) == NULL_ADDR, "CURIO: Base is taken");

        WorldConstants memory _worldConstants = gs().worldConstants;
        gs().players.push(msg.sender);
        gs().playerMap[msg.sender] = Player({
            initTimestamp: block.timestamp,
            active: true,
            goldBalance: _worldConstants.initPlayerGoldBalance,
            totalGoldGenerationPerUpdate: _worldConstants.defaultBaseGoldGenerationPerSecond,
            totalOilGenerationPerUpdate: 0,
            totalOilConsumptionPerUpdate: 0,
            balanceLastUpdated: block.timestamp,
            numOwnedBases: 1,
            numOwnedTroops: 0,
            isDebuffed: false //
        });
        gs().baseIdMap[_baseId].owner = msg.sender;
        gs().baseIdMap[_baseId].health = 800;

        emit Util.NewPlayer(msg.sender, _pos);

        Util._emitPlayerInfo(msg.sender);
    }
}
