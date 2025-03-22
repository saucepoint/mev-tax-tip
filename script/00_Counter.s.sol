// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {Constants} from "./base/Constants.sol";
import {MEVTaxTestInProd} from "../src/MEVTaxTestInProd.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

/// @notice Mines the address and deploys the MEVTaxTestInProd.sol Hook contract
contract MEVTaxTestInProdScript is Script, Constants {
    function setUp() public {}

    function run(address _owner) public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG);

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(POOLMANAGER, _owner);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(MEVTaxTestInProd).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.broadcast();
        MEVTaxTestInProd counter = new MEVTaxTestInProd{salt: salt}(IPoolManager(POOLMANAGER), _owner);
        require(address(counter) == hookAddress, "MEVTaxTestInProdScript: hook address mismatch");
    }
}
