// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {Constants} from "./base/Constants.sol";
import {Config} from "./base/Config.sol";

contract CreatePoolAndAddLiquidityScript is Script, Constants, Config {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    uint256 token0Amount = 1 ether;
    uint256 token1Amount = 1900e6;

    function run() external {
        // set the price equal to vanilla ETH/USDC 5 bip pool
        PoolKey memory vanillaPool =
            PoolKey({currency0: currency0, currency1: currency1, fee: 500, tickSpacing: 10, hooks: IHooks(address(0))});
        (uint160 vanillaSqrtPrice,,,) = POOLMANAGER.getSlot0(vanillaPool.toId());

        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 10,
            hooks: hookContract
        });
        bytes memory hookData = new bytes(0);

        // --------------------------------- //

        // tick range is +/- 25% of spot price
        // calculating sqrt(price * 1.25e18/1e18) * Q96 is the same as
        // (sqrt(price) * Q96) * (sqrt(0.9e18/1e18))
        // (sqrt(price) * Q96) * (sqrt(0.9e18) / sqrt(1e18))
        int24 tickLower = TickMath.getTickAtSqrtPrice(
            uint160(vanillaSqrtPrice * FixedPointMathLib.sqrt(0.75e18) / FixedPointMathLib.sqrt(1e18))
        );
        int24 tickUpper = TickMath.getTickAtSqrtPrice(
            uint160(vanillaSqrtPrice * FixedPointMathLib.sqrt(1.25e18) / FixedPointMathLib.sqrt(1e18))
        );

        // multicall parameters
        bytes[] memory params = new bytes[](3);

        // initialize pool
        params[0] = abi.encodeWithSelector(posm.initializePool.selector, pool, vanillaSqrtPrice, hookData);

        // mint liquidity on the new pool and the vanilla pool
        (bytes memory actions, bytes[] memory mintParams, uint256 valueToPass) = _mintLiquidityParams(
            pool,
            vanillaPool,
            vanillaSqrtPrice,
            tickLower,
            tickUpper,
            token0Amount,
            token1Amount,
            address(this),
            hookData
        );
        params[1] = abi.encodeWithSelector(
            posm.modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 60
        );

        vm.startBroadcast();
        tokenApprovals();
        vm.stopBroadcast();

        // multicall to atomically create pool & add liquidity
        vm.broadcast();
        posm.multicall{value: valueToPass}(params);
    }

    /// @dev helper function for encoding mint liquidity operation
    /// @dev does NOT encode SWEEP, developers should take care when minting liquidity on an ETH pair
    function _mintLiquidityParams(
        PoolKey memory poolKey0,
        PoolKey memory poolKey1,
        uint160 sqrtPrice,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory, bytes[] memory, uint256 amount0Max) {
        bytes memory actions =
            abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        // Converts token amounts to liquidity units
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPrice, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), amount0, amount1
        );

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            poolKey0, tickLower, tickUpper, liquidity, amount0 + 1000 wei, amount1 + 1000 wei, recipient, hookData
        );
        params[1] = abi.encode(
            poolKey1, tickLower, tickUpper, liquidity, amount0 + 1000 wei, amount1 + 1000 wei, recipient, hookData
        );
        params[1] = abi.encode(poolKey0.currency0, poolKey0.currency1);
        return (actions, params, amount0 * 2 + 2000 wei);
    }

    function tokenApprovals() public {
        if (!currency0.isAddressZero()) {
            token0.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(address(token0), address(posm), type(uint160).max, type(uint48).max);
        }
        if (!currency1.isAddressZero()) {
            token1.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(address(token1), address(posm), type(uint160).max, type(uint48).max);
        }
    }
}
