//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "test/DiamondDeploy.t.sol";

contract BasicTest is Test, DiamondDeployTest {
    function testWorldSize() public {
        WorldConstants memory _worldConstants = getter.getWorldConstants();
        assertEq(_worldConstants.worldWidth, 1000);
        assertEq(_worldConstants.worldHeight, 1000);
    }

    function testOnlyAdmin() public {
        Position memory _pos = Position({x: 3, y: 3});
        uint256 _armyTroopTypeId = indexToId(uint256(TROOP_NAME.ARMY));

        vm.expectRevert(bytes("CURIO: Unauthorized"));
        vm.prank(player2);
        helper.spawnTroop(_pos, player2, _armyTroopTypeId);
    }

    function testInitializePlayer() public {
        Base memory _player1Port = getter.getBaseAt(player1Pos);
        assertTrue(_player1Port.name == BASE_NAME.PORT);
        assertEq(_player1Port.owner, player1);

        Player memory _player1 = getter.getPlayer(player1);
        assertTrue(_player1.active);
        assertEq(_player1.balance, 20);
        assertEq(_player1.totalGoldGenerationPerUpdate, 5);
        assertEq(_player1.totalTroopExpensePerUpdate, 0);
        assertEq(_player1.numOwnedBases, 1);
        assertEq(_player1.numOwnedTroops, 0);

        Base memory _player2Port = getter.getBaseAt(player2Pos);
        assertTrue(_player2Port.name == BASE_NAME.PORT);
        assertEq(_player2Port.owner, player2);

        Player memory _player2 = getter.getPlayer(player2);
        assertTrue(_player2.active);
    }

    function testTransferDiamondOwnership() public {
        vm.prank(deployer);
        ownership.transferOwnership(player1);

        address _owner = ownership.owner();
        assertEq(_owner, player1);
    }

    function testTransferBaseOwnership() public {
        Position memory _pos = Position({x: 6, y: 6});
        assertEq(getter.getBaseAt(_pos).owner, NULL_ADDR);
        assertEq(getter.getPlayer(player1).numOwnedBases, 1);

        vm.prank(deployer);
        helper.transferBaseOwnership(_pos, player1);

        assertEq(getter.getBaseAt(_pos).owner, player1);
        assertEq(getter.getPlayer(player1).numOwnedBases, 2);
    }

    function testUpdatePlayerBalance() public {
        assertEq(getter.getPlayer(player1).balance, 20);
        assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 5);
        assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 0);
        assertEq(getter.getPlayer(player1).numOwnedTroops, 0);

        vm.warp(2);
        helper.updatePlayerBalance(player1);
        assertEq(getter.getPlayer(player1).balance, 25);

        vm.startPrank(deployer);
        helper.spawnTroop(Position({x: 0, y: 0}), player1, destroyerTroopTypeId);
        helper.spawnTroop(Position({x: 0, y: 1}), player1, battleshipTroopTypeId);
        assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 3);
        helper.spawnTroop(Position({x: 0, y: 2}), player1, destroyerTroopTypeId);
        helper.spawnTroop(Position({x: 0, y: 3}), player1, battleshipTroopTypeId);
        assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 5);
        assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 6);
        assertEq(getter.getPlayer(player1).numOwnedTroops, 4);
        vm.stopPrank();

        vm.warp(3);
        helper.updatePlayerBalance(player1);
        assertEq(getter.getPlayer(player1).balance, 24);

        vm.startPrank(deployer);
        helper.transferBaseOwnership(Position({x: 2, y: 0}), player1);
        helper.spawnTroop(Position({x: 3, y: 0}), player1, armyTroopTypeId);
        helper.spawnTroop(Position({x: 0, y: 4}), player1, battleshipTroopTypeId);
        assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 10);
        assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 8);
        vm.stopPrank();

        vm.warp(4);
        helper.updatePlayerBalance(player1);
        assertEq(getter.getPlayer(player1).balance, 26);
    }

    function testInitializeMapBatches() public {
        Position memory _pos1 = Position({x: 176, y: 485});
        Position memory _pos2 = Position({x: 371, y: 838});
        Position memory _pos3 = Position({x: 995, y: 645});
        Position[] memory _temp = new Position[](1);
        _temp[0] = _pos3;

        // activate far-flung map regions set not using the first batch
        vm.startPrank(deployer);
        helper.transferBaseOwnership(_pos1, player1);
        helper.spawnTroop(_pos2, player2, troopTransportTroopTypeId);
        helper.bulkInitializeTiles(_temp);
        vm.stopPrank();

        // verify that all three tiles are initialized correctly
        Tile memory _tile1 = getter.getTileAt(_pos1);
        assertTrue(_tile1.isInitialized);
        assertTrue(_tile1.terrain == TERRAIN.COAST);
        assertTrue(_tile1.baseId != NULL);
        assertEq(getter.getBaseAt(_pos1).owner, player1);
        assertEq(_tile1.occupantId, NULL);

        Tile memory _tile2 = getter.getTileAt(_pos2);
        assertTrue(_tile2.isInitialized);
        assertTrue(_tile2.terrain == TERRAIN.WATER);
        assertTrue(_tile2.occupantId != NULL);
        assertEq(getter.getTroopAt(_pos2).owner, player2);
        assertEq(_tile2.baseId, NULL);

        Tile memory _tile3 = getter.getTileAt(_pos3);
        assertTrue(_tile3.isInitialized);
        assertTrue(_tile3.terrain == TERRAIN.INLAND);
        assertTrue(_tile3.baseId != NULL);
        assertEq(getter.getBaseAt(_pos3).owner, NULL_ADDR);
        assertEq(_tile3.occupantId, NULL);

        // verify that another arbitrary tile is not initialized
        Tile memory _mysteriousTile = getter.getTileAt(Position({x: 129, y: 289}));
        assertTrue(!_mysteriousTile.isInitialized);
    }

    function testPauseGame() public {
        vm.expectRevert(bytes("CURIO: Game is ongoing"));
        vm.prank(deployer);
        helper.resumeGame();

        vm.expectRevert(bytes("CURIO: Unauthorized"));
        vm.prank(player3);
        helper.pauseGame();

        // initialize with 3 troops for player1
        vm.startPrank(deployer);
        helper.spawnTroop(Position({x: 0, y: 4}), player1, destroyerTroopTypeId);
        helper.spawnTroop(Position({x: 7, y: 5}), player1, troopTransportTroopTypeId);
        helper.spawnTroop(Position({x: 3, y: 6}), player1, armyTroopTypeId); // no expense
        vm.stopPrank();

        // verify initial states
        Player memory _player1Data = getter.getPlayer(player1);
        assertEq(block.timestamp, 1);
        assertEq(_player1Data.numOwnedBases, 1);
        assertEq(_player1Data.numOwnedTroops, 3);
        assertEq(_player1Data.totalGoldGenerationPerUpdate, 5);
        assertEq(_player1Data.totalTroopExpensePerUpdate, 2);
        assertEq(_player1Data.balance, 20);

        // verify balance after 4 seconds
        vm.warp(5);
        assertEq(getter.getPlayer(player1).balance, 20);
        helper.updatePlayerBalance(player1);
        assertEq(block.timestamp, 5);
        assertEq(getter.getPlayer(player1).balance, 32); // 20 + (5-2) * 4

        // pause game after another 2 seconds
        vm.warp(7);
        assertEq(getter.getPlayer(player1).balance, 32);
        vm.prank(deployer);
        helper.pauseGame();

        // verify player balance update
        assertEq(getter.getPlayer(player1).balance, 38); // 32 + (5-2) * 2;

        // verify that player functions can no longer be called
        vm.startPrank(player1);
        vm.expectRevert(bytes("CURIO: Game is paused"));
        engine.march(1, Position({x: 0, y: 5}));
        vm.expectRevert(bytes("CURIO: Game is paused"));
        engine.purchaseTroop(Position({x: 0, y: 5}), destroyerTroopTypeId);
        vm.stopPrank();

        // verify that admin functions are unaffected
        vm.prank(deployer);
        helper.spawnTroop(Position({x: 0, y: 5}), player2, destroyerTroopTypeId);
        assertEq(getter.getTroopAt(Position({x: 0, y: 5})).owner, player2);
        assertEq(getter.getTroopAt(Position({x: 0, y: 5})).troopTypeId, destroyerTroopTypeId);

        // resume game after another 3 seconds
        vm.warp(10);
        assertEq(getter.getPlayer(player1).balance, 38);
        vm.prank(deployer);
        helper.resumeGame();

        // verify that player balance remains unchanged over paused interval
        assertEq(getter.getPlayer(player1).balance, 38);
        vm.warp(11);
        helper.updatePlayerBalance(player1);
        _player1Data = getter.getPlayer(player1);
        assertEq(_player1Data.balance, 41); // 38 + (5-2)
        assertEq(_player1Data.numOwnedTroops, 3);
    }
}
