// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Treasury Contract
/// @notice Stores ETH and ERC20 tokens for the TPAY ecosystem
contract Treasury is Ownable {
    event ETHWithdrawn(address indexed to, uint256 amount);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Withdraw ETH (only owner)
    function withdrawETH(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        require(address(this).balance >= amount, "insufficient ETH");

        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit ETHWithdrawn(to, amount);
    }

    /// @notice Withdraw ERC20 tokens (only owner)
    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        require(token != address(0), "token=0");

        require(IERC20(token).transfer(to, amount), "ERC20 transfer failed");

        emit TokenWithdrawn(token, to, amount);
    }

    // Allow contract to receive ETH
    receive() external payable {}
}
