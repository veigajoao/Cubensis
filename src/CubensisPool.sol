// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./interfaces/ICubensisPool.sol";

import { UD60x18, convert, ZERO } from "@prb/math/src/UD60x18.sol";

import "./libraries/Tick.sol";
import "./libraries/Position.sol";
import "./libraries/FixedMath.sol";

contract CubensisPool is ICubensisPool {
    using Tick for Tick.Info;
    using Position for mapping(bytes32 => Position.Info); 
    using Position for Position.Info;

    error Debug(uint256);

    // address for token pair in pool
    // prices are always quoted as token1/token0
    // zeroForOne: The token of the trade. Always refers to liquidity held
    // in the contract. false for adding liquidity to token0 or buying token0, true
    // for adding liquidity to token1 or buying token1
    address public token0;
    address public token1;

    // In PoC balances are tracked internally for simplicity
    mapping(bool => mapping (address => uint256)) public tokenBalances;

    // Each tick represents an 0.001 change in price
    mapping (bool => mapping(int24 => Tick.Info)) public ticks;

    // maps for each user position
    // each position map is equivalent to one side of trade
    mapping(bool => mapping(bytes32 => Position.Info)) public positions;

    constructor() {}

    /// INTERNAL FUNCTIONS

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
        UD60x18 quantity,
        address account
    ) internal {
        tokenBalances[zeroForOne][account] += convert(quantity);
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
        UD60x18 quantity,
        address account
    ) internal {
        tokenBalances[zeroForOne][account] -= convert(quantity);
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
        UD60x18 amountIn,
        address account
    ) internal {
        // load tick struct
        Tick.Info storage tickInfo = ticks[zeroForOne][tick];

        // load position strct
        Position.Info storage position = positions[zeroForOne].get(account, tick);

        // get Tick data and update it
        tickInfo.addLiquidity(amountIn);

        // get User's Position and update it
        UD60x18 executedTokens = position.addLiquidity(tickInfo, amountIn);

        // credit any executionTokens to account
        // must convert quantity of executed tokens to amount
        // of other sided tokens
        _addTokensAccount(!zeroForOne, FixedMath.convertAtTick(zeroForOne, tick, executedTokens), account);
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
        UD60x18 amountOut,
        address account
    ) internal {
        // load tick struct
        Tick.Info storage tickInfo = ticks[zeroForOne][tick];

        // load position strct
        Position.Info storage position = positions[zeroForOne].get(account, tick);

        // get Tick data and update it
        // throws if not enough liquidity
        tickInfo.removeLiquidity(amountOut);

        // get User's Position and update it
        UD60x18 executedTokens = position.removeLiquidity(tickInfo, amountOut);

        // credit any executionTokens to account
        // must convert quantity of executed tokens to amount
        // of other sided tokens
        _addTokensAccount(!zeroForOne, FixedMath.convertAtTick(zeroForOne, tick, executedTokens), account);
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
        UD60x18 amount
    ) internal returns (UD60x18 executed, UD60x18 received) {
        // load tick struct
        Tick.Info storage tickInfo = ticks[zeroForOne][tick];
        Tick.Info memory _tickInfo = tickInfo;

        UD60x18 tokensToReceive = FixedMath.convertAtTick(zeroForOne, tick, amount);

        if (_tickInfo.totalBalance <= tokensToReceive) {
            // If trade is going to take all tokens, recalculated received and executed
            received = _tickInfo.totalBalance;
            executed = FixedMath.convertAtTick(zeroForOne, tick, received);
            // set executedBalance to be the full amount of tokens
            // only call if executed > 0
            if (executed > ZERO) tickInfo.applyTrade(executed);
            
        } else {
            // If trade does not deplete tick, merely update variables
            received = tokensToReceive;
            executed = amount;
            tickInfo.applyTrade(executed);
        }
        
    }

    /// PUBLIC FUNCTIONS

    /// @inheritdoc ICubensisPool
    function limitOrderTrade(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn
    ) external returns (uint256 amountInExecuted, uint256 amountOutReceived) {
        UD60x18 _amountIn = convert(amountIn);
        address _sender = msg.sender;

        // transfer amountIn to contract
        _removeTokensAccount(!zeroForOne, _amountIn, _sender);

        // check tick for other side trade
        (UD60x18 _executed, UD60x18 _received) = _executeOnTick(zeroForOne, tick, _amountIn);

        // add rest as limit order
        _addLiquidityToTick(!zeroForOne, tick, _amountIn - _executed, _sender);

        // transfer received tokens
        _addTokensAccount(zeroForOne, _received, _sender);

        amountInExecuted = convert(_executed);
        amountOutReceived = convert(_received);
    }

    /// @inheritdoc ICubensisPool
    function spotOrderTrade(
        bool zeroForOne,
        int24 tick,
        uint256 amountIn
    ) external returns (uint256 amountInExecuted, uint256 amountOutReceived) {
        UD60x18 _amountIn = convert(amountIn);
        address _sender = msg.sender;

        // we delay the transfer of amountIn to
        // only take the necessary amount
        _removeTokensAccount(!zeroForOne, _amountIn, _sender);

        // check tick for other side trade
        (UD60x18 _executed, UD60x18 _received) = _executeOnTick(zeroForOne, tick, _amountIn);

        // transfer in consumed amountIn tokens
        _removeTokensAccount(!zeroForOne, _executed, _sender);

        // transfer received tokens
        _addTokensAccount(zeroForOne, _received, _sender);

        amountInExecuted = convert(_executed);
         amountOutReceived = convert(_received);
    }

    /// @inheritdoc ICubensisPool
    function removeOrder(
        bool zeroForOne,
        int24 tick,
        uint256 amountOut
    ) external {
        _removeLiquidityFromTick(zeroForOne, tick, convert(amountOut), msg.sender);
    }

    /// @inheritdoc ICubensisPool
    function claimExceutedOrder(
        int24 tick
    ) external virtual returns (uint256 amount0, uint256 amount1) {
        address _sender = msg.sender;

        // update positions
        UD60x18 _executed0 = positions[false].get(_sender, tick).update(ticks[false][tick]);
        UD60x18 _executed1 = positions[true].get(_sender, tick).update(ticks[true][tick]);

        // send tokens
        _addTokensAccount(false, _executed0, _sender);
        _addTokensAccount(true, _executed1, _sender);

        amount0 = convert(_executed0);
        amount1 = convert(_executed1);
    }

}
