// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("NFT", "NFT") {
        // 컨트랙트 생성과 함께 메시지 발신자에게 100개의 NFT를 발행합니다.
        for (uint i = 0; i < 100; i++) {
            _safeMint(msg.sender, _tokenIds.current());
            _tokenIds.increment();
        }
    }
}
