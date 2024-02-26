// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

/// @title FixedMath
/// @notice Contains functions for managing tick processes and relevant calculations
library FixedMath {
    
    /**
     * @notice generates UD60x18 1.001 value
     * @return value UD60x18 1.001
     */
    function baseTickValue() internal pure returns (UD60x18 value) {
        UD60x18 one = convert(1);
        UD60x18 fraction = one.div(convert(1000));
        value = one + fraction;
    }

    /**
     * @notice Gets the price value of a tick
     * @param tick the tick to get price for
     * @return value price for the tick
     */
    function tickValue(
        int24 tick
    ) internal pure returns (UD60x18 value) {
        if (tick >= 0) {
             value = baseTickValue().pow(convert(uint256(uint24(tick))));
        } else {
            value = convert(1) / baseTickValue().pow(convert(uint256(uint24(tick))));
        }
    }
    
    /**
     * @notice Get price for an entire trade at a given tick
     * @param zeroForOne side of the trade
     * @param tick tick of the trade
     * @param base amount of base token for trade
     */
    function convertAtTick(
        bool zeroForOne,
        int24 tick,
        UD60x18 base
    ) internal pure returns (UD60x18 value) {
        if (zeroForOne) {
            value = base * tickValue(tick);
        } else {
            value = base / tickValue(tick);
        }
    }
}
