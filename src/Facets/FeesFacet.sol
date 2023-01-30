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

    /// VIEW FUNCTIONS ///

    function fixedNativeFee() external override view returns(
        uint256 _fixedNativeFee
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _fixedNativeFee = s.fixedNativeFee;
    }

    function RubicPlatformFee() external override view returns(
        uint256 _RubicPlatformFee
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _RubicPlatformFee = s.RubicPlatformFee;
    }

    function maxRubicPlatformFee() external override view returns(
        uint256 _maxRubicPlatformFee
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _maxRubicPlatformFee = s.maxRubicPlatformFee;
    }

    function availableRubicNativeFee() external override view returns(
        uint256 _availableRubicNativeFee
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _availableRubicNativeFee = s.availableRubicNativeFee;
    }

    function availableRubicTokenFee(address _token) external override view returns(
        uint256 _availableRubicTokenFee
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _availableRubicTokenFee = s.availableRubicTokenFee[_token];
    }

    function availableIntegratorNativeFee(address _integrator) external override view returns(
        uint256 _availableIntegratorNativeFee
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _availableIntegratorNativeFee = s.availableIntegratorNativeFee[_integrator];
    }

    function availableIntegratorTokenFee(address _token, address _integrator) external override view returns(
        uint256 _availableIntegratorTokenFee
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _availableIntegratorTokenFee = s.availableIntegratorTokenFee[_token][_integrator];
    }

    function integratorToFeeInfo(address _integrator) external override view returns(
        IFeesFacet.IntegratorFeeInfo memory _info
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _info = s.integratorToFeeInfo[_integrator];
    }
}
