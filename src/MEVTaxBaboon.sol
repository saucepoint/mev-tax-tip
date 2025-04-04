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

/// @title MEVTaxBaboon
/// @dev saucepoint's second version of MEV Taxes (version B)
contract MEVTaxBaboon is BaseHook, Owned {
    using PoolIdLibrary for PoolKey;

    struct Data {
        uint128 lastBlockSeen;
        uint64 minFee;
        uint64 maxFee;
    }

    mapping(PoolId poolId => uint64 referenceMinPriorityFee) public referenceMinPriorityFee;
    mapping(PoolId poolId => uint64 targetFee) public targetFee;
    mapping(PoolId poolId => uint64 runningAverage) public runningAverage;
    mapping(PoolId poolId => uint64[8] priorityFeeHistory) public priorityFeeHistory;

    mapping(PoolId poolId => Data poolData) public poolData;
    mapping(PoolId poolId => mapping(uint128 blockNumber => uint256 topPriorityFee)) public topPriorityFees;

    constructor(IPoolManager _poolManager, address _owner) BaseHook(_poolManager) Owned(_owner) {}

    function _beforeInitialize(address, PoolKey calldata key, uint160) internal override returns (bytes4) {
        require(key.fee == LPFeeLibrary.DYNAMIC_FEE_FLAG, "are u dumb or are u stupid");

        targetFee[key.toId()] = 800; // 5 bips

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
        uint256 currentPriorityFee = tx.gasprice - block.basefee;
        if (currentPriorityFee < referenceMinPriorityFee[poolId]) {
            runningAverage[poolId] -= (referenceMinPriorityFee[poolId] / 8);
            runningAverage[poolId] += uint64(currentPriorityFee / 8);
        }

        // calculate the slope of the linear function, assuming theres a target swap fee
        // targetFee = slope * averagePriorityFee
        // 5 bips = slope * averagePriorityFee
        uint256 slope = targetFee[poolId] / runningAverage[poolId];
        uint256 overrideFee = slope * currentPriorityFee;

        return (
            BaseHook.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            uint24(overrideFee) | LPFeeLibrary.OVERRIDE_FEE_FLAG
        );
    }

    function _runningAverage(PoolId poolId) internal view returns (uint64) {
        return runningAverage[poolId];
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
