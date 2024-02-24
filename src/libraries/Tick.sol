// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import "./LiquidityMath.sol";

/// @title Tick
/// @notice Contains functions for managing tick processes and relevant calculations
library Tick {
    // info stored for each initialized individual tick
    struct Info {
        // balances of total orders (executed + pending)
        UD60x18 totalBalance;
        // balances of already realized orders
        UD60x18 executedRatio;
    }

    /**
     * @notice Applies the effects of a settled trade to the Tick struct
     * @param self self
     * @param tradedAmount quantity of liquidity tokens effectively traded
     */
    function applyTrade(
        Info storage self,
        UD60x18 tradedAmount
    ) private {
        self.executedRatio = self.executedRatio + tradedAmount;
    }

    /**
     * @notice Adds liquidity to the tick. Must be applied when an account creates a new
     * limit order or increases the size of their previous order in the tick
     * @param self self
     * @param addedLiquidity amount of tokens added to tick liquidity
     */
    function addLiquidity(
        Info storage self,
        UD60x18 addedLiquidity
    ) private {
        Info memory _self = self;
        UD60x18 _totalBalance = _self.totalBalance + addedLiquidity;
        self.executedRatio = _totalBalance * _self.executedRatio / _self.totalBalance;
        self.totalBalance = _totalBalance;
    }

    /**
     * @notice Removes liquidity from the tick. Must be applied when an account deletes their
     * limit order or reduces its size in the tick
     * @param self self
     * @param removedLiquidity amount of tokens removed from liquidity
     */
    function removeLiquidity(
        Info storage self,
        UD60x18 removedLiquidity
    ) private {
        Info memory _self = self;
        UD60x18 _totalBalance = _self.totalBalance - removedLiquidity;
        self.executedRatio = _totalBalance * _self.executedRatio / _self.totalBalance;
        self.totalBalance = _totalBalance;
    }
}
