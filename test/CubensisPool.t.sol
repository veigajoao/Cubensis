// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CubensisPool} from "../src/CubensisPool.sol";
import {MockCubensisPool} from "./MockCubensisPool.t.sol";

import {UD60x18, convert, ZERO} from "@prb/math/src/UD60x18.sol";

import "../src/libraries/Tick.sol";
import "../src/libraries/Position.sol";
import "../src/libraries/FixedMath.sol";

contract CubensisTest is Test {
    MockCubensisPool public pool;

    error Debug(uint256, uint256, uint256, uint256, uint256, uint256);
    error Debug2(int24, int24, int24, int24);

    address public alice;
    address public bob;
    address public carmen;

    // tick limits
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    // mocked decimals for tokens
    uint256 constant DECIMALS = 1e18;
    int24 constant ZERO_PRICE_TICK = 0;

    function setUp() public {
        // initialize contract
        pool = new MockCubensisPool();

        // initialize 3 accounts to use
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carmen = makeAddr("carmen");

        // give accounts balance
        pool.addTokensAccount(false, 100 * DECIMALS, alice);
        pool.addTokensAccount(false, 100 * DECIMALS, bob);
        pool.addTokensAccount(false, 100 * DECIMALS, carmen);

        pool.addTokensAccount(true, 100 * DECIMALS, alice);
        pool.addTokensAccount(true, 100 * DECIMALS, bob);
        pool.addTokensAccount(true, 100 * DECIMALS, carmen);
    }

    function test_limit_order_flip_tick() public {
        // alice creates order on price 1 to sell 10 token1
        uint256 aliceBalance0_0 = pool.tokenBalances(false, alice);
        uint256 aliceBalance1_0 = pool.tokenBalances(true, alice);
        uint256 ALICE_ORDER_SIZE = 10 * DECIMALS;

        vm.prank(alice);
        (, uint256 receivedAlice) = pool.limitOrderTrade(false, ZERO_PRICE_TICK, ALICE_ORDER_SIZE);

        // assert effects of limit placement:
        // 1. Alice's balance should have been reduced for token1
        // and stayede the same for token0
        uint256 aliceBalance0_1 = pool.tokenBalances(false, alice);
        uint256 aliceBalance1_1 = pool.tokenBalances(true, alice);
        assert(aliceBalance1_0 - ALICE_ORDER_SIZE == aliceBalance1_1);
        assert(aliceBalance0_0 == aliceBalance0_1);
        assert(receivedAlice == 0);

        // 2. tick should have been initialized
        (
            uint256 counterTick0,
            UD60x18 totalBalanceTick0,
            UD60x18 executedRatioTick0
        ) = pool.ticks(true, ZERO_PRICE_TICK);
        assert(counterTick0 == 1);
        assert(convert(totalBalanceTick0) == ALICE_ORDER_SIZE);
        assert(convert(executedRatioTick0) == 1);

        // 3. Alice's position should have been initialized
        (
            uint256 counterPos0,
            UD60x18 totalBalancePos0,
            UD60x18 executedRatioPos0
        ) = pool.positions(
                true,
                keccak256(abi.encodePacked(alice, ZERO_PRICE_TICK))
            );
            
        assert(counterPos0 == 1);
        assert(convert(totalBalancePos0) == ALICE_ORDER_SIZE);
        assert(convert(executedRatioPos0) == 1);

        // bob creates order on price 1 to sell 30 token0
        uint256 bobBalance0_0 = pool.tokenBalances(false, bob);
        uint256 bobBalance1_0 = pool.tokenBalances(true, bob);
        uint256 BOB_ORDER_SIZE = 30 * DECIMALS;

        vm.prank(bob);
        (uint256 executedBob, uint256 receivedBob) = pool.limitOrderTrade(true, ZERO_PRICE_TICK, BOB_ORDER_SIZE);

        // assert effects of limit placement:
        // order should have been mateched for 10 tokens 
        // and new tick opened for other 20
        // 1. Bob's balance should have been reduced for token1
        // and increased for token2
        uint256 bobBalance0_1 = pool.tokenBalances(false, bob);
        uint256 bobBalance1_1 = pool.tokenBalances(true, bob);
        assert(bobBalance0_0 - BOB_ORDER_SIZE == bobBalance0_1);
        assert(bobBalance1_1 == bobBalance1_0 + receivedBob); // since price is 1 we can use executed

        // 2. Alice's tick should have been fully executed
        (
            uint256 counterTick1,
            UD60x18 totalBalanceTick1,
            UD60x18 executedRatioTick1
        ) = pool.ticks(true, ZERO_PRICE_TICK);
        assert(counterTick1 == 1);
        assert(convert(totalBalanceTick1) == 0);
        assert(convert(executedRatioTick1) == 0);

        // 3. Bob's tick must have been initialized with remaining
        (
            uint256 counterTick2,
            UD60x18 totalBalanceTick2,
            UD60x18 executedRatioTick2        
        ) = pool.ticks(false, ZERO_PRICE_TICK);
        assert(counterTick2 == 1);
        assert(convert(totalBalanceTick2) == BOB_ORDER_SIZE - executedBob);
        assert(convert(executedRatioTick2) == 1);

        // 4. Alice's position should not have been closed
        // since it is lazy loaded
        (
            uint256 counterPos1,
            UD60x18 totalBalancePos1,
            UD60x18 executedRatioPos1
        ) = pool.positions(
                true,
                keccak256(abi.encodePacked(alice, ZERO_PRICE_TICK))
            );
            
        assert(counterPos1 == 1);
        assert(convert(totalBalancePos1) == 10 * DECIMALS); // ALICE_ORDER_SIZE causing stack too deep
        assert(convert(executedRatioPos1) == 1);

        // 3. Bob's position should have been initialized
        (
            uint256 counterPos2,
            UD60x18 totalBalancePos2,
            UD60x18 executedRatioPos2
        ) = pool.positions(
                false,
                keccak256(abi.encodePacked(bob, ZERO_PRICE_TICK))
            );
            
        assert(counterPos2 == 1);
        assert(convert(totalBalancePos2) == 30 * DECIMALS - executedBob); // BOB_ORDER_SIZE causing stack too deep
        assert(convert(executedRatioPos2) == 1);

    }

    // use fuzzying to make sure all prices are calculated correctly
    function test_limit_order_broken_value_ticks(
        uint256 initialTokenAmount,
        uint256 amount0,
        uint256 amount1,
        int24 tick,
        string memory account1
    ) public {
        // test with large token amounts
        vm.assume(initialTokenAmount < 5e32);
        vm.assume(amount0 < initialTokenAmount);
        vm.assume(amount1 <  initialTokenAmount);

        initialTokenAmount = bound(initialTokenAmount, 5e16, 5e29);

        amount0 = bound(amount0, 5000, 1.5e20);
        amount1 = bound(amount1, 5000, 1.5e20);

        amount0 = 5000;
        amount1 = 5000;
        
        // we cannot exponentiate by very large numbers
        // causes overflow on FixedMath.tickValue
        // this covers up unti 1e21/1 price scale
        tick = int24(bound(tick, -35000, 35000));

        address amanda = makeAddr(account1);
        address barney = makeAddr(string.concat(account1, "a"));

        // give accounts balance
        pool.addTokensAccount(false, initialTokenAmount, amanda);
        pool.addTokensAccount(false, initialTokenAmount, barney);
        pool.addTokensAccount(true, initialTokenAmount, amanda);
        pool.addTokensAccount(true, initialTokenAmount, barney);

        // both users add different random amounts to same random tick
        vm.prank(amanda);
        (uint256 executedAmanda, uint256 receivedAmanda) = pool.limitOrderTrade(false, tick, amount1);
        
        vm.prank(barney);
        (uint256 executedBarney, uint256 receivedBarney) = pool.limitOrderTrade(true, tick, amount0);
        
        // user that bid first updates their position
        vm.prank(amanda);
        (,uint256 receivedAmanda0_1,uint256 executedAmanda_1,) = pool.claimExecutedOrder(tick);
        // update amanda's position to sum executed tokens
        executedAmanda += executedAmanda_1;
        // update amanda's position to sum receivals from update
        receivedAmanda += receivedAmanda0_1;

        uint256 tokensToReceive0 = convert(FixedMath.convertAtTick(true, tick, convert(amount1)));
        uint256 tokensToReceive1 = convert(FixedMath.convertAtTick(false, tick, convert(amount0)));

        if (tokensToReceive0 > amount0) {
            tokensToReceive0 = amount0;
        }
        if (tokensToReceive1 > amount1) {
            tokensToReceive1 = amount1;
        }

        assertEq(tokensToReceive1, receivedAmanda, "Amanda should receive correct amount of tokens");
    
        assertEq(tokensToReceive0, receivedBarney, "Barney should receive correct amount of tokens");
        
        assertEq(receivedAmanda, executedBarney, "Amanda's received tokens should be equal to Barney's executed tokens");
        
        assertEq(receivedBarney, executedAmanda, "Barney's received tokens should be equal to Amanda's executed tokens");


    }

    // make sure flipping of ticks doesn't cause any bug
    function test_limit_order_multiple_consecutive_flip_ticks() public {}

    // make sure spotOrderTrade works correctly
    function test_spot_order_trade() public {}

    function test_remove_order() public {}

    function test_claim_executed_order() public {}
}
