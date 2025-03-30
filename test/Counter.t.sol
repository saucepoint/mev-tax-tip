// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {MEVTaxTestInProd} from "../src/MEVTaxTestInProd.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract MEVTaxTestInProdTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    MEVTaxTestInProd hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager, address(this)); //Add all the necessary constructor arguments from the hook
        deployCodeTo("MEVTaxTestInProd.sol:MEVTaxTestInProd", constructorArgs, flags);
        hook = MEVTaxTestInProd(flags);

        // Create the pool
        key = PoolKey(currency0, currency1, LPFeeLibrary.DYNAMIC_FEE_FLAG, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);

        tickLower = -60;
        tickUpper = 60;

        uint128 liquidityAmount = 1_000_000e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = posm.mint(
            key,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );
    }

    /// @dev big test bc fuggit
    function test_monolithlic() public {
        // all trades zero for one, exact-input of 1e18
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;

        // set base fee and priority
        vm.fee(1 gwei);
        vm.txGasPrice(1 gwei + 1 gwei); // 1 gwei priority fee
        BalanceDelta firstSwap = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        assertApproxEqRel(firstSwap.amount1(), 1e18, 0.007e18); // 1:1 swap, but with a 0.69% fee bip fee

        vm.txGasPrice(1 gwei + 0.01 gwei);
        BalanceDelta secondSwap = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        assertApproxEqRel(secondSwap.amount1(), 1e18, 0.0005e18); // 0.05% error: 0.0495% fee and price impact

        // second swap gets better output since their fee is much lower
        assertGt(secondSwap.amount1(), firstSwap.amount1());

        // new block
        skip(2);

        // to quote transactions with a reasonable priority fee
        // we use previous block's top priority fee (1 gwei)
        // in practice, the new block's first swap's priority fee will be high and ~equal to previous block's first swap
        vm.fee(2 gwei);
        vm.txGasPrice(2 gwei + 0.01 gwei);

        BalanceDelta thirdSwap = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        assertApproxEqRel(thirdSwap.amount1(), 1e18, 0.0005e18); // 0.05% error: 0.0495% fee and price impact
    }
}
