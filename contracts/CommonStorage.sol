// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract CommonStorage {
    enum State {
        NOT_STARTED,
        RUNNING,
        PAUSED,
        EXPIRED,
        CANCELLED,
        FINISHED
    }
    State public campaignState;

    enum ContractType {
        ERC20,
        ERC721,
        ERC1155
    }
    ContractType contractType;

    struct Link {
        uint8 id;
        uint256 tokenBalance;
        uint256 etherBalance;
        uint256 tokenID;
        address wallet;
        bytes32 puzzle;
    }
    mapping(uint8 => Link) internal _links;

    IERC20 public TOKEN;
    IERC721 public NFT;
    uint8 internal constant MAXIMUM_LINK_COUNT = 50;
    string public version;
    address payable public client;
    address public factory;
    address payable public campaignEOA;
    uint256 public tokenAmount;
    uint256 public tokenPerLink;
    uint256 public etherAmount;
    uint256 public etherPerLink;
    string public campaignID;
    uint256 public duration;
    uint256 public startTime;
    uint8 public numberOfLinks;
    address public implementation;
    bool public initialized;
    uint256[] tokenIDs;
}
