# Execution Calculation Algorithm

In Cubensis, all limit orders are placed in price `ticks`. A `tick` accumulates liquidity from every single account that placed orders to it.

## The Problem
The problem can be stated as following:

1. Consider the price tick of 10 tokenA for 1 tokenB
2. Consider that sellerA, sellerB and sellerC placed limit orders at that price point to sell tokenA with a size of 50 tokenA each
4. Consider a buyerA just placed an order on the other side of the tick, selling 10 tokenB for 100 tokenA
5. How should the trades be distributed between sellerA, sellerB and sellerC?

There are 2 options to solve this problem:
1. First Come First Serve -> the first seller to have placed their order gets executed first, until their order is fully executed, the the protocol starts to execute for the second seller
2. Percentage based -> The trade is distributed between all orders at that price point pro rata to the size of the orders

Cubensis uses a percentage based pro rata approach as it is more friendly to smart contract based orders, requiring less computation.

## Algorithm requirements
The requirement for implementation is pretty straightforward:

1. Whenever a trade is executed, the contract must check how many percent of the total pending orders was fulfilled. 
2. Each user's individual order must be fulfilled in the same percentage

Example situation:
1. Tick price is 1 tokenA for 1 tokenB
2. sellerA added an order to sell 100 tokenA for 100 tokenB
3. sellerB added an order to sell 50 tokenA for 50 tokenB
4. buyerA added an order to sell 15 tokenB for 15 tokenA

5. There were a total of 150 tokenA available at the tick. buyerA purchased 15 of those - equivalent to 10% of total volume
6. sellerA's order should be executed by 10%, meaning they receive 10 tokenB and still have a 90 tokenA sized order pending
7. sellerB's order should be executed by 10%, meaning they receive 5 tokenB and still have a 40 tokenA sized order pending


Besides the operational requirements, it is also required for smart contract performance that:
1. Performing a trade is O(1) or ar least O(n) to the different ticks being queried
2. Execution of each individual order is lazily evaluated in relation to the tick (this means whenever a trade occurs it is not necessary to update every single user's position)

## Blockchain environment issues
There is a very important issue implementing this algorithm - we have to restrict ourselves to using only integer based arithmetic within smart contracts to maintain precision.

At the same time, the contract can't just update everyone's positions whenever a new order is executed, since that would not be gas efficient.

[This paper](https://batog.info/papers/scalable-reward-distribution.pdf) summarizes the technical issue very well.

## Implementation

To account for changes in proportions between different users adding and removing liquidity we need a little tweak on the data structure:

```solidity
struct TickInfo {
    // total liquidity in the tick
    uint256 totalBalance;
    // total execution ratio - starts at 1
    // uses int128 as per ABDKMath64x64 lib
    int128 executionRatio
}

struct PositionInfo {
    // total liquidity in the tick
    uint256 totalBalance;
    // total execution ratio - starts at 1
    // uses int128 as per ABDKMath64x64 lib
    int128 executionRatio
}
```

User updates their position (cheks if the order has been fulfilled):
```
uint256 newBalance = PositionInfo.totalBalance * TickInfo.executionRatio / PositionInfo.executionRatio;

uint256 executedAmount = PositionInfo.totalBalance - newBalance;

PositionInfo.totalBalance = newBalance
```
The check lazily applies past executions of tick to the user's position. After that, the cached executionRatio in the position is updated to the newest.

User adds liquidity `addedLiquidity`:
```solidity
// TICK
// calculates new total balance
TickInfo.totalBalance += addedLiquidity;

// POSITION
// calculates total liquidity remaining to user
uint256 newTotalBalance = (PositionInfo.totalBalance * TickInfo.executionRatio / PositionInfo.executionRatio) + addedLiquidity;

// reset user's ratio
PositionInfo.executionRatio = TickInfo.executionRatio;
```
This makes sure that the current executed assets held by the user are deducted from their balance (the smart contract must return them to the user) and then updates the position.

*This docs are pseudocode, actual code needs to handle precision errors in operations


Trade is executed in `tradedAmount`:
```
// calculates how many percent of liquidity
// was executed in this trade
int128 ratioExecuted = 1 - tradedAmount / TickInfo.totalBalance;

// updates new total balance
TickInfo.totalBalance -= tradedAmount;

// updates new execution index
TickInfo.executionRatio = TickInfo.executionRatio * ratioExecuted;
```
The trade deducts the totalBalance in the Tick and updates the execution index (so that it can later be lazily applied to every single position).

### Appendix
Notice that removals of liquidity in the algorithm work in the exact same way as adding liquidity, but with subtraction operations.

This algorithm requires high precision numbers to be efficient for small trades. Implementation should use fixed precision numbers with large precision values (specialized libs might be required).