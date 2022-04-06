// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import { ERC20 } from "solmate/tokens/ERC20.sol";

interface FlashloanCallback {
    function receiveTokens(address tokenAddress, uint256 amountToBorrow) external;
}

contract Flashloaner {
    ERC20 public token;
    uint256 public balance;

    constructor(address _token) {
        token = ERC20(_token);
    }

    function deposit(uint256 _amount) public {
        token.transferFrom(msg.sender, address(this), _amount);
        balance += _amount;
    }

    function withdraw(uint256 _amount) public {
        require(_amount <= balance, "NICE_TRY_NERD");
        token.transfer(msg.sender, _amount);
        balance -= _amount;
    }

    function flashloan(uint256 amountToBorrow) public {
        require(amountToBorrow <= balance, "NOT_ENOUGH_TOKENS");
        require(balance == token.balanceOf(address(this)), "UNEXPECTED_BALANCE");

        token.transfer(msg.sender, amountToBorrow);

        FlashloanCallback(msg.sender).receiveTokens(address(token), amountToBorrow);

        require(balance <= token.balanceOf(address(this)), "TOO_FEW_TOKENS_RETURNED");
    }
}
