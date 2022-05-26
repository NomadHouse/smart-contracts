// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestLinkToken is ERC20 {
    constructor() ERC20("Link", "LNK"){}

    function faucet(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function transferAndCall(
        address,
        uint256,
        bytes memory
    ) public pure returns (bool success) {
        return true;
    }
}
