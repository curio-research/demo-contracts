//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "test/DiamondDeploy.t.sol";

contract GetterTest is Test, DiamondDeployTest {
    function testBulkGetAllTroops() public {
        vm.startPrank(deployer);
        helper.spawnTroop(Position({x: 1, y: 3}), player1, armyTroopTypeId);
        helper.spawnTroop(Position({x: 1, y: 4}), player1, armyTroopTypeId);
        helper.transferBaseOwnership(Position({x: 2, y: 3}), player2);
        helper.spawnTroop(Position({x: 2, y: 3}), player2, armyTroopTypeId);
        helper.transferBaseOwnership(Position({x: 2, y: 4}), player2);
        helper.spawnTroop(Position({x: 2, y: 4}), player2, armyTroopTypeId);
        helper.spawnTroop(Position({x: 7, y: 5}), player3, destroyerTroopTypeId);
        vm.stopPrank();

        Troop[] memory _allTroops = getter.bulkGetAllTroops();
        assertEq(_allTroops.length, 5);
        assertEq(_allTroops[0].owner, player1);
        assertEq(_allTroops[1].pos.x, 1);
        assertEq(_allTroops[1].pos.y, 4);
        assertEq(_allTroops[2].troopTypeId, armyTroopTypeId);
        assertEq(_allTroops[2].owner, player2);
        assertEq(_allTroops[4].troopTypeId, destroyerTroopTypeId);
        assertEq(getter.getTileAt(Position({x: 1, y: 3})).occupantId, 1);
        assertEq(getter.getTileAt(Position({x: 2, y: 3})).occupantId, 3);

        vm.warp(2);
        vm.prank(player1);
        engine.march(1, Position({x: 2, y: 3}));

        assertTrue(getter.getTroop(1).health > 0 || getter.getTroop(3).health > 0); // one army must survive

        if (getter.getTroop(3).health == 0) {
            // verify that all troops remain the same except player2's dead army
            _allTroops = getter.bulkGetAllTroops();
            assertEq(_allTroops.length, 5);
            assertEq(_allTroops[0].owner, player1);
            assertEq(_allTroops[1].pos.x, 1);
            assertEq(_allTroops[1].pos.y, 4);
            assertEq(_allTroops[2].troopTypeId, NULL);
            assertEq(_allTroops[2].owner, address(0));
            assertEq(_allTroops[4].troopTypeId, destroyerTroopTypeId);
        } else {
            // verify that all troops remain the same except player1's dead army
            _allTroops = getter.bulkGetAllTroops();
            assertEq(_allTroops.length, 5);
            assertEq(_allTroops[0].owner, address(0));
            assertEq(_allTroops[0].health, 0);
            assertEq(_allTroops[0].troopTypeId, NULL);
            assertEq(_allTroops[1].pos.x, 1);
            assertEq(_allTroops[1].pos.y, 4);
            assertEq(_allTroops[2].owner, player2);
            assertEq(_allTroops[4].troopTypeId, destroyerTroopTypeId);
        }
    }
}
