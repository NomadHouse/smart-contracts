// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {
    constructor() ERC721("TestNFT", "TST") {}

    function faucet(uint256 id) public {
        _safeMint(msg.sender, id);
    }
}
