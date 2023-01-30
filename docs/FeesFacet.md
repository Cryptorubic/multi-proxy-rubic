# Fees Facet

## Description

Manages the fee values and used to collect the fees and check fee values and available fee amount to collect

## View functions

Use the `fixedNativeFee` to fetch the current value of global fixed native fee

```solidity
function fixedNativeFee() external view returns(
    uint256 _fixedNativeFee
);
```

Use the `RubicPlatformFee` to fetch the current value of global token fee

```solidity
function RubicPlatformFee() external view returns(
    uint256 _RubicPlatformFee
);
```

Use the `maxRubicPlatformFee` to fetch the current value of max global token fee

```solidity
function maxRubicPlatformFee() external view returns(
    uint256 _maxRubicPlatformFee
);
```

Use the `integratorToFeeInfo` to fetch the [fee info](../src/Interfaces/IFeesFacet.sol) corresponding to specified integrator

```solidity
function integratorToFeeInfo(address _integrator) external view returns(
    IFeesFacet.IntegratorFeeInfo memory _info
);
```

Use the `availableRubicNativeFee` to fetch the current available amount of Rubic's fixed native fee to collect

```solidity
function availableRubicNativeFee() external view returns(
    uint256 _availableRubicNativeFee
);
```

Use the `availableRubicTokenFee` to fetch the current available amount of Rubic's token fee in specified token to collect

```solidity
function availableRubicTokenFee(address _token) external view returns(
    uint256 _availableRubicTokenFee
);
```

Use the `availableIntegratorNativeFee` to fetch the current available amount of specified integrator's fixed native fee to collect

```solidity
function availableIntegratorNativeFee(address _integrator) external view returns(
    uint256 _availableIntegratorNativeFee
);
```

Use the `availableIntegratorTokenFee` to fetch the current available amount of specified integrator's token fee in specified token to collect

```solidity
function availableIntegratorTokenFee(address _token, address _integrator) external view returns(
    uint256 _availableIntegratorTokenFee
);
```
