// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Lock Contract
/// @notice Holds TPAY tokens on behalf of users and allows owner to withdraw
contract Lock is Ownable {
    IERC20 public tpayToken;   // reference to TPAY token

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(address _tpayToken, address initialOwner) Ownable(initialOwner) {
        require(_tpayToken != address(0), "Token address = zero");
        tpayToken = IERC20(_tpayToken);
    }

    /// @notice User deposits TPAY tokens into this contract
    function deposit(uint256 amount) external {
        require(amount > 0, "amount=0");
        require(
            tpayToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        emit Deposited(msg.sender, amount);
    }

    /// @notice Owner can withdraw tokens to a given address
    function withdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        require(amount > 0, "amount=0");
        require(
            tpayToken.transfer(to, amount),
            "Withdraw transfer failed"
        );
        emit Withdrawn(to, amount);
    }

    /// @notice Get contract's TPAY balance
    function getBalance() external view returns (uint256) {
        return tpayToken.balanceOf(address(this));
    }
}
