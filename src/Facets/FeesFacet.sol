// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IFeesFacet } from "../Interfaces/IFeesFacet.sol";
import { LibFees} from "../Libraries/LibFees.sol";
import { LibAccess } from "../Libraries/LibAccess.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";

contract FeesFacet is IFeesFacet, ReentrancyGuard {
    /// @inheritdoc IFeesFacet
    function setMaxRubicPlatformFee(
        uint256 _maxFee
    ) external override {
        LibAccess.enforceAccessControl();
        LibFees.setMaxRubicPlatformFee(_maxFee);
    }

    /// @inheritdoc IFeesFacet
    function setRubicPlatformFee(
        uint256 _platformFee
    ) external override {
        LibAccess.enforceAccessControl();
        LibFees.setRubicPlatformFee(_platformFee);
    }

    /// @inheritdoc IFeesFacet
    function setFixedNativeFee(
        uint256 _fixedNativeFee
    ) external override {
        LibAccess.enforceAccessControl();
        LibFees.setFixedNativeFee(_fixedNativeFee);
    }

    /// @inheritdoc IFeesFacet
    function setIntegratorInfo(
        address _integrator,
        IntegratorFeeInfo memory _info
    ) external override {
        LibAccess.enforceAccessControl();
        LibFees.setIntegratorInfo(_integrator, _info);
    }

    /// @inheritdoc IFeesFacet
    function collectIntegratorFee(
        address _token
    ) external override nonReentrant {
        LibFees.collectIntegrator(msg.sender, _token);
    }

    /// @inheritdoc IFeesFacet
    function collectIntegratorFee(
        address _integrator,
        address _token
    ) external override {
        LibAccess.enforceAccessControl();
        LibFees.collectIntegrator(_integrator, _token);
    }

    /// @inheritdoc IFeesFacet
    function collectRubicFee(
        address _token,
        address _recipient
    ) external override {
        LibAccess.enforceAccessControl();
        LibFees.collectRubicFee(_token, _recipient);
    }

    /// @inheritdoc IFeesFacet
    function collectRubicNativeFee(
        address _recipient
    ) external override {
        LibAccess.enforceAccessControl();
        LibFees.collectRubicNativeFee(_recipient);
    }
}
