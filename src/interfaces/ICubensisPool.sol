// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICubensisPool {
    
    /**
     * @notice Swap token0 for token1 or token1 for token0
     * at a given tick, add unexecuted part of trade as limit
     * order
     * @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
     * @param tick The tick at which the trade should be executed.
     * @param amountIn The amount of tokens to swap (in token that the user is selling)
     * @return amountInExecuted The amount of tokens that were swapped (denominated in token user is selling)
     */
    function limitOrderTrade(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn
    ) external returns (uint256 amountInExecuted);

    /**
     * @notice Swap token0 for token1 or token1 for token0
     * at a given tick, return unexecuted part to user  * order
     * @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
     * @param tick The tick at which the trade should be executed.
     * @param amountIn The amount of tokens to swap (in token that the user is selling)
     * @return amountInExecuted The amount of tokens that were swapped (denominated in token user is selling)
     */
    function spotOrderTrade(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn
    ) external returns (uint256 amountInExecuted);

    /**
     * @notice Remove order previously created at a given tick
     * @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
     * @param tick The tick at which the order is located.
     * @param amountOut The amount of tokens to remove from the order
     * @return amountOutExecuted The amount of tokens that were successfully removed from the order
     */
    function removeOrder(
        bool zeroForOne,
        int24 tick,
        uint256 amountOut
    ) external returns (uint256 amountOutExecuted);

    /**
     * @notice After orders are successfully executed, they must be claimed
     * to return to user's balance. Calling this function returns claims all tokens
     * in a given tick.
     * @param tick Tick from ehich to claim executed orders
     * @return amount0 Amount of token0 claimed
     * @return amount1 Amount of token1 claimed
     */
    function claimExceutedOrder(
        int24 tick
    ) external returns (uint256 amount0, uint256 amount1);
}