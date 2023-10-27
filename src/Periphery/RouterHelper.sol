// SPDX-License-Identifier: AGPL-3.0-or-later

import "@openzeppelin/contracts/utils/Address.sol";

pragma solidity 0.8.17;

interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function nonces(address owner) external view returns (uint);
}

interface IBasePool is IERC20 {
    function getReserves() external view returns (uint, uint);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function poolType() external view returns (uint16);

    function token0PrecisionMultiplier() external view returns (uint);

    function token1PrecisionMultiplier() external view returns (uint);
}

interface IFactory {
    function getPool(
        address tokenA,
        address tokenB
    ) external view returns (address pool);

    function getSwapFee(
        address pool,
        address sender,
        address tokenIn,
        address tokenOut,
        bytes calldata data
    ) external view returns (uint24 swapFee);
}

interface IFeeManager {
    function getSwapFee(
        address pool,
        address sender,
        address tokenIn,
        address tokenOut,
        bytes calldata data
    ) external view returns (uint24);

    function getProtocolFee(address pool) external view returns (uint24);

    function getFeeRecipient() external view returns (address);

    function defaultSwapFee(uint16) external view returns (uint24);

    function defaultProtocolFee(uint16) external view returns (uint24);

    function feeRecipient() external view returns (address);
}

interface IMaster is IFeeManager {
    function feeManager() external view returns (address);

    function isPool(address pool) external view returns (bool);
}

contract RouteHelper {
    using Address for address;

    /*//////////////////////////////////////////////////////////////
                              SWAP ROUTES
    //////////////////////////////////////////////////////////////*/

    function _getPoolReserves(
        address factory,
        address tokenA,
        address tokenB
    )
        private
        view
        returns (address pool, uint reserveA, uint reserveB, uint16 poolType)
    {
        pool = IFactory(factory).getPool(tokenA, tokenB);

        if (pool.isContract()) {
            // return empty values if pool not exists
            (uint reserve0, uint reserve1) = IBasePool(pool).getReserves();
            (reserveA, reserveB) = tokenA < tokenB
                ? (reserve0, reserve1)
                : (reserve1, reserve0);
            poolType = IBasePool(pool).poolType();
        }
    }

    struct RoutePool {
        address pool;
        address tokenA;
        address tokenB;
        uint16 poolType;
        uint reserveA;
        uint reserveB;
        uint24 swapFeeAB;
        uint24 swapFeeBA;
    }

    function _getRoutePool(
        address factory,
        address tokenA,
        address tokenB,
        address account,
        address feeManager
    ) private view returns (RoutePool memory data) {
        (
            address contractAddress,
            uint reserveA,
            uint reserveB,
            uint16 poolType
        ) = _getPoolReserves(factory, tokenA, tokenB);

        data = RoutePool({
            pool: contractAddress,
            tokenA: tokenA,
            tokenB: tokenB,
            poolType: poolType,
            reserveA: reserveA,
            reserveB: reserveB,
            swapFeeAB: reserveA != 0
                ? IFeeManager(feeManager).getSwapFee(
                    contractAddress,
                    account,
                    tokenA,
                    tokenB,
                    ""
                )
                : 0,
            swapFeeBA: reserveA != 0
                ? IFeeManager(feeManager).getSwapFee(
                    contractAddress,
                    account,
                    tokenB,
                    tokenA,
                    ""
                )
                : 0
        });
    }

    struct RoutePools {
        RoutePool[] poolsDirect;
        RoutePool[] poolsA;
        RoutePool[] poolsB;
        RoutePool[] poolsBase;
    }

    struct RoutePoolsContext {
        uint m;
        uint n;
        uint i;
        uint mi;
        uint bi;
        uint bn;
    }

    // get route pools for token A and tokenB with factories and base tokens.
    function getRoutePools(
        address tokenA,
        address tokenB,
        address[] calldata factories,
        address[] calldata baseTokens,
        address master,
        address account
    ) external view returns (RoutePools memory routePools) {
        RoutePoolsContext memory it;
        it.m = factories.length;
        it.n = baseTokens.length;

        // declare array
        routePools.poolsDirect = new RoutePool[](it.m);

        it.i = it.n * it.m; // a, b pools length = base * variety, reused as root base index below
        routePools.poolsA = new RoutePool[](it.i);
        routePools.poolsB = new RoutePool[](it.i);

        it.i = (((it.n - 1) * it.n) / 2) * it.m; // bases pools length, base pairs * variety
        routePools.poolsBase = new RoutePool[](it.i);

        // declare vars for loop
        address factory;
        address base;
        address baseOther;
        it.i = 0;

        address feeManager = IMaster(master).feeManager();

        // collect pools for each factory
        while (it.mi < it.m) {
            factory = factories[it.mi];

            // collect pools: direct, a <> b
            routePools.poolsDirect[it.mi] = _getRoutePool(
                factory,
                tokenA,
                tokenB,
                account,
                feeManager
            );

            // collect pools for each base token
            for (it.i = 0; it.i < it.n; ) {
                // root grow from 0
                base = baseTokens[it.i];

                it.bi = it.mi * it.n + it.i; // a,b pools index shift by factory, reused as base pair index below

                // collect pools: tokenA <> base
                if (tokenA != base && base != tokenB) {
                    routePools.poolsA[it.bi] = _getRoutePool(
                        factory,
                        tokenA,
                        base,
                        account,
                        feeManager
                    );
                }

                // collect pools: tokenB <> base
                if (tokenB != base && base != tokenA) {
                    routePools.poolsB[it.bi] = _getRoutePool(
                        factory,
                        base,
                        tokenB,
                        account,
                        feeManager
                    );
                }

                // collect pools: base to base
                it.bi = it.i + 1;
                while (it.bi < it.n) {
                    // skip used roots (... < i) and itself (i)
                    baseOther = baseTokens[it.bi];

                    if (base != baseOther) {
                        routePools.poolsBase[it.bn++] = _getRoutePool(
                            factory,
                            base,
                            baseOther,
                            account,
                            feeManager
                        );
                    }

                    unchecked {
                        ++it.bi;
                    }
                }

                unchecked {
                    ++it.i;
                }
            }

            unchecked {
                ++it.mi;
            }
        }
    }
}
