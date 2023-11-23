// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "./CommonStorage.sol";
import "./CampaignAndPaymentParams.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */

/// @title DTB_ERC20_V4_0_1
/// @author Cho Yeah Hwang
/// @notice Drop the bit ERC20 contract v4
/// @dev
contract ERCProxy is CommonStorage, CampaignAndPaymentParams, Proxy {
    /// @notice ERC20/721 Campaign deployment
    /// @dev
    /// @param _impleAddress Implementation contract address
    /// @param _campaignParams Campaign parameters
    constructor(address _impleAddress, CampaignParams memory _campaignParams) {
        implementation = _impleAddress;

        (bool success, bytes memory returndata) = _impleAddress.delegatecall(
            abi.encodeWithSignature(
                "initialize((uint8,address,address,string,uint8,uint256,address,uint256,address,uint256[],uint256))",
                _campaignParams
            )
        );
        if (!success) {
            if (returndata.length > 0) {
                string memory errorMessage = abi.decode(returndata, (string));
                revert(errorMessage);
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view override returns (address) {
        return implementation;
    }
}
