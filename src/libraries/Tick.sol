// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { UD60x18, convert, ZERO } from "@prb/math/src/UD60x18.sol";

/// @title Tick
/// @notice Contains functions for managing tick processes and relevant calculations
library Tick {
    // info stored for each initialized individual tick
    struct Info {
        // counter to track tick restarts after finishing liquidty
        uint256 counter;
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
    ) internal {
        Info memory _self = self;

        require(_self.totalBalance > ZERO);

        UD60x18 _newBalance = _self.totalBalance - tradedAmount;

        self.executedRatio = _newBalance * _self.executedRatio / _self.totalBalance;
        self.totalBalance = _newBalance;
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
    ) internal {
        Info memory _self = self;

        if (
            _self.counter == 0 || // if tick hasn't been initialized yet
            _self.totalBalance == ZERO // if tick has been fully executed and needs reinitialization
        ) {
            self.counter += 1;
            self.totalBalance = addedLiquidity;
            self.executedRatio = convert(1);
        } else {
            self.totalBalance = _self.totalBalance + addedLiquidity;
        }        
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
    ) internal {
        Info memory _self = self;

        require(_self.counter > 0, "Unitilized tick");
        require(_self.totalBalance > removedLiquidity, "Not enough liquidity");
        self.totalBalance = _self.totalBalance - removedLiquidity;
    }
}
