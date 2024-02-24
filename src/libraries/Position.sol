// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { UD60x18, convert, ZERO } from "@prb/math/src/UD60x18.sol";

import "./Tick.sol";

/// @title Position
/// @notice Positions represent an owner address' order at a specific tick
/// @dev Positions store additional state for tracking the execution of the order
library Position {
    // info stored for each user's position
    struct Info {
        // The order value in this tick
        UD60x18 totalBalance;
        // The amount of executed value
        UD60x18 executedRatio;
    }

    /**
     * @notice Returns the Info struct of a position, given an owner and position boundaries
     * @param self The mapping containing all user positions
     * @param owner The address of the position owner
     * @param tick The tick for the value
     * @return position The position info struct of the given owners' position
     */
    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tick
    ) internal view returns (Position.Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, tick))];
    }

    /** 
     * @notice Updates the execution status of the position claiming tokens
     * that were executed since last update
     * @dev Must always be called before interacting with user position to update it.
     * Lib only returns excuted value, it must be credited to user in the contract functionality
     * @param self The individual position to update
     * @param tick Current state of the tick
     * @return executed How many tokens of the position were sold since last update
     */
    function update(
        Info storage self,
        Tick.Info memory tick
    ) internal returns (UD60x18 executed) {
        Info memory _self = self;
        Tick.Info memory _tick = tick;

        UD60x18 newBalance = _self.totalBalance * _tick.executedRatio / _self.executedRatio;

        executed = _self.totalBalance - newBalance;

        self.totalBalance = newBalance;
    }

    /** 
     * @notice Adds liquidity to a user's tick position
     * @dev Must only be applied after position has been updated via update function
     * @param self The individual position to update
     * @param tick Current state of the tick
     * @param addedLiquidity How many tokens the user is adding to the position
     * @return executed How many tokens of the position were sold since last update
     */
    function addLiquidity(
        Info storage self,
        Tick.Info memory tick,
        UD60x18 addedLiquidity
    ) internal returns (UD60x18 executed) {
        Info memory _self = self;

        executed = update(self, tick);

        self.totalBalance = _self.totalBalance + addedLiquidity;
        self.executedRatio = ZERO;

    }

    /** 
     * @notice Removes liquidity from a user's tick position
     * @dev Update function is called before applyinh
     * @param self The individual position to update
     * @param tick Current state of the tick
     * @param removedLiquidity How many tokens the user is removing from the position
     * @return executed How many tokens of the position were sold since last update
     */
    function removeLiquidity(
        Info storage self,
        Tick.Info memory tick,
        UD60x18 removedLiquidity
    ) internal returns (UD60x18 executed) {
        Info memory _self = self;

        executed = update(self, tick);

        self.totalBalance = _self.totalBalance - removedLiquidity;
        self.executedRatio = ZERO;

    }
}
