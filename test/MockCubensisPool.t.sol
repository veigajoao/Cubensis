// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {CubensisPool} from "../src/CubensisPool.sol";

import { UD60x18, convert, ZERO } from "@prb/math/src/UD60x18.sol";

contract MockCubensisPool is CubensisPool {
    
    /**
     * @notice Mocked function for testing. Give tokens to an account
     * @dev implemented with internal balances for PoC, can integrate
     * ERC20 or other token standards for implementation
     * @param zeroForOne The side of the trade
     * @param quantity Amount of tokens to be sent
     * @param account Account to receive tokens 
     */
    function addTokensAccount(
        bool zeroForOne,
        uint256 quantity,
        address account
    ) external {
        _addTokensAccount(zeroForOne, convert(quantity), account);
    }

    /**
     * @notice Mocked function for testing. Removes tokens from an account
     * @dev implemented with internal balances for PoC, can integrate
     * ERC20 or other token standards for implementation
     * @param zeroForOne The side of the trade
     * @param quantity Amount of tokens to be sent
     * @param account Account to receive tokens 
     */
    function removeTokensAccount(
        bool zeroForOne,
        uint256 quantity,
        address account
    ) internal {
        _addTokensAccount(zeroForOne, convert(quantity), account);
    }
}