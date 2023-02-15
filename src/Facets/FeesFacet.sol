// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IFeesFacet } from "../Interfaces/IFeesFacet.sol";
import { LibFees} from "../Libraries/LibFees.sol";
import { LibAccess } from "../Libraries/LibAccess.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { TokenAddressIsZero, InvalidFee } from "../Errors/GenericErrors.sol";


contract FeesFacet is IFeesFacet, ReentrancyGuard {

    /// @inheritdoc IFeesFacet
    function initialize(address _feeTreasure, uint256 _maxRubicPlatformFee) external override {
        LibDiamond.enforceIsContractOwner();
        if (_feeTreasure == address(0)) {
            revert TokenAddressIsZero();
        }
        if (_maxRubicPlatformFee == 0) {
            revert InvalidFee();
        }

        LibFees.FeesStorage storage fs = LibFees.feesStorage();

        fs.feeTreasure = _feeTreasure;
        fs.maxRubicPlatformFee = _maxRubicPlatformFee;
    }

    /// @inheritdoc IFeesFacet
    function setMaxRubicPlatformFee(
        uint256 _maxFee
    ) external override {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        LibFees.setMaxRubicPlatformFee(_maxFee);
    }

    /// @inheritdoc IFeesFacet
    function setRubicPlatformFee(
        uint256 _platformFee
    ) external override {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        LibFees.setRubicPlatformFee(_platformFee);
    }

    /// @inheritdoc IFeesFacet
    function setFixedNativeFee(
        uint256 _fixedNativeFee
    ) external override {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        LibFees.setFixedNativeFee(_fixedNativeFee);
    }

    /// @inheritdoc IFeesFacet
    function setIntegratorInfo(
        address _integrator,
        IntegratorFeeInfo memory _info
    ) external override {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        LibFees.setIntegratorInfo(_integrator, _info);
    }

    /// VIEW FUNCTIONS ///

    function calcTokenFees(
        uint256 _amount,
        address _integrator
    ) external override view returns(uint256 totalFee, uint256 RubicFee, uint256 integratorFee) {
        LibFees.FeesStorage storage fs = LibFees.feesStorage();
        IntegratorFeeInfo memory info = fs.integratorToFeeInfo[_integrator];
        (totalFee, RubicFee) = LibFees._calculateFee(fs, _amount, info);
        integratorFee = totalFee - RubicFee;
    }

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

    function integratorToFeeInfo(address _integrator) external override view returns(
        IFeesFacet.IntegratorFeeInfo memory _info
    ) {
        LibFees.FeesStorage storage s = LibFees.feesStorage();

        _info = s.integratorToFeeInfo[_integrator];
    }
}
