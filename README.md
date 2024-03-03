# Cubensis - A Fully On chain orderbook

The goal of this project is to realize a fully on chain orderbook. 

It is based off of Uniswap V3 principles.

## Architecture goals

The main insight is to use the tech stack that Uniswap V3 built for tracking liquidity across different price `ticks` to track limit order book activity.

Each pool is composed of 2 assets `A` and `B`. There are different price tickets for the asset pairs, each `tick` represents a 0.001% increment in price between two points on an asset pair's graph.

Any time a user sets a limit order, they select an amount of liquidity and a `tick` value to set their limit orders at. The contract first checks if there is enough opposite side liquidity at that `tick`. If it can find such a `tick`, then it will execute the trade on that `tick`, otherwise, it is going to provide liquidity on that `tick` and create an NFT for the user representing their newly created liquidity position.

The main goal of this project is to provide the basis for a fully on chain orderbook protocol. This project can then be adapted for deployed on privacy preserving EVMs to constitute a **true source of dark liquidity on chain**.

### TODO
- [x] Build price conversion engine - Built using fixed point math
- [x] Build matching engine - We don't need one, MEV is going to match displaced orders for us in O(1)
- [ ] Emit events
- [ ] Build relevant tests
 
### Future work
- [ ] Currently trading amounts that are very small can create rounding down scenarios where it is possible to buy tokens for "free". A production implementation must create larger fixed point types and conversion logic that ensures this never happens (it is possible and simple bu at the same time it's a lot of work to implement properly and efficiently)
- [ ] Currently order of execution within the same `tick` are executed in parallel, according to their share of the `tick` pool. We need to make sure that is acceptable - traditional orderbooks execute orders at same price range in FIFO
- [ ] Currently assets are locked and do not generate yield when they are awaiting execution. A way to generate yield would facilitate liquidity for the protocol
- [ ] A private implementation of Cubensis requires adapting to privacy preserving libraries and designs of the target chain

