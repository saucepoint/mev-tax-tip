// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {MEVTaxBaboon} from "../../src/MEVTaxBaboon.sol";

contract BaboonHarness is MEVTaxBaboon {
    constructor(
        IPoolManager _poolManager,
        address _owner
    ) MEVTaxBaboon(_poolManager, _owner) {}

    function getRunningAverage() external view returns (uint64) {
        return 0;
    }

    function getSlope() external view returns (uint64) {
        return 0;
    }

    function getSwapFee() external view returns (uint24) {
        return 0;
    }
}