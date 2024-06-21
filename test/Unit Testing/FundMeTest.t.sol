// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 5 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    // this functon runs first
    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); // (vm.deal(address, uint256))Used to set the balance of an address to new Balance.
    }

    function testMaximumDollarIsFive() public view {
        //console.log("Salaam there");
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMessageSender() public view {
        assertEq(fundMe.getOwner(), msg.sender); // 'Us' calls the "FundMe test", which then deploys "FundMe".The "FundMe test" becomes the owner of "FundMe", and not 'us'.
        // assertEq(fundMe.i_owner(), address(this)); // returs the address of the current contract
        console.log(msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        // Expect the next operation to revert (fail)
        vm.expectRevert();
        //  Sending 0 Ether
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // The next tx will be sent by USER.
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();
        address funder = fundMe.getFunders(0);
        assertEq(funder, USER);
    }

    function testMultipleFunders() public {
        // Define the users
        address[] memory users = new address[](3);
        users[0] = address(0x123);
        users[1] = address(0x456);
        users[2] = address(0x789);

        // Allocate some Ether to each user using the STARTING_BALANCE constant
        for (uint i = 0; i < users.length; i++) {
            vm.deal(users[i], STARTING_BALANCE);
        }

        // Fund the contract from each user and verify they are added to the funders array
        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            fundMe.fund{value: SEND_VALUE}();
            vm.stopPrank();
            address funder = fundMe.getFunders(i);
            assertEq(funder, users[i]);
        }
    }

    modifier funded() {
        vm.prank(USER); // The next tx will be sent by USER.
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    // (AAA) Testing Methodology:

    function testWithDrawWithASingleFunder() public funded {
        // Arrange: Set up the test by initializing variables, objects and prepping preconditions.
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act: Perform the operation to be tested like a function invocation.
        uint256 gasStart = gasleft(); // Sent: 1000

        vm.txGasPrice(GAS_PRICE); // Sets tx.gasprice for the rest of the transaction.

        vm.prank(fundMe.getOwner()); // Cost: 200
        fundMe.withdraw();

        uint256 gasEnd = gasleft(); // 800
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log(gasUsed);

        // Assert: Compare the received output with the expected output.
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithDrawWithMultipleFunders() public funded {
        // Arrange:
        uint160 numberOfFunders = 10;
        uint160 startingFundersIndex = 1;
        for (uint160 i = startingFundersIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // Sets up a prank from an address that has some ether.
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act:
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert:
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }

    function testWithDrawWithMultipleFundersCheaper() public funded {
        // Arrange:
        uint160 numberOfFunders = 10;
        uint160 startingFundersIndex = 1;
        for (uint160 i = startingFundersIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // Sets up a prank from an address that has some ether.
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act:
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert:
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }
}
