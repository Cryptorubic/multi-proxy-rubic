// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ICelerWithdraw } from "../Interfaces/ICelerWithdraw.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { LibAccess } from "../Libraries/LibAccess.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { ZeroAddress } from "../Errors/GenericErrors.sol";

/// @title Celer Withdraw Facet
/// @notice Provides functionality to perform authorized Celer's refund with transferring to the actual sender
contract CelerWithdrawFacet is ReentrancyGuard {
    /// @notice The contract address of the Celer bridge
    ICelerWithdraw private immutable celer;

    /// Types ///

    struct CelerData {
        bytes _wdmsg;
        bytes[] _sigs;
        address[] _signers;
        uint256[] _power;
    }

    /// Constructor ///

    constructor(ICelerWithdraw _celer) {
        if (address(_celer) == address(0)) {
            revert ZeroAddress();
        }
        celer = _celer;
    }

    /// External Methods ///

    /// @notice Performs Celer's refund to the actual sender
    /// @param _celerData the core information needed for a refund
    /// @param _asset the asset of a refund
    /// @param _recipient the actual sender who should receive a refund
    function withdrawFromCeler(
        CelerData calldata _celerData,
        address _asset,
        address payable _recipient
    ) external nonReentrant {
        if (_recipient == address(0)) {
            revert ZeroAddress();
        }

        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }

        uint256 balanceBefore = LibAsset.getOwnBalance(_asset);

        celer.withdraw(
            _celerData._wdmsg,
            _celerData._sigs,
            _celerData._signers,
            _celerData._power
        );

        LibAsset.transferAsset(
            _asset,
            _recipient,
            LibAsset.getOwnBalance(_asset) - balanceBefore
        );
    }
}
