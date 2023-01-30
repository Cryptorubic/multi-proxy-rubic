# LibFees

## Description

A library used for setting and collecting fees. Includes logic of setting global Rubic fee info and each specific integrator's fee info.

Rubic accrues fees on each bridge or DEX interaction. There are two fees being accrued:

- fixed native fee (absolute value of native tokens) <a name="fixedNativeFee"></a>
- token fee (percentage of tokens being transferred) <a name="tokenFee"></a>

These two values depend on whether the integrator parameter is specified in function call. If it is not equal to zero address then the fixed native fee and token fee are presented as corresponding values to the integrator. Otherwise, global values of fixed native fee and token fee are taken.

The values of the fees should be fetched using [FeesFacet](./FeesFacet.md)
