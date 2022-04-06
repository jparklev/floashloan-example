// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "ds-test/test.sol";

import { Flashloaner } from "../Flashloaner.sol"; 
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract FlashloanerTest is DSTest {
    uint256 public constant INITIAL_BALANCE = 1e18;

    Flashloaner public flashloaner;
    MockERC20 public token;

    // Balance that will be returned to the flashloaner when the `receiveTokens` callback is called
    uint256 public _returnAmount;

    function setUp() public {
        token = new MockERC20("APE TOKEN", "APE", 18);

        // Mint initial Ape tokens to this address
        token.mint(address(this), INITIAL_BALANCE);

        flashloaner = new Flashloaner(address(token));
    }

    /* ========== FLASHLOAN CALLBACK ========== */
    /// This function will be called back into when this contract calls `flashloan` on the Flashloaner
    function receiveTokens(address tokenAddress, uint256 amountToBorrow) public {
        // Do sick arbs with the funds
        MockERC20(tokenAddress).transfer(address(msg.sender), _returnAmount);
    }
    /* ======================================== */

    function testDeposit() public {
        token.approve(address(flashloaner), INITIAL_BALANCE);
        flashloaner.deposit(INITIAL_BALANCE);

        assertEq(token.balanceOf(address(flashloaner)), INITIAL_BALANCE);
        assertEq(token.balanceOf(address(flashloaner)), flashloaner.balance());
    }

    function testFuzzWithdraw(uint256 amount) public {
        // Only test fuzz params that are less than the balance of APE tokens in this contract
        if (amount > INITIAL_BALANCE) {
            return;
        }
        
        token.approve(address(flashloaner), amount);
        flashloaner.deposit(amount);
        // Tokens leave this contract when deposited
        assertEq(token.balanceOf(address(this)), INITIAL_BALANCE - flashloaner.balance());

        flashloaner.withdraw(amount);
        // No funds are left behind in the flashloaner
        assertEq(token.balanceOf(address(this)), INITIAL_BALANCE);
    }

    function testWithdrawTooMuch() public {
        token.approve(address(flashloaner), INITIAL_BALANCE / 2);
        flashloaner.deposit(INITIAL_BALANCE / 2);
        try flashloaner.withdraw(INITIAL_BALANCE) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "NOT_ENOUGH_TOKENS");
        }
    }

    function testBasicFlashLoan() public {
        // Give the flashloaner half of the APE tokens in this contract
        token.approve(address(flashloaner), INITIAL_BALANCE / 2);
        flashloaner.deposit(INITIAL_BALANCE / 2);

        // Borrow and return the full balance available
        uint256 flashloanerBalancePre = flashloaner.balance();
        _returnAmount = flashloanerBalancePre;
        // Should not revert
        flashloaner.flashloan(flashloanerBalancePre);

        assertEq(token.balanceOf(address(this)), INITIAL_BALANCE - flashloanerBalancePre);
        assertEq(flashloanerBalancePre, flashloaner.balance());
        assertEq(token.balanceOf(address(flashloaner)), flashloaner.balance());
    }

    function testFlashloanNothing() public {
        token.approve(address(flashloaner), INITIAL_BALANCE / 2);
        flashloaner.deposit(INITIAL_BALANCE  / 2);

        flashloaner.flashloan(0);
        assertEq(INITIAL_BALANCE / 2, flashloaner.balance());
        assertEq(INITIAL_BALANCE / 2, token.balanceOf(address(this)));
    }

    function testFlashFailingLoanTooLarge() public {
        token.approve(address(flashloaner), INITIAL_BALANCE / 2);
        flashloaner.deposit(INITIAL_BALANCE  / 2);

        try flashloaner.flashloan(INITIAL_BALANCE) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "NOT_ENOUGH_TOKENS");
        }
    }

    function testFlashFailingTooFewTokensReturned() public {
        token.approve(address(flashloaner), INITIAL_BALANCE / 2);
        flashloaner.deposit(INITIAL_BALANCE / 2);

        uint256 flashloanerBalancePre = flashloaner.balance();
        _returnAmount = flashloanerBalancePre / 2;
        try flashloaner.flashloan(flashloanerBalancePre) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "TOO_FEW_TOKENS_RETURNED");
        }
    }

    function testFlashTooManyTokensReturned() public {
        token.approve(address(flashloaner), INITIAL_BALANCE / 4);
        flashloaner.deposit(INITIAL_BALANCE / 4);

        uint256 flashloanerBalancePre = flashloaner.balance();
        _returnAmount = INITIAL_BALANCE / 2;

        flashloaner.flashloan(flashloanerBalancePre);

        assertEq(INITIAL_BALANCE - _returnAmount, token.balanceOf(address(this)));
        assertEq(_returnAmount, flashloaner.balance());
        assertEq(flashloaner.balance(), token.balanceOf(address(flashloaner)));
    }
}
