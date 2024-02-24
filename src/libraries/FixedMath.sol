// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

/// @title FixedMath
/// @notice Contains functions for managing tick processes and relevant calculations
library FixedMath {
    
    function baseTickValue() private pure returns (UD60x18 value) {
        UD60x18 one = convert(1);
        UD60x18 fraction = one.div(convert(1000));
        value = one + fraction;
    }

    function tickValue(
        int24 tick
    ) private pure returns (UD60x18 value) {
        if (tick >= 0) {
             value = baseTickValue().pow(convert(uint256(uint24(tick))));
        } else {
            value = convert(1) / baseTickValue().pow(convert(uint256(uint24(tick))));
        }
    }
    
    function convertAtTick(
        bool zeroForOne,
        int24 tick,
        UD60x18 base
    ) private pure returns (UD60x18 value) {
        if (zeroForOne) {
            value = base * tickValue(tick);
        } else {
            value = base / tickValue(tick);
        }
    }
}
