// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import { ERC20 } from "solmate/tokens/ERC20.sol";

interface FlashloanCallback {
    function receiveTokens(address tokenAddress, uint256 amountToBorrow) external;
}

contract Flashloaner {
    ERC20 public token;
    address public owner;

    constructor(address _token) {
        token = ERC20(_token);
        owner = msg.sender;
    }

    function deposit(uint256 _amount) public {
        token.transferFrom(msg.sender, address(this), _amount);
    }

    // only owner can withdraw (or we would have to allow multiple people being able to deposit/withdraw and handle balances separately)
    function withdraw(uint256 _amount) requiresAuth public nonReentrant {
        token.transfer(msg.sender, _amount);
    }

    function flashloan(uint256 amountToBorrow) public {
        require(amountToBorrow <= balancePreLoan, "NOT_ENOUGH_TOKENS");
        uint256 balancePreLoan = token.balanceOf(address(this));

        token.transfer(msg.sender, amountToBorrow);

        FlashloanCallback(msg.sender).receiveTokens(address(token), amountToBorrow);

        require(balancePreLoan == token.balanceOf(address(this)), "TOO_FEW_TOKENS_RETURNED");
    }

    modifier requiresAuth() {
        require(owner == msg.sender, "UNAUTHORIZED");
        _;
    }
}
