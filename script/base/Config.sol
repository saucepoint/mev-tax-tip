// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev populated with default anvil addresses
    IERC20 constant token0 = IERC20(address(0)); // native eth
    IERC20 constant token1 = IERC20(address(0x078D782b760474a361dDA0AF3839290b0EF57AD6)); // USDC on unichain
    IHooks constant hookContract = IHooks(address(0x0));

    Currency constant currency0 = Currency.wrap(address(token0));
    Currency constant currency1 = Currency.wrap(address(token1));
}
