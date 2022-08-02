//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// Data structures for game

enum BASE_NAME {
    PORT,
    CITY,
    OIL_WELL
}

// TODO: allow bases to consume oil

enum TERRAIN {
    COAST,
    INLAND,
    WATER
}

enum TROOP_NAME {
    INFANTRY,
    DESTROYER,
    CRUISER,
    BATTLESHIP
}

struct Position {
    uint256 x;
    uint256 y;
}

struct Player {
    uint256 initTimestamp;
    bool active;
    uint256 goldBalance;
    uint256 totalGoldGenerationPerUpdate;
    uint256 totalOilGenerationPerUpdate;
    uint256 totalOilConsumptionPerUpdate;
    uint256 balanceLastUpdated;
    uint256 numOwnedBases;
    uint256 numOwnedTroops;
    bool isDebuffed;
}

struct Base {
    BASE_NAME name;
    address owner;
    uint256 attackFactor;
    uint256 defenseFactor;
    uint256 health;
    uint256 goldGenerationPerSecond;
    uint256 oilGenerationPerSecond;
    Position pos;
}

struct Tile {
    bool isInitialized;
    TERRAIN terrain;
    uint256 occupantId; // armyID
    uint256 baseId;
}

struct Army {
    address owner;
    uint256[] troopIds; // troopIds
    uint256 lastMoved;
    uint256 lastLargeActionTaken;
    Position pos;
}

struct Troop {
    uint256 armyId;
    uint256 troopTypeId;
    uint256 health;
}

struct TroopType {
    TROOP_NAME name;
    uint256 maxHealth;
    uint256 damagePerHit;
    uint256 attackFactor; // in the interval [0, 100]
    uint256 defenseFactor; // in the interval [0, 100]
    uint256 movementCooldown;
    uint256 largeActionCooldown;
    uint256 goldPrice;
    uint256 oilConsumptionPerSecond;
}

struct WorldConstants {
    address admin;
    uint256 worldWidth;
    uint256 worldHeight;
    uint256 combatEfficiency; // in the interval [0, 100]
    uint256 numInitTerrainTypes; // default is 6
    uint256 initBatchSize; // default is 50 if numInitTerrainTypes = 6
    uint256 initPlayerGoldBalance;
    uint256 initPlayerOilBalance;
    uint256 maxBaseCountPerPlayer;
    uint256 maxTroopCountPerPlayer;
    uint256 maxPlayerCount;
    uint256 defaultBaseGoldGenerationPerSecond;
    uint256 defaultWellOilGenerationPerSecond;
    uint256 debuffFactor; // in the interval [0, 100]. 100 means losing everything, 0 means debuff affects nothing
}

struct GameState {
    bool isPaused;
    uint256 lastPaused;
    WorldConstants worldConstants;
    address[] players;
    mapping(address => Player) playerMap;
    mapping(address => uint256[]) playerTroopIdMap;
    Tile[5000][5000] map;
    uint256[] baseIds;
    uint256 baseNonce;
    mapping(uint256 => Base) baseIdMap;
    uint256[] troopIds;
    uint256[] armyIds;
    uint256 troopNonce;
    uint256 armyNonce;
    mapping(uint256 => Troop) troopIdMap;
    mapping(uint256 => Army) armyIdMap;
    uint256[] troopTypeIds;
    mapping(uint256 => TroopType) troopTypeIdMap;
    uint256[][] encodedColumnBatches;
}
