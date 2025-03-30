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

    struct Data {
        uint128 lastBlockSeen;
        uint64 minFee;
        uint64 maxFee;
    }

    mapping(PoolId poolId => Data poolData) public poolData;
    mapping(PoolId poolId => mapping(uint128 blockNumber => uint256 topPriorityFee)) public topPriorityFees;

    constructor(IPoolManager _poolManager, address _owner) BaseHook(_poolManager) Owned(_owner) {}

    function _beforeInitialize(address, PoolKey calldata key, uint160) internal override returns (bytes4) {
        require(key.fee == LPFeeLibrary.DYNAMIC_FEE_FLAG, "are u dumb or are u stupid");

        // we be lazy as shit so set a max fee of 69 bips by default
        poolData[key.toId()].minFee = 495; // 4.95 bips
        poolData[key.toId()].maxFee = 6_900;

        return BaseHook.beforeInitialize.selector;
    }

    /// @dev Computes a swap fee based on priority fee relative to the highest priority fee in the last seen block
    function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        Data storage data = poolData[poolId];
        uint128 lastBlockSeen = data.lastBlockSeen;
        uint256 minFee = data.minFee;
        uint256 maxFee = data.maxFee;
        uint256 topPriorityFee = topPriorityFees[poolId][lastBlockSeen];
        uint256 txPriorityFee = tx.gasprice - block.basefee;

        // swap fee is priority fee proportional to the previous top priority fee: `maxFee * (txPriorityFee / topPriorityFee)`
        // safe casting because maxFee is capped at 10_000
        uint24 overrideFee = topPriorityFee != 0 ? uint24((maxFee * txPriorityFee) / topPriorityFee) : uint24(maxFee);

        // override fee is a minimum of minFee
        if (overrideFee < minFee) {
            overrideFee = uint24(minFee);
        }

        // set state for future blocks / transactions
        if (lastBlockSeen != block.number) {
            data.lastBlockSeen = uint128(block.number);

            // txPriorityFee is the highest priority fee if this is the first tx in the block
            topPriorityFees[poolId][uint128(block.number)] = txPriorityFee;
        }

        return (
            BaseHook.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            overrideFee | LPFeeLibrary.OVERRIDE_FEE_FLAG
        );
    }

    function setDefaultFee(PoolId poolId, uint64 minFee, uint64 maxFee) external onlyOwner {
        // maximum swap fee is 1%
        require(maxFee <= 10_000, "yo price too high u need to cut ittttt");
        require(minFee < maxFee, "baka");
        Data storage data = poolData[poolId];
        data.minFee = minFee;
        data.maxFee = maxFee;
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
