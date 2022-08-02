//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "test/DiamondDeploy.t.sol";

contract StackingTest is Test, DiamondDeployTest {
    function testArmyBasics() public {
        assertEq(getter.getPlayer(player1).numOwnedBases, 1);
        assertEq(getter.getPlayer(player1).numOwnedTroops, 0);

        // spawn troop => army automatically generated
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId);
        Army memory _army1 = getter.getArmyAt(player1Pos);
        assertEq(_army1.owner, player1); // check ownership
        assertEq(_army1.pos.x, player1Pos.x); // check position
        assertEq(_army1.pos.y, player1Pos.y);
    }

    function testSpawnTroop() public {
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId); // spawn an infrantry
        vm.stopPrank();

        Army memory _army1 = getter.getArmyAt(player1Pos);

        assertEq(_army1.troopIds.length, 1);
    }

    function testMoveArmyWithSingleTroop() public {
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId); // spawn an infrantry
        vm.stopPrank();

        vm.startPrank(player1);
        Position memory _targetPos = Position({x: 7, y: 1});

        vm.warp(2);
        engine.march(1, _targetPos); // move army to (7, 1);

        Army memory _army1 = getter.getArmyAt(_targetPos);
        assertEq(_army1.pos.x, _targetPos.x); // check position
        assertEq(_army1.pos.y, _targetPos.y);
        assertEq(_army1.troopIds.length, 1); // check the troop is inside
    }

    function testBattleBaseWithSingleTroop() public {
        Position memory _targetPos = Position({x: 6, y: 2});

        Position[] memory _tiles = new Position[](1);
        _tiles[0] = _targetPos;

        vm.prank(deployer);
        helper.bulkInitializeTiles(_tiles);

        Tile memory _tile = getter.getTileAt(_targetPos);
        Base memory _base = getter.getBase(_tile.baseId);
        assertEq(_tile.occupantId, NULL);
        assertEq(_base.owner, NULL_ADDR);
        assertEq(_base.health, 150);
        assertEq(getter.getPlayer(player1).totalOilConsumptionPerUpdate, 0);

        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId); // spawn an infantry
        vm.stopPrank();

        assertEq(getter.getPlayer(player1).totalOilConsumptionPerUpdate, 1);

        vm.startPrank(player1);

        vm.warp(2);
        engine.march(1, _targetPos); // move army to (6, 2);

        if (getter.getTroop(1).health == 100) {
            // infantry won
            assertEq(getter.getPlayer(player1).totalOilConsumptionPerUpdate, 1);
            Army memory _army1 = getter.getArmyAt(_targetPos);
            assertEq(_army1.pos.x, _targetPos.x); // check position
            assertEq(_army1.pos.y, _targetPos.y);
            assertEq(_army1.troopIds.length, 1); // check the troop is inside
            _tile = getter.getTileAt(_targetPos);
            _base = getter.getBase(_tile.baseId);
            assertEq(_tile.occupantId, 1);
            assertEq(_base.owner, player1);
            assertEq(_base.health, 150);
        } else {
            // port won
            assertEq(getter.getPlayer(player1).totalOilConsumptionPerUpdate, 0);
            Army memory _army1 = getter.getArmy(1);
            assertEq(_army1.owner, NULL_ADDR);
            assertEq(_army1.troopIds.length, 0);
            assertEq(getter.getTroop(1).health, 0);
            _tile = getter.getTileAt(_targetPos);
            _base = getter.getBase(_tile.baseId);
            assertEq(_tile.occupantId, NULL);
            assertEq(_base.owner, NULL_ADDR);
            assertEq(_base.health, 50);
        }
    }

    function testMoveTroop() public {
        assertEq(getter.getPlayer(player1).totalOilGenerationPerUpdate, 0);
        assertEq(getter.getPlayer(player1).totalOilConsumptionPerUpdate, 0);

        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId); // spawn an infrantry. troop # 1
        Position memory army2position = Position({x: 6, y: 2});
        helper.spawnTroop(army2position, player1, infantryTroopTypeId); // spawn an infrantry. troop #2
        vm.stopPrank();

        assertEq(getter.getPlayer(player1).totalOilGenerationPerUpdate, 0);
        assertEq(getter.getPlayer(player1).totalOilConsumptionPerUpdate, 2);

        vm.startPrank(player1);
        vm.warp(2);
        engine.moveTroop(1, army2position);
        vm.stopPrank();

        // verify initial tile's details
        Tile memory tile = getter.getTileAt(player1Pos);
        assertEq(tile.occupantId, 0);

        // // check that the original army #1 is deleted
        // Army memory army1 = getter.getArmy(1);
        // // TODO: figure out what happens to a deleted key value pair in mapping

        // // verify target army's details
        Army memory targetArmy = getter.getArmyAt(army2position);
        assertEq(targetArmy.troopIds.length, 2); // check that the new army has 2 troops inside
        assertEq(targetArmy.troopIds[0], 2); // new army contains troop #1 and #2
        assertEq(targetArmy.troopIds[1], 1);

        // // ------------------------------------------------
        // // move troop1 back to original tile

        vm.startPrank(player1);
        vm.warp(4);
        engine.moveTroop(1, player1Pos);
        vm.stopPrank();

        Army memory separatedArmy = getter.getArmyAt(player1Pos);
        assertEq(separatedArmy.troopIds.length, 1);
        assertEq(separatedArmy.troopIds[0], 1); // troop #1 moved out

        Army memory army2 = getter.getArmyAt(army2position);
        assertEq(army2.troopIds.length, 1);
        assertEq(army2.troopIds[0], 2); // troop #2 in old tile
    }

    function testMarch() public {
        // spawn two troops and combine them
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId); // spawn an infrantry. troop # 1
        Position memory army2position = Position({x: 6, y: 2});
        helper.spawnTroop(army2position, player1, infantryTroopTypeId); // spawn an infrantry. troop #2
        vm.stopPrank();

        vm.startPrank(player1);
        vm.warp(2);
        engine.moveTroop(1, army2position);
        vm.stopPrank();

        // march
        vm.startPrank(player1);
        vm.warp(4);
        engine.march(2, player1Pos);
        vm.stopPrank();

        Tile memory _tile1 = getter.getTileAt(player1Pos); // where march moved to
        assertEq(_tile1.occupantId, 2);

        Tile memory _tile2 = getter.getTileAt(army2position); // where the troops left from
        assertEq(_tile2.occupantId, 0);
    }

    function testInfantryMove() public {
        // spawn 1 infantry 1 destroyer and combine them
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId); // spawn an infrantry. troop # 1
        Position memory destroyerPosition = Position({x: 7, y: 1});
        helper.spawnTroop(destroyerPosition, player1, destroyerTroopTypeId); // spawn an destroyer. troop #2
        vm.stopPrank();

        vm.startPrank(player1);
        vm.warp(2);
        engine.moveTroop(1, destroyerPosition); // move infantry to destroyer

        Tile memory _tile = getter.getTileAt(destroyerPosition); // where march moved to
        assertEq(_tile.occupantId, 2);

        Army memory army = getter.getArmyAt(destroyerPosition);
        assertEq(army.troopIds.length, 2); // new tile should have infantry + destroyer

        vm.warp(4);
        vm.expectRevert(bytes("CURIO: Troops and land type not compatible"));
        engine.march(2, getRightPos(destroyerPosition));
    }

    function testArmyBattle() public {
        // spawn 1 infantry 1 destroyer and combine them
        vm.startPrank(deployer);

        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId); // spawn an infrantry. troop # 1
        Position memory destroyerPosition = Position({x: 7, y: 1});
        helper.spawnTroop(destroyerPosition, player1, destroyerTroopTypeId); // spawn an destroyer. troop #2

        helper.spawnTroop(player2Pos, player2, infantryTroopTypeId);
        Position memory battleshipPosition = Position({x: 7, y: 3});
        helper.spawnTroop(battleshipPosition, player2, battleshipTroopTypeId);

        vm.stopPrank();

        // preparing for battle
        vm.startPrank(player1);
        vm.warp(2);
        engine.moveTroop(1, destroyerPosition); // move infantry to destroyer
        vm.warp(4);
        engine.march(2, Position({x: 7, y: 2}));
        vm.stopPrank();

        vm.startPrank(player2);
        engine.moveTroop(3, battleshipPosition); // move infantry to battleship
        Tile memory newPlayer2Tile = getter.getTileAt(battleshipPosition);
        uint256 player2ArmyId = newPlayer2Tile.occupantId;

        // battle
        vm.warp(6);
        engine.march(player2ArmyId, Position({x: 7, y: 2}));

        // check battle results - unlikely destroyer gonna win but could happen
        Army memory winningArmy = getter.getArmyAt(battleshipPosition);
        assertEq(winningArmy.owner, player2);
        Tile memory targetTile = getter.getTileAt(Position({x: 7, y: 2}));
        assertEq(targetTile.occupantId, 0);
        vm.stopPrank();
    }

    function testMoveTroopEdgeCases() public {
        // spawn 1 infantry 1 destroyer and combine them
        vm.startPrank(deployer);

        helper.spawnTroop(player1Pos, player1, infantryTroopTypeId); // spawn an infrantry. troop # 1
        Position memory _pos2 = Position({x: 7, y: 1});
        Position memory _pos3 = Position({x: 6, y: 0});
        Position memory _pos4 = Position({x: 6, y: 2});
        Position memory _pos5 = Position({x: 5, y: 1});

        // center position is (6, 1)
        helper.spawnTroop(_pos2, player1, infantryTroopTypeId); // spawn an destroyer. troop #2
        helper.spawnTroop(_pos3, player1, infantryTroopTypeId);
        helper.spawnTroop(_pos4, player1, infantryTroopTypeId);
        helper.spawnTroop(_pos5, player1, infantryTroopTypeId);
        vm.stopPrank();

        // move all player one's troop to (player1Pos which is (6, 1))
        vm.startPrank(player1);
        vm.warp(2);
        engine.moveTroop(2, player1Pos);
        engine.moveTroop(3, player1Pos);
        engine.moveTroop(4, player1Pos);
        engine.moveTroop(5, player1Pos);
        vm.stopPrank();

        Army memory _targetArmy = getter.getArmy(1);
        assertEq(_targetArmy.troopIds.length, 5);

        // spawn extra troop
        vm.startPrank(deployer);
        helper.spawnTroop(_pos2, player1, infantryTroopTypeId);
        vm.stopPrank();

        // move extra troop to army
        vm.startPrank(player1);
        vm.expectRevert("CURIO: Army can have up to five troops, or two with one transport");
        vm.warp(4);
        engine.moveTroop(6, player1Pos);
        vm.stopPrank();

        // player 2 move troop to player 1's army -- to the one generated as extra
        vm.startPrank(deployer);
        helper.spawnTroop(Position({x: 7, y: 2}), player2, infantryTroopTypeId);
        vm.stopPrank();

        // move extra troop to army
        vm.startPrank(player2);
        vm.expectRevert("CURIO: You can only combine with own troop");
        vm.warp(6);
        engine.moveTroop(6, _pos2);
        vm.stopPrank();
    }

    function testDistributeDamage() public {
        // spawn 1 infantry 1 destroyer and combine them
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, battleshipTroopTypeId); // spawn an infrantry. troop # 1
        Position memory battleshipPosition = Position({x: 7, y: 1});
        helper.spawnTroop(battleshipPosition, player1, battleshipTroopTypeId); // spawn an destroyer. troop #2
        helper.spawnTroop(Position({x: 7, y: 2}), player2, battleshipTroopTypeId);
        vm.stopPrank();

        vm.startPrank(player1);
        vm.warp(2);
        engine.moveTroop(1, battleshipPosition); // move infantry to destroyer

        Tile memory _tile = getter.getTileAt(battleshipPosition); // where march moved to
        assertEq(_tile.occupantId, 2);

        Army memory _army = getter.getArmyAt(battleshipPosition);
        assertEq(_army.troopIds.length, 2); // new tile should have infantry + destroyer

        // test battling => player1 most likely to win; at least its first troop health decreases
        vm.warp(4);
        engine.march(2, Position({x: 7, y: 2}));
        Army memory _winnerArmy = getter.getArmyAt(battleshipPosition);
        Troop memory _firstTroop = getter.getTroop(_winnerArmy.troopIds[0]);
        uint256 firstTroopMaxHealth = getter.getTroopType(_firstTroop.troopTypeId).maxHealth;
        assertEq(_firstTroop.health != firstTroopMaxHealth, true);
    }
}
