// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./interfaces/ICubensisPool.sol";

import "./libraries/BitMath.sol";
import "./libraries/TickBitmap.sol";
import "./libraries/Tick.sol";
import "./libraries/Position.sol";
import "./libraries/FixedMath.sol";

contract CubensisPool is ICubensisPool {
    using TickBitmap for mapping (int16 => uint256);
    using Tick for Tick.Info;
    using Position for mapping(bytes32 => Position); 
    using Position for Position.Info;

    // address for token pair in pool
    address public token0;
    address public token1;
    // In PoC balances are tracked internally for
    // simplicity
    mapping(bool => mapping (address => uint256)) public tokenBalances;

    // minimum spacing between 2 price ticks
    int24 public tickSpacing;

    mapping (bool => mapping(int24 => Tick.Info)) public ticks;

    // low level map of current ticks with orders
    // each tick only provides liquidity on one side
    mapping(bool => mapping (int16 => uint256)) public tickBitmap;

    // maps for each user position
    // each position map is equivalent to one side of trade
    mapping(bool => mapping(bytes32 => Position.Info)) public positions;

    // gloabal state of prices and orders
    struct Slot0 {
        // tick with best price on both ends
        int24 bestTick0;
        int24 bestTick1;

        // whether there is an initialized tick in each end
        bool intialized0;
        bool initialized1;

        // for reentrancy protection
        bool unlocked;
    }

    Slot0 public slot0;

    constructor() {

    }

    /// INTERNAL FUNCTIONS

    /**
     * @notice Converts an amount of token0 to token1 at the price of
     * a specific tick 
     * @param zeroForOne Token that is being converted 
     * @param quantity Amount of tokens being converted
     * @return value Equivalent amount of other sided tokens
     */
    function _convertAtTick(
        bool zeroForOne,
        int24 tick,
        uint256 quantity
    ) private pure returns (uint256 value) {
        value = FixedMath.convertAtTick(zeroForOne, tick, base);
    }

    /**
     * @notice Internal function to give tokens to an account
     * @dev implemented with internal balances for PoC, can integrate
     * ERC20 or other token standards for implementation
     * @param zeroForOne The side of the trade
     * @param quantity Amount of tokens to be sent
     * @param account Account to receive tokens 
     */
    function _addTokensAccount(
        bool zeroForOne,
        uint256 quantity,
        address account
    ) private {
        tokenBalances[zeroForOne][account] += quantity;
    }

    /**
     * @notice Internal function to remove tokens from an account
     * @dev implemented with internal balances for PoC, can integrate
     * ERC20 or other token standards for implementation
     * @param zeroForOne The side of the trade
     * @param quantity Amount of tokens to be sent
     * @param account Account to remove tokens from 
     */
    function _removeTokensAccount(
        bool zeroForOne,
        uint256 quantity,
        address account
    ) private {
        tokenBalances[zeroForOne][account] -= quantity;
    }

    /**
     * @notice function to open up a new Tick
     * @dev must flip the specific tick and edit its data to include
     * new liquidity
     * @param zeroForOne The side of the trade
     * @param tick Tick to add liquidity to
     * @param amountIn Amount of tokens added as liquidity
     * @param account Account that is adding liquidity
     */
    function _addLiquidityToTick(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn,
        address account
    ) private {
        // load tick struct
        Tick.Info storage tickInfo = ticks[zeroForOne][tick];
        Tick.Info memory _tickInfo = tick;

        // load position strct
        Position.Info storage position = positions[zeroForOne].get(account, tick);
        Position.Info memory _position = position;

        // if tick is uninitiliazed in map, flip it
        if (_tickInfo.totalBalance == _tickInfo.executedBalance) {
            tickBitmap[zeroForOne].flipTick(tick, tickSpacing);
        }

        // get Tick data and update it
        tick.addLiquidity(amountIn);

        // get User's Position and update it
        uint256 executedTokens = position.addLiquidity(tickInfo, amountIn);

        // credit any executionTokens to account
        // must convert quantity of executed tokens to amount
        // of other sided tokens
        _addTokensAccount(!zeroForOne, _convertAtTick(zeroForOne, tick, executedTokens));
    }

    /**
     * @notice function to open up a new Tick
     * @dev must flip the specific tick and edit its data to include
     * new liquidity
     * @param zeroForOne The side of the trade
     * @param tick Tick to remove liquidity from
     * @param amountOut Amount of tokens removed from liquidity
     * @param account Account that is removing liquidity
     */
    function _removeLiquidityFromTick(
        bool zeroForOne,
        int24 tick,
        uint256 amountOut,
        address account
    ) private {
        // load tick struct
        Tick.Info storage tickInfo = ticks[zeroForOne][tick];
        Tick.Info memory _tickInfo = tick;

        // load position strct
        Position.Info storage position = positions[zeroForOne].get(account, tick);
        Position.Info memory _position = position;

        // if tick is uninitiliazed in map, flip it
        if (_tickInfo.totalBalance == _tickInfo.executedBalance) {
            tickBitmap[zeroForOne].flipTick(tick, tickSpacing);
        }

        // get Tick data and update it
        tick.removeLiquidity(amountOut);

        // must flip tick if liquidity goes to zero
        if (ti)

        // get User's Position and update it
        uint256 executedTokens = position.removeLiquidity(tickInfo, amountOut);

        // credit any executionTokens to account
        // must convert quantity of executed tokens to amount
        // of other sided tokens
        _addTokensAccount(!zeroForOne, _convertAtTick(zeroForOne, tick, executedTokens));
    }

    /**
     * @notice Executes trade at a specific tick
     * @param zeroForOne The side of the trade
     * @param tick Tick to trade at
     * @param amount Quantity of tokens to trade for tokens in the tick
     * @return executed Amount of tokens traded in (tokens send by trader)
     * @return received Amount of tokens traded out (tokens received by trader)
     */
    function _executeOnTick(
        bool zeroForOne,
        int24 tick,
        uint256 amount
    )  returns (uint256 executed, uint256 received) {
        // load tick struct
        Tick.Info storage tickInfo = ticks[!zeroForOne][tick];
        Tick.Info memory _tickInfo = tick;

        uint256 tokensToReceive = _convertAtTick(zeroForOne, tick, amount);

        if (_tickInfo.totalBalance - _tickInfo.executedBalance <= tokensToReceive) {
            // If trade is going to take all tokens, recalculated received and executed
            received = _tickInfo.totalBalance - _tickInfo.executedBalance;
            executed = _convertAtTick(zeroForOne, tick, received);
            // set executedBalance to be the full amount of tokens
            tickInfo.executedBalance = _tickInfo.totalBalance;
            // flip tick in bitmap
            tickBitmap[!zeroForOne].flipTick(tick, tickSpacing);
        } else {
            // If trade does not deplete tick, merely update variables
            received = tokensToReceive;
            executed = amount;
            tickInfo.executedBalance += tokensToReceive;
        }
        
    }

    /// PUBLIC FUNCTIONS

    /// @inheritdoc ICubensisPool
    function limitOrderTrade(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn
    ) external returns (uint256 amountInExecuted) {
        // check tick for other side trade

        // if enough liquidity -> execute

        // if not enough liquidty -> add liquidity to tick

    }

    /// @inheritdoc ICubensisPool
    function spotOrderTrade(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn
    ) external returns (uint256 amountInExecuted);

    /// @inheritdoc ICubensisPool
    function removeOrder(
        bool zeroForOne,
        int24 tick,
        uint256 amountOut
    ) external returns (uint256 amountOutExecuted);

    /// @inheritdoc ICubensisPool
    function claimExceutedOrder(
        int24 tick
    ) external returns (uint256 amount0, uint256 amount1);


}
