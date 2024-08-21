// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

// Chianlink Local Docs: https://cll-devrel.gitbook.io/chainlink-local-documentation
import {IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {CCIPLocalSimulator} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

import {CrossChainNameServiceRegister} from "../src/CrossChainNameServiceRegister.sol";
import {CrossChainNameServiceLookup} from "../src/CrossChainNameServiceLookup.sol";
import {CrossChainNameServiceReceiver} from "../src/CrossChainNameServiceReceiver.sol";

contract CrossChainNameService is Test {
    CCIPLocalSimulator public ccipLocalSimulator;

    // Source chain - Contract to register a ccns
    CrossChainNameServiceRegister public crossChainNameServiceRegister;

    // Cross chain receiver - Messages sent from CCIP to this receiving contract
    CrossChainNameServiceReceiver public crossChainNameServiceReceiver;

    // Lookup contract - on the source chain
    CrossChainNameServiceLookup public crossChainNameServiceLookupSource;

    // Lookup contract - on receiving chain
    CrossChainNameServiceLookup public crossChainNameServiceLookupReceiver;

    // Come up with some address for Alice for testing purposes
    address public immutable ALICES_ADDRESS = makeAddr("Alice");

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            ,
            ,
            ,

        ) = ccipLocalSimulator.configuration();

        // Create a lookup source chain
        crossChainNameServiceLookupSource = new CrossChainNameServiceLookup();

        // Create the register on source chain
        crossChainNameServiceRegister = new CrossChainNameServiceRegister(
            address(sourceRouter),
            address(crossChainNameServiceLookupSource)
        );

        // Create a lookup on receiving chain
        crossChainNameServiceLookupReceiver = new CrossChainNameServiceLookup();

        // Create a receiver on destination chain
        crossChainNameServiceReceiver = new CrossChainNameServiceReceiver(
            address(destinationRouter),
            address(crossChainNameServiceLookupReceiver),
            chainSelector
        );

        // Provide the Register address to the 'source' lookup
        crossChainNameServiceLookupSource.setCrossChainNameServiceAddress(
            address(crossChainNameServiceRegister)
        );

        // Provide the Receiver address to the lookup receiver
        crossChainNameServiceLookupReceiver.setCrossChainNameServiceAddress(
            address(crossChainNameServiceReceiver)
        );

        // Enable the chain on the register
        uint256 gasLimit = 2000000;
        crossChainNameServiceRegister.enableChain(
            chainSelector,
            address(crossChainNameServiceReceiver),
            gasLimit
        );
    }

    function test_can_register_name() public {
        string memory ALICES_CCNS = "alice.ccns";
        // Prank as Alice when we register the CCNS
        vm.prank(ALICES_ADDRESS);
        // Register Alices address
        crossChainNameServiceRegister.register(ALICES_CCNS);

        // Assert that it's registered on source chain
        assertEq(
            ALICES_ADDRESS,
            crossChainNameServiceLookupSource.lookup(ALICES_CCNS)
        );

        // Assert that it's registered on destination chain
        assertEq(
            ALICES_ADDRESS,
            crossChainNameServiceLookupReceiver.lookup(ALICES_CCNS)
        );
    }
}
