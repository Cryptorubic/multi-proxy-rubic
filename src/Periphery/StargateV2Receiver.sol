pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { OFTComposeMsgCodec } from "../Libraries/OFTComposeMsgCodec.sol";
import { LibUtil } from "../Libraries/LibUtil.sol";
import { LibAsset } from "../Libraries/LibAsset.sol";

contract StargateV2Receiver is ILayerZeroComposer, Ownable {
    address public immutable endpoint;

    event ReceivedWithoutSwap(address receiver, address token, uint256 amount);

    constructor(address _endpoint) {
        endpoint = _endpoint;
    }

    function lzCompose(
        address,
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) external payable {
        require(msg.sender == endpoint, "!endpoint");

        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);

        (
            address _target,
            address _token,
            address _receiver,
            bytes memory _calldata
        ) = abi.decode(_composeMessage, (address, address, address, bytes));

        IERC20(_token).approve(address(_target), amountLD);

        (bool success, ) = _target.call{ value: msg.value }(_calldata);
        if (!success) {
            IERC20(_token).transfer(_receiver, amountLD);
            emit ReceivedWithoutSwap(_receiver, _token, amountLD);
        }
    }

    function withdrawAsset(
        address _assetAddress,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        address sendTo = (LibUtil.isZeroAddress(_to)) ? msg.sender : _to;
        LibAsset.transferAsset(_assetAddress, payable(sendTo), _amount);
    }

    fallback() external payable {}
    receive() external payable {}
}
