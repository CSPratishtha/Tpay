// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/TPayPair.sol";

/// @title TPayFactory
/// @notice Factory that creates TPayPair contracts (UniswapV2-style).
/// Follows the pattern: feeTo / feeToSetter. Uses CREATE2 for deterministic pair addresses.
contract TPayFactory is Ownable {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    /// @param _feeToSetter initial address that can set feeTo (later transfer to Timelock/Governance)
    constructor(address _feeToSetter) {
        require(_feeToSetter != address(0), "TPayFactory: zero setter");
        feeToSetter = _feeToSetter;
    }

    /// @notice number of pairs created
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /// @notice Create a pair for tokenA / tokenB. Anyone may call.
    /// Uses CREATE2 with salt = keccak256(token0, token1) to guarantee deterministic address.
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "TPayFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "TPayFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "TPayFactory: PAIR_EXISTS");

        bytes memory bytecode = type(TPayPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // initialize pair (sets token0/token1 inside pair)
        TPayPair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /// @notice Set fee recipient address (only callable by feeToSetter)
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "TPayFactory: FORBIDDEN");
        feeTo = _feeTo;
    }

    /// @notice Change who can set feeTo (only callable by current feeToSetter)
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "TPayFactory: FORBIDDEN");
        require(_feeToSetter != address(0), "TPayFactory: ZERO_ADDRESS");
        feeToSetter = _feeToSetter;
    }
}
