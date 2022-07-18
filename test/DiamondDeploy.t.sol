//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "contracts/facets/DiamondCutFacet.sol";
import "contracts/facets/DiamondLoupeFacet.sol";
import "contracts/facets/OwnershipFacet.sol";
import "contracts/diamond.sol";
import "contracts/upgradeInitializers/diamondInit.sol";
import "contracts/interfaces/IDiamondCut.sol";
import "contracts/libraries/GameUtil.sol";
import "contracts/facets/GetterFacet.sol";
import "contracts/facets/EngineFacet.sol";
import "contracts/facets/HelperFacet.sol";
import "contracts/libraries/Types.sol";

/// @title diamond deploy foundry template
/// @notice This contract sets up the diamond for testing and is inherited by other foundry test contracts.

contract DiamondDeployTest is Test {
    address public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondInit public diamondInit;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public diamondOwnershipFacet;
    EngineFacet public engineFacet;
    GetterFacet public getterFacet;
    HelperFacet public helperFacet;

    // diamond-contract-casted methods
    EngineFacet public engine;
    GetterFacet public getter;
    HelperFacet public helper;
    OwnershipFacet public ownership;

    uint256 public NULL = 0;
    address public NULL_ADDR = address(0);

    address public deployer = address(0);
    address public player1 = address(1);
    address public player2 = address(2);
    address public player3 = address(3);

    Position public player1Pos = Position({x: 6, y: 1});
    Position public player2Pos = Position({x: 6, y: 3});
    Position public player3Pos = Position({x: 5, y: 2});

    uint256 public initTroopNonce = 1;

    uint256 public armyTroopTypeId = indexToId(uint256(TROOP_NAME.ARMY));
    uint256 public troopTransportTroopTypeId = indexToId(uint256(TROOP_NAME.TROOP_TRANSPORT));
    uint256 public destroyerTroopTypeId = indexToId(uint256(TROOP_NAME.DESTROYER));
    uint256 public battleshipTroopTypeId = indexToId(uint256(TROOP_NAME.BATTLESHIP));

    // troop types
    TroopType public armyTroopType =
        TroopType({
            name: TROOP_NAME.ARMY,
            isLandTroop: true,
            maxHealth: 1,
            damagePerHit: 1,
            attackFactor: 100,
            defenseFactor: 100,
            cargoCapacity: 0,
            movementCooldown: 1,
            largeActionCooldown: 1,
            cost: 6,
            expensePerSecond: 0 //
        });
    TroopType public troopTransportTroopType =
        TroopType({
            name: TROOP_NAME.TROOP_TRANSPORT,
            isLandTroop: false,
            maxHealth: 3,
            damagePerHit: 1,
            attackFactor: 50,
            defenseFactor: 50,
            cargoCapacity: 6,
            movementCooldown: 1,
            largeActionCooldown: 1,
            cost: 14,
            expensePerSecond: 1 //
        });
    TroopType public destroyerTroopType =
        TroopType({
            name: TROOP_NAME.DESTROYER,
            isLandTroop: false,
            maxHealth: 3,
            damagePerHit: 1,
            attackFactor: 100,
            defenseFactor: 100,
            cargoCapacity: 0,
            movementCooldown: 1,
            largeActionCooldown: 1,
            cost: 20,
            expensePerSecond: 1 //
        });
    TroopType public cruiserTroopType =
        TroopType({
            name: TROOP_NAME.CRUISER,
            isLandTroop: false,
            maxHealth: 8,
            damagePerHit: 2,
            attackFactor: 100,
            defenseFactor: 100,
            cargoCapacity: 0,
            movementCooldown: 1,
            largeActionCooldown: 1,
            cost: 30,
            expensePerSecond: 1 //
        });
    TroopType public battleshipTroopType =
        TroopType({
            name: TROOP_NAME.BATTLESHIP,
            isLandTroop: false,
            maxHealth: 12,
            damagePerHit: 3,
            attackFactor: 100,
            defenseFactor: 100,
            cargoCapacity: 0,
            movementCooldown: 1,
            largeActionCooldown: 1,
            cost: 50,
            expensePerSecond: 2 //
        });

    // we assume these two facet selectors do not change. If they do however, we should use getSelectors
    bytes4[] OWNERSHIP_SELECTORS = [bytes4(0xf2fde38b), 0x8da5cb5b];
    bytes4[] LOUPE_SELECTORS = [bytes4(0xcdffacc6), 0x52ef6b2c, 0xadfca15e, 0x7a0ed627, 0x01ffc9a7];

    function setUp() public {
        vm.startPrank(deployer);

        diamondCutFacet = new DiamondCutFacet();
        diamond = address(new Diamond(deployer, address(diamondCutFacet)));
        diamondInit = new DiamondInit();
        diamondLoupeFacet = new DiamondLoupeFacet();
        diamondOwnershipFacet = new OwnershipFacet();

        helperFacet = new HelperFacet();
        engineFacet = new EngineFacet();
        getterFacet = new GetterFacet();

        WorldConstants memory _worldConstants = _generateWorldConstants();
        TroopType[] memory _troopTypes = _generateTroopTypes();

        // fetch args from cli. craft payload for init deploy
        bytes memory initData = abi.encodeWithSelector(getSelectors("DiamondInit")[0], _worldConstants, _troopTypes);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);
        cuts[0] = IDiamondCut.FacetCut({facetAddress: address(diamondLoupeFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: LOUPE_SELECTORS});
        cuts[1] = IDiamondCut.FacetCut({facetAddress: address(diamondOwnershipFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: OWNERSHIP_SELECTORS});
        cuts[2] = IDiamondCut.FacetCut({facetAddress: address(engineFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: getSelectors("EngineFacet")});
        cuts[3] = IDiamondCut.FacetCut({facetAddress: address(getterFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: getSelectors("GetterFacet")});
        cuts[4] = IDiamondCut.FacetCut({facetAddress: address(helperFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: getSelectors("HelperFacet")});

        IDiamondCut(diamond).diamondCut(cuts, address(diamondInit), initData);

        helper = HelperFacet(diamond);
        getter = GetterFacet(diamond);
        engine = EngineFacet(diamond);
        ownership = OwnershipFacet(diamond);

        // initialize map using lazy + encoding
        uint256[][] memory _map = _generateMap(_worldConstants.worldWidth, _worldConstants.worldHeight, 10);
        uint256[][] memory _encodedColumnBatches = _encodeTileMap(_map, _worldConstants.numInitTerrainTypes, _worldConstants.initBatchSize);
        helper.storeEncodedColumnBatches(_encodedColumnBatches);

        vm.stopPrank();

        // initialize players
        vm.prank(player1);
        engine.initializePlayer(player1Pos);
        vm.prank(player2);
        engine.initializePlayer(player2Pos);
        vm.prank(player3);
        engine.initializePlayer(player3Pos);
    }

    function _encodeTileMap(
        uint256[][] memory _tileMap,
        uint256 _numInitTerrainTypes,
        uint256 _batchSize
    ) internal pure returns (uint256[][] memory) {
        uint256[][] memory _result = new uint256[][](_tileMap.length);
        uint256 _numBatchPerCol = _tileMap[0].length / _batchSize;
        uint256 _lastBatchSize = _tileMap[0].length % _batchSize;

        uint256[] memory _encodedCol;
        uint256 _temp;
        uint256 k;

        for (uint256 x = 0; x < _tileMap.length; x++) {
            _encodedCol = new uint256[](_numBatchPerCol + 1);
            for (k = 0; k < _numBatchPerCol; k++) {
                _encodedCol[k] = 0;
                for (uint256 y = 0; y < _batchSize; y++) {
                    _temp = _encodedCol[k] + _tileMap[x][k * _batchSize + y] * _numInitTerrainTypes**y;
                    if (_temp < _encodedCol[k]) revert("Integer overflow");
                    _encodedCol[k] = _temp;
                }
            }
            if (_lastBatchSize > 0) {
                _encodedCol[k] = 0;
                for (uint256 y = 0; y < _lastBatchSize; y++) {
                    _temp = _encodedCol[k] + _tileMap[x][k * _batchSize + y] * _numInitTerrainTypes**y;
                    if (_temp < _encodedCol[k]) revert("Integer overflow");
                    _encodedCol[k] = _temp;
                }
                _encodedCol[k] = _temp;
            }
            _result[x] = _encodedCol;
        }

        return _result;
    }

    // Note: hardcoded
    function _generateWorldConstants() internal view returns (WorldConstants memory) {
        return
            WorldConstants({
                admin: deployer,
                worldWidth: 1000,
                worldHeight: 1000,
                numPorts: 15,
                numCities: 15, // yo
                combatEfficiency: 50,
                numInitTerrainTypes: 5,
                initBatchSize: 100,
                initPlayerBalance: 20,
                defaultBaseGoldGenerationPerSecond: 5,
                maxBaseCountPerPlayer: 20,
                maxTroopCountPerPlayer: 20,
                maxPlayerCount: 50
            });
    }

    // Note: hardcoded
    function _generateTroopTypes() internal view returns (TroopType[] memory) {
        TroopType[] memory _troopTypes = new TroopType[](5);
        _troopTypes[0] = armyTroopType;
        _troopTypes[1] = troopTransportTroopType;
        _troopTypes[2] = destroyerTroopType;
        _troopTypes[3] = cruiserTroopType;
        _troopTypes[4] = battleshipTroopType;
        return _troopTypes;
    }

    // Note: hardcoded
    function _generateMap(
        uint256 _width,
        uint256 _height,
        uint256 _interval
    ) public pure returns (uint256[][] memory) {
        uint256[] memory _coastCol = new uint256[](_height);
        uint256[] memory _landCol = new uint256[](_height);
        uint256[] memory _waterCol = new uint256[](_height);
        uint256[] memory _portCol = new uint256[](_height);
        uint256[] memory _cityCol = new uint256[](_height);

        for (uint256 y = 0; y < _height; y++) {
            _coastCol[y] = 0;
            _landCol[y] = 1;
            _waterCol[y] = 2;
            _portCol[y] = 3;
            _cityCol[y] = 4;
        }

        uint256[][] memory _map = new uint256[][](_width);
        for (uint256 x = 0; x < _width; x += _interval) {
            _map[x] = _waterCol;
            _map[x + 1] = _waterCol;
            _map[x + 2] = _portCol;
            _map[x + 3] = _landCol;
            _map[x + 4] = _landCol;
            _map[x + 5] = _cityCol;
            _map[x + 6] = _portCol;
            _map[x + 7] = _waterCol;
            _map[x + 8] = _coastCol;
            _map[x + 9] = _landCol;
        }

        return _map;
    }

    // helper functions

    // generates values that need to be initialized from the cli and pipes it back into solidity! magic
    function getInitVal() public returns (WorldConstants memory _constants, TroopType[] memory _troopTypes) {
        string[] memory runJsInputs = new string[](4);
        runJsInputs[0] = "yarn";
        runJsInputs[1] = "--silent";
        runJsInputs[2] = "run";
        runJsInputs[3] = "getInitParams";

        bytes memory res = vm.ffi(runJsInputs);

        (_constants, _troopTypes) = abi.decode(res, (WorldConstants, TroopType[]));
    }

    function getSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](5);
        cmd[0] = "yarn";
        cmd[1] = "--silent";
        cmd[2] = "run";
        cmd[3] = "getFuncSelectors";
        cmd[4] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    // FIXME: change to 999
    function indexToId(uint256 _index) public pure returns (uint256) {
        return _index + 1;
    }
}
