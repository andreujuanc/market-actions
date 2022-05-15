//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../uniswap/IUniswapV2Router01.sol";
import "../uniswap/IUniswapV2Pair.sol";
import "../IEIP20.sol";

abstract contract Swap {
    IUniswapV2Router01 router;

    constructor(address router_) {
        router = IUniswapV2Router01(router_);
    }

    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toAmount,
        address receipient
    ) public {
        require(IEIP20(fromToken).approve(address(router), fromAmount), "approve failed.");

        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;

        uint deadline = block.timestamp + 100;

        router.swapExactTokensForTokens(
            fromAmount,
            toAmount, // amountOutMin: we can skip computing this number because the math is tested
            path,
            receipient,
            deadline
        );
    }

    // function pairInfo(address tokenA, address tokenB)
    //     internal
    //     view
    //     returns (
    //         uint256 reserveA,
    //         uint256 reserveB,
    //         uint256 totalSupply
    //     )
    // {
    //     IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB));
    //     totalSupply = pair.totalSupply();
    //     (uint256 reserves0, uint256 reserves1, ) = pair.getReserves();
    //     (reserveA, reserveB) = tokenA == pair.token0() ? (reserves0, reserves1) : (reserves1, reserves0);
    // }

    // function computeLiquidityShareValue(
    //     uint256 liquidity,
    //     address tokenA,
    //     address tokenB
    // ) external override returns (uint256 tokenAAmount, uint256 tokenBAmount) {
    //     revert("TODO");
    // }
}
