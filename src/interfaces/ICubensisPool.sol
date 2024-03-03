// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICubensisPool {
    
    /**
     * @notice Swap token0 for token1 or token1 for token0
     * at a given tick, add unexecuted part of trade as limit
     * order
     * @dev current implementation is only aware of the selected tick.
     * A more advanced version should look across neighboring ticks as well
     * @param zeroForOne The token of the trade. Always refers to liquidity held
     * in the contract. false for adding liquidity to token0 or buying token0, true
     * for adding liquidity to token1 or buying token1
     * @param tick The tick at which the trade should be executed.
     * @param amountIn The amount of tokens to swap (in token that the user is selling)
     * @return amountInExecuted The amount of tokens that were swapped (denominated in token user is selling)
     * @return amountOutReceived The amount of tokens that were swapped (denominated in token user is buying)
     */
    function limitOrderTrade(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn
    ) external returns (uint256 amountInExecuted, uint256 amountOutReceived);

    /**
     * @notice Swap token0 for token1 or token1 for token0
     * at a given tick, return unexecuted part to user  * order
     * @param zeroForOne The token of the trade. Always refers to liquidity held
     * in the contract. false for adding liquidity to token0 or buying token0, true
     * for adding liquidity to token1 or buying token1
     * @param tick The tick at which the trade should be executed.
     * @param amountIn The amount of tokens to swap (in token that the user is selling)
     * @return amountInExecuted The amount of tokens that were swapped (denominated in token user is selling)
     * @return amountOutReceived The amount of tokens that were swapped (denominated in token user is buying)
     */
    function spotOrderTrade(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn
    ) external returns (uint256 amountInExecuted, uint256 amountOutReceived);

    /**
     * @notice Remove order previously created at a given tick
     * @dev fails if amountOut is not possible to withdraw. Always withdraws the
     * exact amount requested by the user
     * @param zeroForOne The token of the trade. Always refers to liquidity held
     * in the contract. false for adding liquidity to token0 or buying token0, true
     * for adding liquidity to token1 or buying token1
     * @param tick The tick at which the order is located.
     * @param amountOut The amount of tokens to remove from the order
     */
    function removeOrder(
        bool zeroForOne,
        int24 tick,
        uint256 amountOut
    ) external;

    /**
     * @notice After orders are successfully executed, they must be claimed
     * to return to user's balance. Calling this function returns claims all tokens
     * in a given tick.
     * @param tick Tick from ehich to claim executed orders
     * @return executedAmount0 Amount of token0 executed (sold) since last update
     * @return receivedAmount0 Amount of token0 claimed
     * @return executedAmount1 Amount of token1 executed (sold) since last update
     * @return receivedAmount1 Amount of token1 claimed
     */
    function claimExecutedOrder(
        int24 tick
    ) external returns (
        uint256 executedAmount0,
        uint256 receivedAmount0,
        uint256 executedAmount1, 
        uint256 receivedAmount1
    );
}