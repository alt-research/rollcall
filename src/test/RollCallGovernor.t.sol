// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {Vm} from "./lib/Vm.sol";
import {OVM_FakeCrossDomainMessenger} from "./OVM_FakeCrossDomainMessenger.sol";
import {Lib_PredeployAddresses} from "../lib/Lib_PredeployAddresses.sol";
import {RollCallBridge} from "../RollCallBridge.sol";
import {IRollCallGovernor} from "../interfaces/IRollCallGovernor.sol";
import {SimpleRollCallGovernor} from "../extensions/SimpleRollCallGovernor.sol";

contract GovernanceERC20 is ERC20 {
    constructor() public ERC20("Rollcall", "ROLLCALL") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract RollCallGovernorSetup is DSTest {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    GovernanceERC20 internal token;
    RollCallBridge internal bridge;
    SimpleRollCallGovernor internal governor;

    address[] internal sources = new address[](1);
    bytes32[] internal slots = new bytes32[](1);

    function setUp() public virtual {
        token = new GovernanceERC20();

        OVM_FakeCrossDomainMessenger cdm = new OVM_FakeCrossDomainMessenger();

        bridge = new RollCallBridge(cdm);

        sources[0] = address(token);
        slots[0] = bytes32("1");

        governor = new SimpleRollCallGovernor(
            "rollcall",
            sources,
            slots,
            address(bridge)
        );
    }
}

contract RollCallGovernor_Constructor is DSTest {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function testCannotConstructWithSourcesSlotsLengthMismatch() public {
        address[] memory sources = new address[](1);
        sources[0] = address(0);
        bytes32[] memory slots = new bytes32[](0);

        vm.expectRevert("governor: sources slots length mismatch");
        new SimpleRollCallGovernor("rollcall", sources, slots, address(0));
    }
}

contract RollCallGovernor_Metadata is RollCallGovernorSetup {
    function testExpectInitialMetadata() public {
        for (uint256 i = 0; i < slots.length; i++) {
            assertEq(governor.slots()[i], slots[i], "slots mismatch");
            assertEq(governor.sources()[i], sources[i], "sources mismatch");
        }

        assertEq(governor.version(), "1");
        assertEq(governor.name(), "rollcall");
        assertEq(governor.quorum(0), 1);
        assertEq(governor.votingPeriod(), 1);
    }
}
