// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./CommonStorage.sol";
import "./CampaignAndPaymentParams.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
contract CommonFeature is
    CommonStorage,
    CampaignAndPaymentParams,
    IERC721Receiver
{
    using ECDSA for bytes32;

    event RefundToken(address client, uint256 amount);
    event RefundEther(address client, uint256 amount);
    event RefundNFT(address client, uint256 tokenID);
    event Airdropped(
        uint256 linkID,
        address claimerWallet,
        uint256 tokenBalance,
        uint256 etherBalance,
        uint256 tokenID
    );

    error NumberOfLinkOutOfRange(uint256 numberOfLinks);
    error CampaignExpired(
        uint256 currentTimestamp,
        uint256 campaignEndTimestamp
    );
    error CampaignNotRunning(State campaignState);
    error CampaignAlreadyStarted(State campaignState);
    error AleadyAirdropped(address recipientWallet);
    error PuzzleNotVerified(bytes32 puzzle);
    error TokenBalanceNotEqual(uint256 tokenBalance);
    error TokenAddressNotSet(address tokenAddress);
    error InsufficientTokenAmount(uint256 value);
    error NotAllowedTokenExist(uint256 tokenID);
    error tokenIDNotEqual(uint256 tokenID);
    error EtherBalanceNotEqual(uint256 etherBalance);
    error InsufficientEtherBalance(uint256 etherBalance);
    error AirdropEtherFailed(bool result);
    error RefundEtherFailed(bool result);
    error NotClient(address sender);
    error NotCampaignEOA(address sender);
    error InsufficientEtherAmount(uint256 value, uint256 requiredAmount);
    error NotApprovedForAll();
    error CampaignCanceld();

    modifier onlyClient() {
        if (msg.sender != client) revert NotClient(msg.sender);
        _;
    }
    modifier onlyCampaignEOA() {
        if (msg.sender != campaignEOA) revert NotCampaignEOA(msg.sender);
        _;
    }
    modifier requireNotStarted() {
        if (campaignState != State.NOT_STARTED)
            revert CampaignAlreadyStarted({campaignState: campaignState});
        _;
    }
    modifier requireRunning() {
        if (campaignState != State.RUNNING)
            revert CampaignNotRunning({campaignState: campaignState});
        _;
    }
    modifier requireNotExpired() {
        if (startTime + duration < block.timestamp) {
            campaignState = State.EXPIRED;
            revert CampaignExpired({
                currentTimestamp: block.timestamp,
                campaignEndTimestamp: startTime + duration
            });
        }
        _;
    }
    modifier requireNotCancelled() {
        if (campaignState == State.CANCELLED) revert CampaignCanceld();
        _;
    }
    modifier hasEnoughEther(uint256 _cost, uint256 _txFee) {
        uint256 requiredAmount = _cost + _txFee + etherAmount;
        if (msg.value < requiredAmount)
            revert InsufficientEtherAmount({
                value: msg.value,
                requiredAmount: requiredAmount
            });
        _;
    }
    modifier checkAleadyAirdropped(uint8 _id) {
        if (_getLink(_id).wallet != address(0))
            revert AleadyAirdropped({recipientWallet: _getLink(_id).wallet});
        _;
    }
    modifier verifyPuzzle(uint8 _id, bytes32 _puzzle) {
        if (_getLink(_id).puzzle != _puzzle)
            revert PuzzleNotVerified({puzzle: _puzzle});
        _;
    }

    constructor() {}

    /// @notice ERC20/721 Campaign deployment
    /// @dev
    /// @param _campaignParams Campaign parameters
    function initialize(CampaignParams memory _campaignParams) public {
        if (
            _campaignParams.numberOfLinks <= 0 ||
            _campaignParams.numberOfLinks > MAXIMUM_LINK_COUNT
        )
            revert NumberOfLinkOutOfRange({
                numberOfLinks: _campaignParams.numberOfLinks
            });

        campaignState = State.NOT_STARTED;
        client = _campaignParams.client;
        factory = payable(msg.sender);
        contractType = ContractType(_campaignParams.contractType); // Todo: bitwise 방식 적용
        campaignEOA = payable(_campaignParams.campaignEOA);
        campaignID = _campaignParams.campaignID;
        numberOfLinks = _campaignParams.numberOfLinks;
        duration = _campaignParams.duration * 60 * 60 * 24;
        startTime = block.timestamp;

        // ERC20
        if (_campaignParams.tokenAmount > 0) {
            if (_campaignParams.tokenAddress == address(0))
                revert TokenAddressNotSet({
                    tokenAddress: _campaignParams.tokenAddress
                });
            tokenAmount = _campaignParams.tokenAmount;
            TOKEN = IERC20(_campaignParams.tokenAddress);
            tokenPerLink =
                _campaignParams.tokenAmount /
                _campaignParams.numberOfLinks;
        }

        // ERC721
        if (_campaignParams.tokenIDs.length > 0) {
            if (_campaignParams.nftAddress == address(0))
                revert TokenAddressNotSet({
                    tokenAddress: _campaignParams.nftAddress
                });

            uint8 _tokenIdLength = uint8(_campaignParams.tokenIDs.length);
            if (_tokenIdLength <= 0 || _tokenIdLength > MAXIMUM_LINK_COUNT)
                revert NumberOfLinkOutOfRange({numberOfLinks: _tokenIdLength});

            tokenIDs = _campaignParams.tokenIDs;
            NFT = IERC721(_campaignParams.nftAddress);
        }

        // Ether
        if (_campaignParams.etherAmount > 0) {
            etherAmount = _campaignParams.etherAmount;
            etherPerLink =
                _campaignParams.etherAmount /
                _campaignParams.numberOfLinks;
        }

        _createMultipleLinks();
    }

    // todo: modifier로 호출자 제한
    function startCampaign() external returns (address) {
        if (tokenAmount > 0 && address(TOKEN) != address(0)) {
            if (TOKEN.balanceOf(address(this)) < tokenAmount)
                revert InsufficientTokenAmount({
                    value: TOKEN.balanceOf(address(this))
                });
        }

        if (tokenIDs.length > 0 && address(NFT) != address(0)) {
            for (uint8 i = 0; i < numberOfLinks; i++) {
                if (IERC721(NFT).ownerOf(tokenIDs[i]) != address(this)) {
                    revert NotAllowedTokenExist({tokenID: tokenIDs[i]});
                }
            }
        }

        if (etherAmount > 0) {
            if (address(this).balance < etherAmount) {
                revert InsufficientEtherAmount({
                    value: address(this).balance,
                    requiredAmount: etherAmount
                });
            }
        }
        campaignState = State.RUNNING;
        return msg.sender;
    }

    /// @notice Airdropping
    /// @param _id Airdro link index number
    /// @param _tokenID NFT Token ID to be airdropped
    /// @param _etherBalance Ether balance of the link
    /// @param _puzzle Puzzle to verify
    /// @param _claimerWallet User wallet address that's getting the airdrop
    /// @dev Only campaignEOA can run this function
    function airdrop(
        uint8 _id,
        uint256 _tokenBalance,
        uint256 _etherBalance,
        uint256 _tokenID,
        bytes32 _puzzle,
        address payable _claimerWallet
    )
        public
        onlyCampaignEOA
        requireRunning
        requireNotExpired
        requireNotCancelled
        checkAleadyAirdropped(_id)
        verifyPuzzle(_id, _puzzle)
    {
        Link memory linkObj = _getLink(_id);
        uint256 _linkTokenBalance = linkObj.tokenBalance;
        uint256 _linkEtherBalance = linkObj.etherBalance;
        uint256 _linkTokenID = linkObj.tokenID;

        linkObj.wallet = _claimerWallet;
        linkObj.tokenBalance = 0; // erc1155 염두해서 일단 놔둬봄
        linkObj.etherBalance = 0;
        _setLink(_id, linkObj);

        // ERC20
        if (tokenPerLink > 0) {
            if (_linkTokenBalance != _tokenBalance)
                revert TokenBalanceNotEqual({tokenBalance: _tokenBalance});

            TOKEN.transfer(_claimerWallet, _tokenBalance);
            // Todo: 결과값 확인
        }

        // ERC721
        if (tokenIDs.length > 0) {
            if (_linkTokenID != _tokenID)
                revert tokenIDNotEqual({tokenID: _tokenID});

            NFT.safeTransferFrom(address(this), _claimerWallet, _tokenID);
            // Todo: 결과값 확인
        }

        // Ether
        if (etherPerLink > 0) {
            if (_linkEtherBalance != _etherBalance)
                revert EtherBalanceNotEqual({etherBalance: _etherBalance});

            if (address(this).balance < _etherBalance)
                revert InsufficientEtherBalance({
                    etherBalance: address(this).balance
                });

            (bool result, ) = _claimerWallet.call{value: _etherBalance}("");
            if (!result) revert AirdropEtherFailed({result: result});
        }

        checkAllLinksUsed();
        emit Airdropped(
            _id,
            _claimerWallet,
            _tokenBalance,
            _etherBalance,
            _tokenID
        );
    }

    /// @notice Get the balance of the contract
    function getBalance()
        public
        view
        onlyClient
        returns (uint256 tokenBalance, uint256 etherBalance, uint256 nftBalance)
    {
        etherBalance = address(this).balance;

        if (address(TOKEN) != address(0) && tokenAmount > 0) {
            tokenBalance = TOKEN.balanceOf(address(this));
        }

        if (address(NFT) != address(0) && tokenIDs.length > 0) {
            nftBalance = NFT.balanceOf(address(this));
        }

        return (tokenBalance, etherBalance, nftBalance);
    }

    /// @notice Fetching whole data of the links
    /// @dev Only client can run this function
    /// @return returns Airdrop link list
    function getLinks() public view onlyClient returns (Link[] memory) {
        Link[] memory linkList = new Link[](numberOfLinks);
        for (uint8 i = 0; i < numberOfLinks; i++) {
            linkList[i] = _links[i];
        }
        return linkList;
    }

    /// @notice Client can cancel the campaign and transfer the fund back to his wallet
    /// @dev Only client can run this function
    function cancelCampaign()
        public
        onlyClient
        requireNotExpired
        requireNotCancelled
    {
        campaignState = State.CANCELLED;
        _refund();
    }

    function _refund() internal {
        uint256 etherBalance = address(this).balance;
        if (etherBalance > 0) {
            (bool result, ) = client.call{value: etherBalance}("");
            if (!result) revert RefundEtherFailed({result: result});
            emit RefundEther(client, etherBalance);
        }

        if (tokenAmount > 0 && address(TOKEN) != address(0)) {
            uint256 tokenBalance = TOKEN.balanceOf(address(this));
            if (tokenBalance > 0) {
                TOKEN.transfer(client, tokenBalance);
                emit RefundToken(client, tokenBalance);
            }
        }

        if (tokenIDs.length > 0 && address(NFT) != address(0)) {
            uint256 refundedNFTCount = 0;
            for (uint8 i = 0; i < tokenIDs.length; i++) {
                Link memory linkObj = _getLink(i);
                if (linkObj.wallet == address(0)) {
                    refundedNFTCount++;
                    NFT.safeTransferFrom(
                        address(this),
                        client,
                        linkObj.tokenID
                    );
                }
            }
            if (refundedNFTCount > 0) emit RefundNFT(client, refundedNFTCount);
        }
    }

    /// @notice Client can change the campaign state as PAUSED or RUNNING
    /// @dev Only client can run this function
    function toggleRunOrPause() public onlyClient returns (State) {
        if (campaignState == State.RUNNING) {
            campaignState = State.PAUSED;
        } else if (campaignState == State.PAUSED) {
            campaignState = State.RUNNING;
        }
        return campaignState;
    }

    /// @notice Can check specific index has been used
    /// @param id Airdrop link index number
    /// @return returns True or False
    function isAvailableLink(uint8 id) public view returns (bool) {
        return _links[id].wallet == address(0);
    }

    /// @notice Checking Puzzle whether the signed message is from the client
    /// @param _id Index number of the link map
    /// @param signature Signed message
    /// @return returns True or False
    function isValidPuzzleSignature(
        uint8 _id,
        bytes calldata signature
    ) public view returns (bool) {
        return
            _links[_id].puzzle.toEthSignedMessageHash().recover(signature) ==
            address(client);
    }

    function _getLink(uint8 id) internal view returns (Link memory) {
        return _links[id];
    }

    function _setLink(uint8 id, Link memory link) internal {
        _links[id] = link;
    }

    /// @notice Creating multiple airdrop links
    function _createMultipleLinks() internal {
        for (uint8 i = 0; i < numberOfLinks; i++) {
            _setOneLink(i);
        }
    }

    /// @notice Creating a single airdrop link
    function _setOneLink(uint8 i) private {
        uint256 _tokenID = 0;
        if (contractType == ContractType.ERC721) {
            _tokenID = tokenIDs[i];
        }
        _setLink(
            i,
            Link(
                i,
                tokenPerLink,
                etherPerLink,
                _tokenID,
                address(0),
                _makePuzzle(i, _tokenID)
            )
        );
    }

    /// @notice Creating a puzzle
    function _makePuzzle(
        uint8 i,
        uint256 tokenID
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    string.concat(
                        Strings.toString(i),
                        Strings.toString(tokenPerLink),
                        Strings.toString(etherPerLink),
                        Strings.toString(tokenID),
                        campaignID
                    )
                )
            );
    }

    function checkAllLinksUsed() public {
        bool allLinksUsed = true;
        for (uint8 i = 0; i < numberOfLinks; i++) {
            if (_links[i].wallet == address(0)) {
                allLinksUsed = false;
            }
        }
        if (allLinksUsed) {
            campaignState = State.FINISHED;
        }
    }

    /// @dev Private function to transfer NFT to this contract
    function _getNFTs() private {
        for (uint8 i = 0; i < numberOfLinks; i++) {
            NFT.safeTransferFrom(client, address(this), tokenIDs[i]);
        }
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        // NFT 수신 시 수행할 로직을 구현 필요
        return this.onERC721Received.selector;
    }
}
