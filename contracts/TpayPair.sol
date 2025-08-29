// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TPayPair
 * @notice Uniswap V2 style pair contract with LP token inside
 * - mint / burn / swap
 * - protocol fee support via factory.feeTo()
 * - price accumulators (price0CumulativeLast / price1CumulativeLast)
 *
 * Important: Factory must deploy this contract (create2) so that msg.sender in constructor is factory.
 * After deployment factory should call `initialize(token0, token1)` (this contract allows initialize).
 */
contract TPayPair is ERC20 {
    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;           // uses single storage slot
    uint112 private reserve1;
    uint32  private blockTimestampLast;

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint private constant MINIMUM_LIQUIDITY = 10**3;
    uint private constant FEE_NUMERATOR = 997; // fee: 0.3% -> 997/1000 used in invariant check
    uint private constant FEE_DENOMINATOR = 1000;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender, uint amount0In,uint amount1In,uint amount0Out,uint amount1Out,address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    modifier onlyFactory() {
        require(msg.sender == factory, "TPayPair: FORBIDDEN");
        _;
    }

    constructor() ERC20("TPAY-LP", "TPAY-LP") {
        // factory will be the deployer (when factory uses CREATE2)
        factory = msg.sender;
    }

    // initialize called immediately after pair creation to set tokens
    function initialize(address _token0, address _token1) external {
        require(factory == address(0) || msg.sender == factory || factory == msg.sender || token0 == address(0), "TPayPair: ALREADY_INITIALIZED");
        // allow only factory to initialize in normal flow
        require(msg.sender == factory, "TPayPair: ONLY_FACTORY");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    // ---- internal safe transfer helper ----
    function _safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TPayPair: TRANSFER_FAILED");
    }

    // ---- update reserves and price accumulators ----
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "TPayPair: OVERFLOW");
        unchecked {
            uint32 blockTimestamp = uint32(block.timestamp % 2**32);
            uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // price accumulators, encoded as UQ112x112*seconds like Uniswap V2
                price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
            reserve0 = uint112(balance0);
            reserve1 = uint112(balance1);
            blockTimestampLast = blockTimestamp;
            emit Sync(reserve0, reserve1);
        }
    }

    // ---- protocol fee minting (to factory.feeTo) ----
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private {
        address feeTo = ITPayFactory(factory).feeTo();
        if (feeTo != address(0)) {
            if (kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0) * uint(_reserve1));
                uint rootKLast = Math.sqrt(kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply() * (rootK - rootKLast);
                    uint denominator = rootK * 5 + rootKLast; // protocol takes 1/6th of fees
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (kLast != 0) {
            kLast = 0;
        }
    }

    // ---- mint liquidity (anyone who has transferred tokens to contract can call) ----
    function mint(address to) external returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            // permanently lock the MINIMUM_LIQUIDITY tokens
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }
        require(liquidity > 0, "TPayPair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint(reserve0) * uint(reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // ---- burn liquidity ----
    // caller should have previously transferred LP tokens to this contract
    function burn(address to) external returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf(address(this));

        _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply(); // note: totalSupply() is LP total supply
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "TPayPair: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint(reserve0) * uint(reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // ---- swaps ----
    // caller must have transferred required input token(s) to contract before calling
    function swap(uint amount0Out, uint amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, "TPayPair: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "TPayPair: INSUFFICIENT_LIQUIDITY");

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);

        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        uint amount0In = 0;
        uint amount1In = 0;
        if (balance0 > _reserve0) amount0In = balance0 - _reserve0;
        if (balance1 > _reserve1) amount1In = balance1 - _reserve1;
        require(amount0In > 0 || amount1In > 0, "TPayPair: INSUFFICIENT_INPUT_AMOUNT");

        // adjusted balances apply the 0.3% fee: check invariant
        uint balance0Adjusted = (balance0 * FEE_DENOMINATOR) - (amount0In * (FEE_DENOMINATOR - FEE_NUMERATOR));
        uint balance1Adjusted = (balance1 * FEE_DENOMINATOR) - (amount1In * (FEE_DENOMINATOR - FEE_NUMERATOR));
        require(balance0Adjusted * balance1Adjusted >= uint(_reserve0) * uint(_reserve1) * (FEE_DENOMINATOR**2), "TPayPair: K");

        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint(reserve0) * uint(reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // ---- helpers ----
    function skim(address to) external {
        _safeTransfer(token0, to, IERC20(token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(token1, to, IERC20(token1).balanceOf(address(this)) - reserve1);
    }

    function sync() external {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}

/* -------------------------------
   Minimal factory interface used above
--------------------------------*/
interface ITPayFactory {
    function feeTo() external view returns (address);
}

/* -------------------------------
   UQ112x112 small helper (like UniswapV2)
--------------------------------*/
library UQ112x112 {
    uint224 constant Q112 = 2**112;

    function encode(uint112 y) internal pure returns (uint224) {
        return uint224(uint256(y) * Q112);
    }
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224) {
        return x / uint224(y);
    }
}
