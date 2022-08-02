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

    uint256 public infantryTroopTypeId = indexToId(uint256(TROOP_NAME.INFANTRY));
    uint256 public destroyerTroopTypeId = indexToId(uint256(TROOP_NAME.DESTROYER));
    uint256 public battleshipTroopTypeId = indexToId(uint256(TROOP_NAME.BATTLESHIP));

    // troop types
    TroopType public infantryTroopType =
        TroopType({
            name: TROOP_NAME.INFANTRY,
            maxHealth: 100,
            damagePerHit: 100,
            attackFactor: 100,
            defenseFactor: 100,
            movementCooldown: 1,
            largeActionCooldown: 1,
            goldPrice: 6,
            oilConsumptionPerSecond: 1 //
        });
    TroopType public destroyerTroopType =
        TroopType({
            name: TROOP_NAME.DESTROYER,
            maxHealth: 300,
            damagePerHit: 100,
            attackFactor: 100,
            defenseFactor: 100,
            movementCooldown: 1,
            largeActionCooldown: 1,
            goldPrice: 20,
            oilConsumptionPerSecond: 1 //
        });
    TroopType public cruiserTroopType =
        TroopType({
            name: TROOP_NAME.CRUISER,
            maxHealth: 800,
            damagePerHit: 200,
            attackFactor: 100,
            defenseFactor: 100,
            movementCooldown: 1,
            largeActionCooldown: 1,
            goldPrice: 30,
            oilConsumptionPerSecond: 1 //
        });
    TroopType public battleshipTroopType =
        TroopType({
            name: TROOP_NAME.BATTLESHIP,
            maxHealth: 1200,
            damagePerHit: 300,
            attackFactor: 100,
            defenseFactor: 100,
            movementCooldown: 1,
            largeActionCooldown: 1,
            goldPrice: 50,
            oilConsumptionPerSecond: 2 //
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
                combatEfficiency: 50,
                numInitTerrainTypes: 6,
                initBatchSize: 50,
                initPlayerGoldBalance: 20,
                initPlayerOilBalance: 20,
                maxBaseCountPerPlayer: 20,
                maxTroopCountPerPlayer: 20,
                maxPlayerCount: 50,
                defaultBaseGoldGenerationPerSecond: 5,
                defaultWellOilGenerationPerSecond: 5,
                debuffFactor: 80 //
            });
    }

    // Note: hardcoded
    function _generateTroopTypes() internal view returns (TroopType[] memory) {
        TroopType[] memory _troopTypes = new TroopType[](5);
        _troopTypes[0] = infantryTroopType;
        _troopTypes[1] = destroyerTroopType;
        _troopTypes[2] = cruiserTroopType;
        _troopTypes[3] = battleshipTroopType;
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

        // set individual columns
        for (uint256 y = 0; y < _height; y++) {
            _coastCol[y] = 0;
            _landCol[y] = 1;
            _waterCol[y] = 2;
            _portCol[y] = 3;
            _cityCol[y] = 4;
        }

        // set whole map
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

        // set oil wells
        _map[0][7] = 5;
        _map[5][0] = 5;
        _map[7][8] = 5;

        return _map;
    }

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

    function indexToId(uint256 _index) public pure returns (uint256) {
        return _index + 1;
    }

    // helpers
    function getRightPos(Position memory _pos) public pure returns (Position memory) {
        return Position({x: _pos.x + 1, y: _pos.y});
    }
}
