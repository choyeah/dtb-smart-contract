// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERCProxy.sol";
import "./CampaignAndPaymentParams.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERCProxy {
    function startCampaign() external returns (address);
}

contract ERCFactory is CampaignAndPaymentParams {
    event ERCProxyDeployed(
        address indexed proxyAddress,
        address indexed client,
        uint8 indexed contractType,
        uint256 createdAt
    );

    event FundsTransferred(
        CampaignParams campaignParams,
        PaymentParams paymentParams
    );

    modifier sufficientEther(
        CampaignParams memory _campaignParams,
        PaymentParams memory _paymentParams
    ) {
        uint256 requiredAmount = _paymentParams.cost +
            _paymentParams.txFee +
            _campaignParams.etherAmount;
        require(msg.value >= requiredAmount, "Insufficient ether amount");
        _;
    }

    function createAndInitializeERCProxy(
        address _implementationAddress,
        CampaignParams memory _campaignParams,
        PaymentParams memory _paymentParams
    ) public payable sufficientEther(_campaignParams, _paymentParams) {
        // 1. Deploy proxy contract
        address newProxyAddress = _deployProxy(
            _implementationAddress,
            _campaignParams
        );

        // 2. Transfer funds to proxy contract
        _transferFundsToProxy(
            _campaignParams,
            _paymentParams,
            payable(newProxyAddress)
        );

        // 3. Update campaign state
        IERCProxy(newProxyAddress).startCampaign();
    }

    function _deployProxy(
        address _implementationAddress,
        CampaignParams memory _campaignParams
    ) private returns (address) {
        ERCProxy newERCProxy = new ERCProxy(
            _implementationAddress,
            _campaignParams
        );

        emit ERCProxyDeployed(
            address(newERCProxy),
            msg.sender,
            _campaignParams.contractType,
            block.timestamp
        );
        return address(newERCProxy);
    }

    function _transferFundsToProxy(
        CampaignParams memory _campaignParams,
        PaymentParams memory _paymentParams,
        address payable _proxyAddress
    ) private {
        _transferERC20(_campaignParams, _proxyAddress);
        _transferNFTs(
            _campaignParams.nftAddress,
            _campaignParams.tokenIDs,
            _proxyAddress
        );
        _transferEther(_campaignParams, _paymentParams, _proxyAddress);
        emit FundsTransferred(_campaignParams, _paymentParams);
    }

    function _transferERC20(
        CampaignParams memory _campaignParams,
        address payable _proxyAddress
    ) private {
        if (
            _campaignParams.tokenAmount > 0 &&
            address(_campaignParams.tokenAddress) != address(0)
        ) {
            require(
                IERC20(_campaignParams.tokenAddress).allowance(
                    msg.sender,
                    address(this)
                ) >= _campaignParams.tokenAmount,
                "Insufficient allowance"
            );
            bool tokenTransferResult = IERC20(_campaignParams.tokenAddress)
                .transferFrom(
                    msg.sender,
                    _proxyAddress,
                    _campaignParams.tokenAmount
                );
            require(tokenTransferResult, "Token transfer failed");
        }
    }

    function _transferNFTs(
        address nftAddress,
        uint256[] memory tokenIDs,
        address payable _proxyAddress
    ) private {
        if (tokenIDs.length > 0 && address(nftAddress) != address(0)) {
            for (uint8 i = 0; i < tokenIDs.length; i++) {
                IERC721(nftAddress).safeTransferFrom(
                    msg.sender,
                    _proxyAddress,
                    tokenIDs[i]
                );
            }
        }
    }

    function _transferEther(
        CampaignParams memory _campaignParams,
        PaymentParams memory _paymentParams,
        address payable _proxyAddress
    ) private {
        // 트랜잭션 수수료, 유료 비용을 수취자에게 전송
        (bool txFeeSendResult, ) = _paymentParams.txFeeReceiver.call{
            value: _paymentParams.txFee
        }("");
        require(txFeeSendResult, "TX fee send failed");
        (bool costSendResult, ) = _paymentParams.costReceiver.call{
            value: _paymentParams.cost
        }("");
        require(costSendResult, "Cost send failed");

        // 에어드랍시 사용될 네이티브 코인이 있으면 etherAmount만큼 Proxy contract로 전송
        if (_campaignParams.etherAmount > 0) {
            (bool result, ) = _proxyAddress.call{
                value: _campaignParams.etherAmount
            }("");
            require(result, "Ether transfer failed");
        }
    }
}
