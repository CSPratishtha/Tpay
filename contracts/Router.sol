// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IPair {
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amountA, uint amountB);
    function swap(uint amount0Out, uint amount1Out, address to) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1);
}

contract Router is Ownable {
    using SafeERC20 for IERC20;

    address public immutable factory;

    constructor(address _factory) {
        require(_factory != address(0), "Invalid factory");
        factory = _factory;
    }

    /// @notice Add liquidity to a pool
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountA,
        uint amountB,
        address to
    ) external returns (uint liquidity) {
        address pair = IFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IFactory(factory).createPair(tokenA, tokenB);
        }

        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);

        liquidity = IPair(pair).mint(to);
    }

    /// @notice Remove liquidity from a pool
    function removeLiquidity(
        address tokenA,
        address tokenB,
        address to
    ) external returns (uint amountA, uint amountB) {
        address pair = IFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Pair not exists");

        (amountA, amountB) = IPair(pair).burn(to);
    }

    /// @notice Simple swap
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMin,
        address to
    ) external {
        address pair = IFactory(factory).getPair(tokenIn, tokenOut);
        require(pair != address(0), "Pair not exists");

        (uint112 reserve0, uint112 reserve1) = IPair(pair).getReserves();

        // simple constant product AMM formula
        require(amountIn > 0, "Invalid input");
        uint amountOut = getAmountOut(amountIn, reserve0, reserve1);
        require(amountOut >= amountOutMin, "Slippage");

        IERC20(tokenIn).safeTransferFrom(msg.sender, pair, amountIn);
        IPair(pair).swap(0, amountOut, to);
    }

    /// @notice Constant product formula
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid reserves");
        uint amountInWithFee = amountIn * 997; // 0.3% fee
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
