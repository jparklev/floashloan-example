// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "ds-test/test.sol";

import { Flashloaner } from "../Flashloaner.sol"; 
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";


contract User { 
    Flashloaner public flashloaner;

    constructor(address _flashloaner) {
        flashloaner = Flashloaner(_flashloaner);
    }

    function doWithdraw(uint256 amount) public {
        flashloaner.withdraw(amount);
    }
}

contract FlashloanerTest is DSTest {
    uint256 public constant INITIAL_BALANCE = 1e18;

    Flashloaner public flashloaner;
    MockERC20 public token;

    // Balance that will be returned to the flashloaner when the `receiveTokens` callback is called
    uint256 public _returnAmount;

    function setUp() public {
        token = new MockERC20("APE TOKEN", "APE", 18);
        flashloaner = new Flashloaner(address(token));
    }

    /* ========== FLASHLOAN CALLBACK ========== */
    /// This function will be called back into when this contract calls `flashloan` on the Flashloaner
    function receiveTokens(address tokenAddress, uint256 amountToBorrow) public {
        // Do sick arbs with the funds
        token.transfer(address(msg.sender), _returnAmount);
    }
    /* ======================================== */

    function testDeposit() public {
        // Mint initial Ape tokens to this address
        token.mint(address(this), INITIAL_BALANCE);
        token.approve(address(flashloaner), INITIAL_BALANCE);

        uint256 balBefore = token.balanceOf(address(flashloaner));
        flashloaner.deposit(INITIAL_BALANCE);

        assertEq(token.balanceOf(address(flashloaner)), INITIAL_BALANCE);
        assertEq(token.balanceOf(address(flashloaner)), balBefore + INITIAL_BALANCE);
    }

    function testWithdraw() public {
        token.mint(address(this), INITIAL_BALANCE);
        token.approve(address(flashloaner), INITIAL_BALANCE);
        flashloaner.deposit(INITIAL_BALANCE);

        // Tokens leave this contract when deposited
        assertEq(token.balanceOf(address(this)), INITIAL_BALANCE - token.balanceOf(address(flashloaner)));

        flashloaner.withdraw(INITIAL_BALANCE);

        // No funds are left behind in the flashloaner
        assertEq(token.balanceOf(address(this)), INITIAL_BALANCE);
    }

    function testWithdrawIfNotOwner() public {
        User user = new User(address(flashloaner));

        token.mint(address(this), INITIAL_BALANCE);
        token.approve(address(flashloaner), INITIAL_BALANCE);
        flashloaner.deposit(INITIAL_BALANCE);

        try user.doWithdraw(INITIAL_BALANCE) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "UNAUTHORIZED");
        }
    }

    function testBasicFlashLoan() public {
        token.mint(address(this), INITIAL_BALANCE);

        // Give the flashloaner half of the APE tokens in this contract
        token.approve(address(flashloaner), INITIAL_BALANCE / 2);
        flashloaner.deposit(INITIAL_BALANCE  / 2);

        // Borrow and return the full balance available
        uint256 flashloanerBalancePre = token.balanceOf(address(flashloaner));
        _returnAmount = flashloanerBalancePre;
        // Should not revert
        flashloaner.flashloan(flashloanerBalancePre);

        assertEq(token.balanceOf(address(this)), INITIAL_BALANCE - flashloanerBalancePre);
        assertEq(flashloanerBalancePre, token.balanceOf(address(flashloaner)));
    }

    function testCantBorrowMoreThanBalance() public {
        try flashloaner.flashloan(100e18) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "NOT_ENOUGH_TOKENS");
        }
    }

    // fuzz tests
    function testFuzzDeposit(uint256 amount) public {
        token.mint(address(this), amount);
        token.approve(address(flashloaner), amount);

        uint256 balBefore = token.balanceOf(address(flashloaner));
        flashloaner.deposit(amount);

        assertEq(token.balanceOf(address(flashloaner)), amount);
        assertEq(token.balanceOf(address(flashloaner)), balBefore + amount);
    }

    function testFuzzWithdraw(uint256 amount) public {
        token.mint(address(this), amount);
        token.approve(address(flashloaner), amount);
        flashloaner.deposit(amount);

        // Tokens leave this contract when deposited
        assertEq(token.balanceOf(address(this)), amount - token.balanceOf(address(flashloaner)));

        flashloaner.withdraw(amount);

        // No funds are left behind in the flashloaner
        assertEq(token.balanceOf(address(this)), amount);
    }

    function testFuzzFlashLoan(uint256 amount) public {
        token.mint(address(this), amount);
        token.approve(address(flashloaner), amount);
        flashloaner.deposit(amount);

        uint256 userBalPreLoan = token.balanceOf(address(this));
        uint256 flashloanerBalPreLoan = token.balanceOf(address(flashloaner));
        _returnAmount = amount;
        flashloaner.flashloan(_returnAmount);

        assertEq(userBalPreLoan, token.balanceOf(address(this)));
        assertEq(flashloanerBalPreLoan, token.balanceOf(address(flashloaner)));
    }

    function testFuzzFlashloanWhenAirdrop(uint256 amount) public {
        token.mint(address(this), amount);
        token.transfer(address(flashloaner), amount);

        _returnAmount = amount / 2;
        flashloaner.flashloan(_returnAmount);
    }

    function testFuzzCantReturnLessThanBorrowed(uint256 amount) public {
        if (amount == 0) amount = 1;
        token.mint(address(this), amount);
        token.approve(address(flashloaner), amount);
        flashloaner.deposit(amount);

        _returnAmount = amount - 1;
        try flashloaner.flashloan(amount) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "TOO_FEW_TOKENS_RETURNED");
        }
    }

}
