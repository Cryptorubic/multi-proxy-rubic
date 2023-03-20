// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;
import { InsufficientBalance, NullAddrIsNotAnERC20Token, NullAddrIsNotAValidSpender, NoTransferToNullAddress, InvalidAmount, NativeValueWithERC, NativeAssetTransferFailed } from "../Errors/GenericErrors.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Proxy } from "../Periphery/ERC20Proxy.sol";
import { LibSwap } from "./LibSwap.sol";
import { LibFees } from "./LibFees.sol";

/// @title LibAsset
/// @notice This library contains helpers for dealing with onchain transfers
///         of assets, including accounting for the native asset `assetId`
///         conventions and any noncompliant ERC20 transfers
library LibAsset {
    uint256 private constant MAX_UINT = type(uint256).max;

    address internal constant NULL_ADDRESS = address(0);

    /// @dev All native assets use the empty address for their asset id
    ///      by convention

    address internal constant NATIVE_ASSETID = NULL_ADDRESS; //address(0)

    /// @notice Gets the balance of the inheriting contract for the given asset
    /// @param assetId The asset identifier to get the balance of
    /// @return Balance held by contracts using this library
    function getOwnBalance(address assetId) internal view returns (uint256) {
        return
            assetId == NATIVE_ASSETID
                ? address(this).balance
                : IERC20(assetId).balanceOf(address(this));
    }

    /// @notice Transfers ether from the inheriting contract to a given
    ///         recipient
    /// @param recipient Address to send ether to
    /// @param amount Amount to send to given recipient
    function transferNativeAsset(
        address payable recipient,
        uint256 amount
    ) internal {
        if (recipient == NULL_ADDRESS) revert NoTransferToNullAddress();
        if (amount > address(this).balance)
            revert InsufficientBalance(amount, address(this).balance);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = recipient.call{ value: amount }("");
        if (!success) revert NativeAssetTransferFailed();
    }

    /// @notice If the current allowance is insufficient, the allowance for a given spender
    /// is set to MAX_UINT.
    /// @param assetId Token address to transfer
    /// @param spender Address to give spend approval to
    /// @param amount Amount to approve for spending
    function maxApproveERC20(
        IERC20 assetId,
        address spender,
        uint256 amount
    ) internal {
        if (address(assetId) == NATIVE_ASSETID) return;
        if (spender == NULL_ADDRESS) revert NullAddrIsNotAValidSpender();
        uint256 allowance = assetId.allowance(address(this), spender);

        if (allowance < amount)
            SafeERC20.safeIncreaseAllowance(
                IERC20(assetId),
                spender,
                MAX_UINT - allowance
            );
    }

    /// @notice Transfers tokens from the inheriting contract to a given
    ///         recipient
    /// @param assetId Token address to transfer
    /// @param recipient Address to send token to
    /// @param amount Amount to send to given recipient
    function transferERC20(
        address assetId,
        address recipient,
        uint256 amount
    ) internal {
        if (isNativeAsset(assetId)) revert NullAddrIsNotAnERC20Token();
        uint256 assetBalance = IERC20(assetId).balanceOf(address(this));
        if (amount > assetBalance)
            revert InsufficientBalance(amount, assetBalance);
        SafeERC20.safeTransfer(IERC20(assetId), recipient, amount);
    }

    /// @notice Transfers tokens from a sender to a given recipient
    /// @param assetId Token address to transfer
    /// @param from Address of sender/owner
    /// @param to Address of recipient/spender
    /// @param amount Amount to transfer from owner to spender
    function transferFromERC20(
        address assetId,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (assetId == NATIVE_ASSETID) revert NullAddrIsNotAnERC20Token();
        if (to == NULL_ADDRESS) revert NoTransferToNullAddress();

        IERC20 asset = IERC20(assetId);
        uint256 prevBalance = asset.balanceOf(to);
        SafeERC20.safeTransferFrom(asset, from, to, amount);
        if (asset.balanceOf(to) - prevBalance != amount)
            revert InvalidAmount();
    }

    /// @dev Deposits asset for bridging and accrues fixed and token fees
    /// @param assetId Address of asset to deposit
    /// @param amount Amount of asset to bridge
    /// @param extraNativeAmount Amount of native token to send to a bridge
    /// @param integrator Integrator for whom to count the fees
    /// @return amountWithoutFees Amount of tokens to bridge minus fees
    function depositAssetAndAccrueFees(
        address assetId,
        uint256 amount,
        uint256 extraNativeAmount,
        address integrator
    ) internal returns (uint256 amountWithoutFees) {
        uint256 accruedFixedNativeFee = LibFees.accrueFixedNativeFee(
            integrator
        );
        // Check that msg value is at least greater than fixed native fee + extra fee sending to bridge
        if (msg.value < accruedFixedNativeFee + extraNativeAmount)
            revert InvalidAmount();

        amountWithoutFees = _depositAndAccrueTokenFee(
            assetId,
            amount,
            accruedFixedNativeFee,
            extraNativeAmount,
            integrator
        );
    }

    /// @dev Deposits assets for each swap that requires and accrues fixed and token fees
    /// @param swaps Array of swap datas
    /// @param integrator Integrator for whom to count the fees
    /// @return amountWithoutFees Array of swap datas with updated amounts
    function depositAssetsAndAccrueFees(
        LibSwap.SwapData[] memory swaps,
        address integrator
    ) internal returns (LibSwap.SwapData[] memory) {
        uint256 accruedFixedNativeFee = LibFees.accrueFixedNativeFee(
            integrator
        );
        if (msg.value < accruedFixedNativeFee) revert InvalidAmount();
        for (uint256 i = 0; i < swaps.length; ) {
            LibSwap.SwapData memory swap = swaps[i];
            if (swap.requiresDeposit) {
                swap.fromAmount = _depositAndAccrueTokenFee(
                    swap.sendingAssetId,
                    swap.fromAmount,
                    accruedFixedNativeFee,
                    0,
                    integrator
                );
            }
            swaps[i] = swap;
            unchecked {
                i++;
            }
        }

        return swaps;
    }

    function _depositAndAccrueTokenFee(
        address assetId,
        uint256 amount,
        uint256 accruedFixedNativeFee,
        uint256 extraNativeAmount,
        address integrator
    ) private returns (uint256 amountWithoutFees) {
        if (isNativeAsset(assetId)) {
            // Check that msg value greater than sending amount + fixed native fees + extra fees sending to bridge
            if (msg.value < amount + accruedFixedNativeFee + extraNativeAmount)
                revert InvalidAmount();
        } else {
            if (amount == 0) revert InvalidAmount();
            uint256 balance = IERC20(assetId).balanceOf(address(this));
            if (balance < amount) revert InsufficientBalance(amount, balance);
            //            getERC20proxy().transferFrom(
            //                assetId,
            //                msg.sender,
            //                address(this),
            //                amount
            //            );
        }

        amountWithoutFees = LibFees.accrueTokenFees(
            integrator,
            amount,
            assetId
        );
    }

    /// @notice Determines whether the given assetId is the native asset
    /// @param assetId The asset identifier to evaluate
    /// @return Boolean indicating if the asset is the native asset
    function isNativeAsset(address assetId) internal pure returns (bool) {
        return assetId == NATIVE_ASSETID;
    }

    /// @notice Wrapper function to transfer a given asset (native or erc20) to
    ///         some recipient. Should handle all non-compliant return value
    ///         tokens as well by using the SafeERC20 contract by open zeppelin.
    /// @param assetId Asset id for transfer (address(0) for native asset,
    ///                token address for erc20s)
    /// @param recipient Address to send asset to
    /// @param amount Amount to send to given recipient
    function transferAsset(
        address assetId,
        address payable recipient,
        uint256 amount
    ) internal {
        (assetId == NATIVE_ASSETID)
            ? transferNativeAsset(recipient, amount)
            : transferERC20(assetId, recipient, amount);
    }

    /// @dev Checks whether the given address is a contract and contains code
    function isContract(address _contractAddr) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(_contractAddr)
        }
        return size > 0;
    }
}
