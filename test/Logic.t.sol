//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "test/DiamondDeploy.t.sol";

contract LogicTest is Test, DiamondDeployTest {
    // ----------------------------------------------------------
    // MARCH TESTS
    // ----------------------------------------------------------

    function testMoveFailure() public {
        // spawn troop at player1 location
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, troopTransportTroopTypeId);
        helper.spawnTroop(Position({x: 7, y: 4}), player1, troopTransportTroopTypeId);
        vm.stopPrank();
        uint256 _troopId = initTroopNonce;

        vm.warp(2);
        vm.startPrank(player1);

        // fail: move to same location
        vm.expectRevert(bytes("CURIO: Already at destination"));
        engine.march(_troopId, player1Pos);

        vm.warp(4);
        engine.march(_troopId, Position({x: 7, y: 2}));
        vm.warp(6);
        engine.march(_troopId, Position({x: 7, y: 3}));

        vm.stopPrank();
    }

    function testMarchFailure() public {
        Position memory _troopPos = Position({x: 7, y: 6});
        Position memory _enemy1Pos = Position({x: 7, y: 7});
        Position memory _enemy2Pos = Position({x: 7, y: 5});

        vm.startPrank(deployer);
        helper.spawnTroop(_troopPos, player1, destroyerTroopTypeId);
        helper.spawnTroop(_enemy1Pos, player2, troopTransportTroopTypeId); // a weaker enemy
        vm.stopPrank();

        uint256 _player1DestroyerId = initTroopNonce;

        vm.warp(2);

        vm.startPrank(player1);

        // fail: 2 attacks in 1 second
        engine.march(_player1DestroyerId, _enemy1Pos);
        if (getter.getTroop(_player1DestroyerId).owner == player1) {
            vm.expectRevert(bytes("CURIO: Large action taken too recently"));
            engine.march(_player1DestroyerId, _enemy2Pos);
        }

        vm.stopPrank();
    }

    function testBattleTroop() public {
        Position memory _armyPos = Position({x: 8, y: 3});
        Position memory _destroyerPos = Position({x: 7, y: 3});

        vm.startPrank(deployer);
        helper.spawnTroop(_armyPos, player2, armyTroopTypeId);
        uint256 _armyId = initTroopNonce;
        helper.spawnTroop(_destroyerPos, player1, destroyerTroopTypeId);
        vm.stopPrank();

        Troop memory _army;
        Troop memory _destroyer = getter.getTroopAt(_destroyerPos);
        assertEq(_destroyer.owner, player1);
        assertEq(_destroyer.health, getter.getTroopType(destroyerTroopTypeId).maxHealth);
        assertEq(getter.getPlayer(player1).numOwnedTroops, 1);
        assertEq(getter.getPlayer(player2).numOwnedTroops, 1);

        // increase time
        vm.warp(3);

        vm.prank(player2);
        // Note: Battle functionality
        engine.march(_armyId, _destroyerPos);

        _destroyer = getter.getTroopAt(_destroyerPos);
        _army = getter.getTroop(_armyId);
        bool _destroyerKilled = _destroyer.owner == NULL_ADDR; // destroyer dies
        bool _armyKilled = _army.owner == NULL_ADDR; // army dies
        assertTrue(_destroyerKilled || _armyKilled);
        helper.updatePlayerBalance(player1);
        assertEq(getter.getPlayer(player1).balance, 28);

        // either side dies but not both
        if (_destroyerKilled) {
            assertTrue(!_armyKilled);
            assertEq(_army.health, 1);
            assertEq(_army.owner, player2);
            assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 5);
            assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 0);
            assertEq(getter.getPlayer(player1).numOwnedTroops, 0);
            assertEq(getter.getPlayer(player2).totalGoldGenerationPerUpdate, 5);
            assertEq(getter.getPlayer(player2).totalTroopExpensePerUpdate, 0);
            assertEq(getter.getPlayer(player2).numOwnedTroops, 1);
        } else {
            assertEq(_destroyer.owner, player1);
            assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 5);
            assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 1);
            assertEq(getter.getPlayer(player1).numOwnedTroops, 1);
            assertEq(getter.getPlayer(player2).totalGoldGenerationPerUpdate, 5);
            assertEq(getter.getPlayer(player2).totalTroopExpensePerUpdate, 0);
            assertEq(getter.getPlayer(player2).numOwnedTroops, 0);
        }
    }

    function testBattleBaseNoCapture() public {
        Position memory _pos1 = Position({x: 7, y: 3});
        Position memory _pos2 = Position({x: 5, y: 3});

        vm.startPrank(deployer);
        helper.spawnTroop(_pos1, player1, destroyerTroopTypeId);
        helper.transferBaseOwnership(Position({x: 5, y: 3}), player1);
        helper.spawnTroop(_pos2, player1, armyTroopTypeId);
        vm.stopPrank();

        vm.warp(3);
        vm.prank(player1);
        engine.march(1, player2Pos);

        Base memory _targetBase = getter.getBaseAt(player2Pos);
        assertEq(_targetBase.health, 0);
        assertEq(_targetBase.owner, player2);
        assertEq(getter.getTileAt(player2Pos).occupantId, NULL);
        Troop memory _destroyer = getter.getTroop(1);
        assertEq(_destroyer.owner, player1);
        assertEq(_destroyer.troopTypeId, destroyerTroopTypeId);
        assertEq(_destroyer.lastLargeActionTaken, 3);
        assertEq(_destroyer.troopTypeId, destroyerTroopTypeId);

        vm.warp(4);
        vm.prank(player1);
        vm.expectRevert(bytes("CURIO: Can only capture base with land troop"));
        engine.march(1, player2Pos);

        vm.prank(player1);
        engine.march(2, player2Pos);

        _targetBase = getter.getBaseAt(player2Pos);
        assertEq(_targetBase.health, 1);
        assertEq(_targetBase.owner, player1);
        assertEq(getter.getTileAt(player2Pos).occupantId, 2);
        Troop memory _army = getter.getTroopAt(player2Pos);
        assertEq(_army.health, 1);
        assertEq(_army.owner, player1);
    }

    function testCaptureBaseFailure() public {
        vm.startPrank(deployer);
        helper.transferBaseOwnership(Position({x: 5, y: 1}), player1);
        helper.spawnTroop(Position({x: 5, y: 1}), player1, armyTroopTypeId);
        uint256 _armyId = initTroopNonce;
        helper.spawnTroop(Position({x: 7, y: 3}), player1, destroyerTroopTypeId);
        vm.stopPrank();

        vm.warp(2);
        vm.prank(player2);
        vm.expectRevert(bytes("CURIO: Can only march own troop"));
        engine.march(_armyId, player3Pos);

        vm.startPrank(player1);
        vm.expectRevert(bytes("CURIO: Target not in firing range"));
        engine.march(_armyId, player2Pos);
        vm.stopPrank();
    }

    // ----------------------------------------------------------
    // PURCHASE TESTS
    // ----------------------------------------------------------
    function testPurchaseTroopFailure() public {
        // fail: purchase by inactive address
        vm.expectRevert(bytes("CURIO: Player is inactive"));
        engine.purchaseTroop(Position({x: 100, y: 50}), armyTroopTypeId);

        // fail: purchase on invalid location
        vm.prank(player2);
        vm.expectRevert(bytes("CURIO: Out of bound"));
        engine.purchaseTroop(Position({x: 6000, y: 6000}), armyTroopTypeId);

        // fail: player2 attempting to produce in other's base
        vm.prank(player2);
        vm.expectRevert(bytes("CURIO: Can only purchase in own base"));
        engine.purchaseTroop(player1Pos, armyTroopTypeId);

        // fail: player3 in a city attempting to purchase a troop transport (water troop)
        vm.prank(player3);
        vm.expectRevert(bytes("CURIO: Only ports can purchase water troops"));
        engine.purchaseTroop(player3Pos, troopTransportTroopTypeId);

        // fail: player1 attempting to purchase a troop over budget
        vm.prank(player1);
        vm.expectRevert(bytes("CURIO: Insufficient balance (consider deleting some troops!)"));
        engine.purchaseTroop(player1Pos, battleshipTroopTypeId);

        // fail: player1 finish producing troop on an occupied base
        vm.prank(deployer);
        helper.spawnTroop(player1Pos, player1, armyTroopTypeId);
        vm.prank(player1);
        vm.expectRevert(bytes("CURIO: Base occupied by another troop"));
        engine.purchaseTroop(player1Pos, troopTransportTroopTypeId);
    }

    function testPurchaseTroop() public {
        assertEq(getter.getPlayer(player1).balance, 20);
        assertEq(getter.getPlayer(player1).numOwnedTroops, 0);

        // player1 purchase troop transport
        vm.startPrank(player1);
        assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 0);
        engine.purchaseTroop(player1Pos, troopTransportTroopTypeId);

        // success: verify troop's basic information
        Troop memory _troop = getter.getTroopAt(player1Pos);
        assertEq(_troop.owner, player1);
        assertEq(_troop.troopTypeId, troopTransportTroopTypeId);
        assertEq(_troop.pos.x, player1Pos.x);
        assertEq(_troop.pos.y, player1Pos.y);

        // success: verify that troop ID was registered correctly
        _troop = getter.getTroop(initTroopNonce);
        assertEq(_troop.pos.x, player1Pos.x);
        assertEq(_troop.pos.y, player1Pos.y);

        // success: verify the troopType is correct
        TroopType memory _troopType = getter.getTroopType(_troop.troopTypeId);
        assertTrue(!_troopType.isLandTroop);

        // success: verify balance and troop count
        assertEq(getter.getPlayer(player1).balance, 20 - 14);
        assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 5);
        assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 1);
        assertEq(getter.getPlayer(player1).numOwnedTroops, 1);

        // success: purchase another troop
        vm.warp(3);
        engine.march(initTroopNonce, Position({x: 7, y: 1}));
        engine.purchaseTroop(player1Pos, troopTransportTroopTypeId);

        // success: verify troop's basic information
        _troop = getter.getTroopAt(player1Pos);
        assertEq(_troop.owner, player1);
        assertEq(_troop.troopTypeId, troopTransportTroopTypeId);
        assertEq(_troop.pos.x, player1Pos.x);
        assertEq(_troop.pos.y, player1Pos.y);

        assertEq(getter.getPlayer(player1).balance, 6 + 2 * (5 - 1) - 14);

        vm.stopPrank();
    }

    // ----------------------------------------------------------
    // REPAIR TESTS
    // ----------------------------------------------------------

    function testRepairFailure() public {
        vm.startPrank(player1);
        vm.expectRevert("CURIO: No base found");
        helper.repair(Position({x: 0, y: 0}));

        vm.expectRevert("CURIO: Can only repair in own base");
        helper.repair(player2Pos);

        vm.expectRevert("CURIO: No troop to repair");
        helper.repair(player1Pos);
        vm.stopPrank();

        uint256 _player1DestroyerId = initTroopNonce;
        Position memory _player2DestroyerPos = Position({x: 7, y: 1});
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, destroyerTroopTypeId);
        helper.spawnTroop(_player2DestroyerPos, player2, destroyerTroopTypeId);
        vm.stopPrank();

        vm.startPrank(player1);
        vm.expectRevert("CURIO: Troop already at full health");
        helper.repair(player1Pos);

        // Note: test battle functionality
        vm.warp(2);
        engine.march(_player1DestroyerId, _player2DestroyerPos);

        // try to replicate "repaired too recently" error on both players' destroyers
        Troop memory _player1Destroyer = getter.getTroopAt(player1Pos);
        if (_player1Destroyer.owner == player1 && _player1Destroyer.health == 1) {
            helper.repair(player1Pos);
            vm.expectRevert("CURIO: Repaired too recently");
            helper.repair(player1Pos);
        }

        vm.stopPrank();

        vm.startPrank(player2);

        Troop memory _player2Destroyer = getter.getTroopAt(_player2DestroyerPos);
        if (_player2Destroyer.owner == player2 && _player2Destroyer.health == 1) {
            helper.repair(_player2DestroyerPos);
            vm.expectRevert("CURIO: Repaired too recently");
            helper.repair(_player2DestroyerPos);
        }

        vm.stopPrank();
    }

    function testRepair() public {
        uint256 _player1DestroyerId = initTroopNonce;
        Position memory _player2DestroyerPos = Position({x: 7, y: 1});
        vm.startPrank(deployer);
        helper.spawnTroop(player1Pos, player1, destroyerTroopTypeId);
        helper.spawnTroop(_player2DestroyerPos, player2, destroyerTroopTypeId);
        vm.stopPrank();

        vm.startPrank(player1);
        vm.warp(2);
        // Note: test battle functionality
        engine.march(_player1DestroyerId, _player2DestroyerPos);

        Troop memory _player1Destroyer = getter.getTroopAt(player1Pos);
        if (_player1Destroyer.owner == player1 && _player1Destroyer.health < 3) {
            uint256 _health = _player1Destroyer.health;
            vm.warp(20);
            helper.repair(player1Pos);
            assertEq(getter.getTroopAt(player1Pos).health, _health + 1);
        }

        vm.stopPrank();
        vm.startPrank(player2);

        Troop memory _player2Destroyer = getter.getTroopAt(_player2DestroyerPos);
        if (_player2Destroyer.owner == player2 && _player2Destroyer.health < 3) {
            uint256 _health = _player2Destroyer.health;
            vm.warp(20);
            helper.repair(_player2DestroyerPos);
            assertEq(getter.getTroopAt(_player2DestroyerPos).health, _health + 1);
        }

        vm.stopPrank();
    }

    // ----------------------------------------------------------
    // DELETE TROOP TESTS
    // ----------------------------------------------------------

    function testDeleteTroop() public {
        assertEq(block.timestamp, 1);

        vm.startPrank(deployer);
        helper.spawnTroop(Position({x: 7, y: 2}), player1, destroyerTroopTypeId);
        helper.spawnTroop(Position({x: 7, y: 3}), player1, troopTransportTroopTypeId);
        vm.stopPrank();

        Player memory _player1Info = getter.getPlayer(player1);
        assertEq(_player1Info.numOwnedTroops, 2);
        assertEq(_player1Info.totalTroopExpensePerUpdate, 2);
        assertEq(_player1Info.balance, 20);

        vm.warp(2);
        helper.updatePlayerBalance(player1);
        _player1Info = getter.getPlayer(player1);
        assertEq(_player1Info.balance, 23);

        vm.prank(player2);
        vm.expectRevert(bytes("CURIO: Can only delete own troop"));
        engine.deleteTroop(1);

        vm.prank(player1);
        engine.deleteTroop(1);
        _player1Info = getter.getPlayer(player1);
        Troop memory _firstDestroyer = getter.getTroop(1);
        assertEq(_firstDestroyer.owner, NULL_ADDR);
        assertEq(_firstDestroyer.health, 0);
        assertEq(_firstDestroyer.pos.y, 0);
        assertEq(_player1Info.numOwnedTroops, 1);
        assertEq(_player1Info.totalTroopExpensePerUpdate, 1);

        vm.warp(3);
        helper.updatePlayerBalance(player1);
        _player1Info = getter.getPlayer(player1);
        assertEq(_player1Info.balance, 27);
    }

    // ----------------------------------------------------------------
    // Note: enable tests below for when ship capturing base is enabled
    // ----------------------------------------------------------------

    // function testBattleBaseNaval() public {
    //     Position memory _destroyerPos = Position({x: 7, y: 3});

    //     vm.prank(deployer);
    //     helper.spawnTroop(_destroyerPos, player1, destroyerTroopTypeId);
    //     helper.updatePlayerBalance(player1);
    //     assertEq(getter.getPlayer(player1).balance, 20);
    //     assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 5);
    //     assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 1);
    //     assertEq(getter.getPlayer(player1).numOwnedBases, 1);
    //     assertEq(getter.getPlayer(player2).totalGoldGenerationPerUpdate, 5);
    //     assertEq(getter.getPlayer(player2).totalTroopExpensePerUpdate, 0);
    //     assertEq(getter.getPlayer(player2).numOwnedBases, 1);
    //     uint256 _destroyerId = initTroopNonce;

    //     // increase time
    //     vm.warp(3);

    //     vm.prank(player1);
    //     // Note: battle functionality
    //     engine.march(_destroyerId, player2Pos);

    //     if (getter.getTroop(_destroyerId).owner != player1) {
    //         console.log("[testbattleBase] Warning: unlikely outcome");
    //         return; // destroyer dies while battling port, a 1/64 (unlikely) outcome
    //     }

    //     Troop memory _destroyer = getter.getTroopAt(player2Pos);
    //     assertEq(_destroyer.owner, player1);

    //     Tile memory _tile = getter.getTileAt(player2Pos);
    //     assertEq(_tile.occupantId, _destroyerId);
    //     assertTrue(_tile.baseId != NULL);

    //     Base memory _port = getter.getBaseAt(player2Pos);
    //     assertEq(_port.owner, player1);
    //     assertEq(_port.health, 1);

    //     helper.updatePlayerBalance(player1);
    //     assertEq(getter.getPlayer(player1).balance, 28);
    //     assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 10);
    //     assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 1);
    //     assertEq(getter.getPlayer(player1).numOwnedBases, 2);
    //     assertEq(getter.getPlayer(player2).totalGoldGenerationPerUpdate, 0);
    //     assertEq(getter.getPlayer(player2).totalTroopExpensePerUpdate, 0);
    //     assertEq(getter.getPlayer(player2).numOwnedBases, 0);
    // }

    // function testCaptureBaseNaval() public {
    //     vm.startPrank(deployer);
    //     helper.transferBaseOwnership(Position({x: 6, y: 2}), player1);
    //     helper.spawnTroop(Position({x: 6, y: 2}), player1, armyTroopTypeId);
    //     uint256 _armyId = initTroopNonce;
    //     helper.spawnTroop(Position({x: 7, y: 3}), player1, destroyerTroopTypeId);
    //     uint256 _destroyerId = initTroopNonce + 1;
    //     helper.transferBaseOwnership(Position({x: 6, y: 4}), player2);
    //     helper.spawnTroop(Position({x: 6, y: 4}), player2, armyTroopTypeId);
    //     vm.stopPrank();

    //     Base memory _base = getter.getBaseAt(player2Pos);
    //     assertEq(_base.owner, player2);
    //     assertEq(getter.getPlayer(player1).numOwnedBases, 1);
    //     assertEq(getter.getPlayer(player2).numOwnedBases, 1);

    //     // increase time
    //     vm.warp(3);

    //     vm.startPrank(player1);
    //     // Note: Battle functionality
    //     engine.march(_destroyerId, player2Pos);
    //     if (getter.getTroop(_destroyerId).owner == NULL_ADDR) {
    //         console.log("[testCaptureBase] Warning: unlikely outcome");
    //         return; // destroyer dies while battling port, a 1/64 (unlikely) outcome
    //     }
    //     assertEq(getter.getBaseAt(player2Pos).owner, player1);
    //     assertEq(getter.getBaseAt(player2Pos).health, 1);
    //     assertEq(getter.getTileAt(player2Pos).occupantId, _destroyerId);
    //     assertEq(getter.getPlayer(player2).numOwnedBases, 1);
    //     assertEq(getter.getPlayer(player1).numOwnedBases, 2);
    //     vm.expectRevert(bytes("CURIO: Destination tile occupied"));
    //     // Note: captureBase functionality
    //     engine.march(_armyId, player2Pos);
    //     vm.stopPrank();

    //     Troop memory _army = getter.getTroop(_armyId);
    //     assertEq(_army.pos.x, 6);
    //     assertEq(_army.pos.y, 3);
    //     assertEq(_army.health, getter.getTroopType(armyTroopTypeId).maxHealth);

    //     _base = getter.getBaseAt(player2Pos);
    //     assertEq(_base.owner, player1);

    //     assertEq(getter.getPlayer(player1).balance, 28);
    //     assertEq(getter.getPlayer(player1).totalGoldGenerationPerUpdate, 10);
    //     assertEq(getter.getPlayer(player1).totalTroopExpensePerUpdate, 1);
    //     assertEq(getter.getPlayer(player2).totalGoldGenerationPerUpdate, 0);
    //     assertEq(getter.getPlayer(player2).totalTroopExpensePerUpdate, 0);

    //     vm.coinbase(deployer);
    // }
}
