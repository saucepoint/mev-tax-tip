// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Owned} from "solmate/src/auth/Owned.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";

contract MEVTaxTestInProd is BaseHook, Owned {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId poolId => uint256 lastBlockSeen) public lastBlockSeen;
    mapping(PoolId poolId => mapping(uint256 blockNumber => uint256 topPriorityFee)) public topPriorityFees;
    mapping(PoolId poolId => uint256 maxFee) public maxFees;

    constructor(IPoolManager _poolManager, address _owner) BaseHook(_poolManager) Owned(_owner) {}

    function _beforeInitialize(address, PoolKey calldata key, uint160) internal pure override returns (bytes4) {
        require(key.fee == LPFeeLibrary.DYNAMIC_FEE_FLAG, "are u dumb or are u stupid");
        return BaseHook.beforeInitialize.selector;
    }

    /// @dev Computes a swap fee based on priority fee relative to the highest priority fee in the last seen block
    function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint256 maxFee = maxFees[key.toId()];
        uint256 topPriorityFee = topPriorityFees[key.toId()][lastBlockSeen[key.toId()]];
        uint256 txPriorityFee = tx.gasprice - block.basefee;

        // swap fee is priority fee proportional to the previous top priority fee: `maxFee * (txPriorityFee / topPriorityFee)`
        // safe casting because maxFee is capped at 10_000
        uint24 overrideFee = topPriorityFee != 0 ? uint24((maxFee * txPriorityFee) / topPriorityFee) : uint24(maxFee);

        // set state for future blocks / transactions
        if (lastBlockSeen[key.toId()] != block.number) {
            lastBlockSeen[key.toId()] = block.number;

            // txPriorityFee is the highest priority fee if this is the first tx in the block
            topPriorityFees[key.toId()][block.number] = txPriorityFee;
        }

        return (
            BaseHook.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            overrideFee | LPFeeLibrary.OVERRIDE_FEE_FLAG
        );
    }

    function setMaxFee(PoolId poolId, uint256 maxFee) external onlyOwner {
        // maximum swap fee is 1%
        require(maxFee <= 10_000, "yo price too high u need to cut ittttt");
        maxFees[poolId] = maxFee;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}
