// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CampaignAndPaymentParams {
    struct CampaignParams {
        uint8 contractType;
        address payable client;
        address payable campaignEOA;
        string campaignID;
        uint8 numberOfLinks;
        uint256 duration;
        address tokenAddress;
        uint256 tokenAmount;
        address nftAddress;
        uint256[] tokenIDs;
        uint256 etherAmount;
    }

    struct PaymentParams {
        uint256 txFee;
        address payable txFeeReceiver;
        uint256 cost;
        address payable costReceiver;
    }
}
