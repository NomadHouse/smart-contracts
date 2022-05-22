// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestNFT is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {}

    function faucet(uint256 id, uint256 amount) public {
        _mint(msg.sender, id, amount, "");
    }
}
