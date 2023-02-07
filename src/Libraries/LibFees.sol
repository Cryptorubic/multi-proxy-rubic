// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IFeesFacet } from "../Interfaces/IFeesFacet.sol";
import { LibUtil } from "../Libraries/LibUtil.sol";
import { FullMath} from "../Libraries/FullMath.sol";
import { LibAsset } from "../Libraries/LibAsset.sol";

/// Implementation of EIP-2535 Diamond Standard
/// https://eips.ethereum.org/EIPS/eip-2535
library LibFees {
    bytes32 internal constant FFES_STORAGE_POSITION = keccak256("rubic.library.fees");
    // Denominator for setting fees
    uint256 internal constant DENOMINATOR = 1e6;

    // Fees specific errors
    error ZeroAmount();
    error FeeTooHigh();
    error ShareTooHigh();
    // ----------------

    event FixedNativeFee(
        uint256 RubicPart,
        uint256 integratorPart,
        address indexed integrator
    );
    event FixedNativeFeeCollected(
        uint256 amount,
        address collector
    );
    event TokenFee(
        uint256 RubicPart,
        uint256 integratorPart,
        address indexed integrator,
        address token
    );
    event IntegratorTokenFeeCollected(
        uint256 amount,
        address indexed integrator,
        address token
    );
    event SetFixedNativeFee(uint256 fee);
    event SetRubicPlatformFee(uint256 fee);
    event SetMaxRubicPlatformFee(uint256 fee);

    struct FeesStorage {
        mapping(address => IFeesFacet.IntegratorFeeInfo) integratorToFeeInfo;
        uint256 maxRubicPlatformFee; // sets in constructor
        uint256 RubicPlatformFee;
        // Rubic fixed fee for swap
        uint256 fixedNativeFee;
        address feeTreasure; //TODO: add setter and init
    }

    function feesStorage() internal pure returns (FeesStorage storage fs) {
        bytes32 position = FFES_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            fs.slot := position
        }
    }

    /**
     * @dev Calculates and accrues fixed crypto fee
     * @param _integrator Integrator's address if there is one
     * @return The amount of fixedNativeFee
     */
    function accrueFixedNativeFee(
        address _integrator
    ) internal returns (uint256) {
        uint256 _fixedNativeFee;
        uint256 _RubicPart;

        FeesStorage storage fs = feesStorage();
        IFeesFacet.IntegratorFeeInfo memory _info = fs.integratorToFeeInfo[_integrator];

        if (_info.isIntegrator) {
            _fixedNativeFee = uint256(_info.fixedFeeAmount);

            if (_fixedNativeFee > 0) {
                _RubicPart =
                    (_fixedNativeFee *
                        _info.RubicFixedCryptoShare) /
                    DENOMINATOR;

                if (_fixedNativeFee - _RubicPart > 0) LibAsset.transferNativeAsset(payable(_integrator), _fixedNativeFee - _RubicPart);
            }
        } else {
            _fixedNativeFee = fs.fixedNativeFee;
            _RubicPart = _fixedNativeFee;
        }

        if (_RubicPart > 0) LibAsset.transferNativeAsset(payable(fs.feeTreasure), _RubicPart);

        emit FixedNativeFee(
            _RubicPart,
            _fixedNativeFee - _RubicPart,
            _integrator
        );

        return _fixedNativeFee;
    }

     /**
     * @dev Calculates token fees and accrues them
     * @param _integrator Integrator's address if there is one
     * @param _amountWithFee Total amount passed by the user
     * @param _token The token in which the fees are collected
     * @return Amount of tokens without fee
     */
    function accrueTokenFees(
        address _integrator,
        uint256 _amountWithFee,
        address _token
    ) internal returns (uint256) {
        FeesStorage storage fs = feesStorage();
        IFeesFacet.IntegratorFeeInfo memory _info = fs.integratorToFeeInfo[_integrator];

        (uint256 _totalFees, uint256 _RubicFee) = _calculateFee(
            fs,
            _amountWithFee,
            _info
        );

        if (_integrator != address(0)) {
            if (_totalFees - _RubicFee > 0) LibAsset.transferAsset(_token, payable(_integrator), _totalFees - _RubicFee);
        }
        if (_RubicFee > 0) LibAsset.transferAsset(_token, payable(fs.feeTreasure), _RubicFee);

        emit TokenFee(
            _RubicFee,
            _totalFees - _RubicFee,
            _integrator,
            _token
        );

        return _amountWithFee - _totalFees;
    }

        /**
     * @dev Sets fee info associated with an integrator
     * @param _integrator Address of the integrator
     * @param _info Struct with fee info
     */
    function setIntegratorInfo(
        address _integrator,
        IFeesFacet.IntegratorFeeInfo memory _info
    ) internal {
        if (_info.tokenFee > DENOMINATOR) {
            revert FeeTooHigh();
        }
        if (
            _info.RubicTokenShare > DENOMINATOR ||
            _info.RubicFixedCryptoShare > DENOMINATOR
        ) {
            revert ShareTooHigh();
        }

        FeesStorage storage fs = feesStorage();

        fs.integratorToFeeInfo[_integrator] = _info;
    }

    /**
     * @dev Sets fixed crypto fee
     * @param _fixedNativeFee Fixed crypto fee
     */
    function setFixedNativeFee(
        uint256 _fixedNativeFee
    ) internal {
        FeesStorage storage fs = feesStorage();
        fs.fixedNativeFee = _fixedNativeFee;

        emit SetFixedNativeFee(_fixedNativeFee);
    }

    /**
     * @dev Sets Rubic token fee
     * @notice Cannot be higher than limit set only by an admin
     * @param _platformFee Fixed crypto fee
     */
    function setRubicPlatformFee(
        uint256 _platformFee
    ) internal {
        FeesStorage storage fs = feesStorage();

        if (_platformFee > fs.maxRubicPlatformFee) {
            revert FeeTooHigh();
        }

        fs.RubicPlatformFee = _platformFee;

        emit SetRubicPlatformFee(_platformFee);
    }

    /**
     * @dev Sets the limit of Rubic token fee
     * @param _maxFee The limit
     */
    function setMaxRubicPlatformFee(
        uint256 _maxFee
    ) internal {
        if (_maxFee > DENOMINATOR) {
            revert FeeTooHigh();
        }

        FeesStorage storage fs = feesStorage();
        fs.maxRubicPlatformFee = _maxFee;

        emit SetMaxRubicPlatformFee(_maxFee);
    }

    /// PRIVATE ///

    /**
     * @dev Calculates fee amount for integrator and rubic, used in architecture
     * @param _amountWithFee the users initial amount
     * @param _info the struct with data about integrator
     * @return _totalFee the amount of Rubic + integrator fee
     * @return _RubicFee the amount of Rubic fee only
     */
    function _calculateFeeWithIntegrator(
        uint256 _amountWithFee,
        IFeesFacet.IntegratorFeeInfo memory _info
    )
        private
        pure
        returns (uint256 _totalFee, uint256 _RubicFee)
    {
        if (_info.tokenFee > 0) {
            _totalFee = FullMath.mulDiv(
                _amountWithFee,
                _info.tokenFee,
                DENOMINATOR
            );

            _RubicFee = FullMath.mulDiv(
                _totalFee,
                _info.RubicTokenShare,
                DENOMINATOR
            );
        }
    }

    function _calculateFee(
        FeesStorage storage _fs,
        uint256 _amountWithFee,
        IFeesFacet.IntegratorFeeInfo memory _info
    )
        internal
        view
        returns (uint256 _totalFee, uint256 _RubicFee)
    {
        if (_info.isIntegrator) {
            (
                _totalFee,
                _RubicFee
            ) = _calculateFeeWithIntegrator(
                _amountWithFee,
                _info
            );
        } else {
            _totalFee = FullMath.mulDiv(
                _amountWithFee,
                _fs.RubicPlatformFee,
                DENOMINATOR
            );

            _RubicFee = _totalFee;
        }
    }
}
