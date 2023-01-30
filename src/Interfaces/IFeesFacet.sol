// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFeesFacet {
    struct IntegratorFeeInfo {
        bool isIntegrator; // flag for setting 0 fees for integrator      - 1 byte
        uint32 tokenFee; // total fee percent gathered from user          - 4 bytes
        uint32 RubicTokenShare; // token share of platform commission     - 4 bytes
        uint32 RubicFixedCryptoShare; // native share of fixed commission - 4 bytes
        uint128 fixedFeeAmount; // custom fixed fee amount                - 16 bytes
    }

    /**
     * @dev Integrator can collect fees calling this function
     * @param _token The token to collect fees in
     */
    function collectIntegratorFee(
        address _token
    ) external;

    /**
     * @dev Managers can collect integrator's fees calling this function
     * Fees go to the integrator
     * @param _integrator Address of the integrator
     * @param _token The token to collect fees in
     */
    function collectIntegratorFee(
        address _integrator,
        address _token
    ) external;

    /**
     * @dev Calling this function managers can collect Rubic's token fee
     * @param _token The token to collect fees in
     * @param _recipient The recipient
     */
    function collectRubicFee(
        address _token,
        address _recipient
    ) external;

    /**
     * @dev Calling this function managers can collect Rubic's fixed crypto fee
     * @param _recipient The recipient
     */
    function collectRubicNativeFee(
        address _recipient
    ) external;

     /**
     * @dev Sets fee info associated with an integrator
     * @param _integrator Address of the integrator
     * @param _info Struct with fee info
     */
    function setIntegratorInfo(
        address _integrator,
        IntegratorFeeInfo memory _info
    ) external;

    /**
     * @dev Sets fixed crypto fee
     * @param _fixedNativeFee Fixed crypto fee
     */
    function setFixedNativeFee(
        uint256 _fixedNativeFee
    ) external;

    /**
     * @dev Sets Rubic token fee
     * @notice Cannot be higher than limit set only by an admin
     * @param _platformFee Fixed crypto fee
     */
    function setRubicPlatformFee(
        uint256 _platformFee
    ) external;

    /**
     * @dev Sets the limit of Rubic token fee
     * @param _maxFee The limit
     */
    function setMaxRubicPlatformFee(
        uint256 _maxFee
    ) external;

    function fixedNativeFee() external view returns(
        uint256 _fixedNativeFee
    );
}
