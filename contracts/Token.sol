// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TPAY Token
/// @notice Governance + utility token for the TPay exchange
contract TPAYToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    constructor(address initialOwner, address treasury)
        ERC20("TPAY Token", "TPAY")
        ERC20Permit("TPAY Token")
        Ownable(initialOwner)
    {
        require(treasury != address(0), "treasury=0");
        _mint(treasury, 1_000_000_000 * 10 ** decimals());
    }

    // ---- Required overrides ----

    /// @dev Voting power & ERC20 transfer hook
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    /// @dev Disambiguate multiple Nonces implementations
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
