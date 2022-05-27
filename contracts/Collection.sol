// contracts/Collection.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Collection is ERC721, Pausable, ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    //=============================== STORAGE ===================================//

    mapping(bytes32 => bytes32) requestIdToTitleId;
    // The follow map from titleId
    mapping(bytes32 => address) titleOwners; // if null addr then title unverified
    mapping(bytes32 => uint8) deedsLeftToMint;
    mapping(bytes32 => uint256[]) titledDeeds;

    // maps deedId to titleId
    bytes32[] internal deeds;

    // Mapping of authorized wallets that have been KYC'd
    mapping(address => bool) _verifiedAddresses;

    // Params for Chainlink Request
    bytes32 private jobId;
    uint256 private fee;

    // Token base URI string
    string internal baseTokenUri;

    // Title search api base URI string
    string internal titleSearchUri;

    // Marketplace smart contract address
    address internal marketplaceContract;

    //=============================== EVENTS ===================================//

    /**
     * @dev Event for deed mint logging
     * @param titleOwner owner/minter of deed
     * @param titleId id of the title of which the deed is a fraction
     * @param deedId id of the deed purchased
     */
    event DeedMinted(address indexed titleOwner, bytes32 titleId, uint256 deedId);
    event TitleVerified(bytes32 titleId);
    event TitleRejected(bytes32 titleId);

    //=============================== INITIALIZATION ===================================//

    /**
     * @notice Initialize the link token and target oracle
     *
     * Kovan Testnet details:
     * Link Token: 0xa36085F69e2889c224210F603D836748e7dC0088
     * Oracle: 0x094C858cF9428a4c18023AA714d3e205b6Db6354 (Oracle Kovan Address)
     * jobId: b107506bb152402dac00444a6da79d44
     *
     */

    constructor(
        address oracle,
        address chainlinkToken,
        string memory titleSearchUri_
    ) ERC721("NomadHouse", "NMH") ConfirmedOwner(msg.sender) {
        setChainlinkOracle(oracle);
        setChainlinkToken(chainlinkToken);
        titleSearchUri = titleSearchUri_;
        jobId = "b107506bb152402dac00444a6da79d44";
        fee = fee_; // (Varies by network and job)

        deeds.push(); // 0th deed used to signal "no such deed"

        _pause(); // start paused because there's more setup to do
    }

    //=============================== OWNER-ONLY FUNCTIONS ===================================//

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev sets new chainlink Job Id 
     */
    function setJobId(bytes32 newJobId) external onlyOwner {
        jobId = newJobId;
    }

    /**
     * @dev sets base uri for all deeds
     */
    function setTokenURI(string memory newURI) external onlyOwner {
        baseTokenUri = newURI;
    }

    /**
     * @dev sets title search uri for title verification
     */
    function setTitleSearchURI(string memory newURI) external onlyOwner {
        titleSearchUri = newURI;
    }

    /**
     * @dev sets marketplace smart contract address to restrict functions to
     * this contract only
     */
    function setMarketplaceContract(address newMarketplaceContract)
        external
        onlyOwner
    {
        marketplaceContract = newMarketplaceContract;
    }

    /**
     * @dev add recipient addresses to the authorized wallets list and grant them the ability to mint
     */
    function authorizeWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "Wallet address cannot be zero address");
        _verifiedAddresses[_wallet] = true;
    }

    /**
     * @dev remove recipient addresses to the authorized wallets list and revoke their ability to mint
     */
    function deauthorizeWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "Wallet address cannot empty");
        _verifiedAddresses[_wallet] = false;
    }

    /**
     * @dev withdraw link from contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    //============================= MODIFIERS ===============================//

    modifier onlyVerifiedAddress(address _address) {
        require(
            _verifiedAddresses[_address] == true,
            "Address must be verified through KYC"
        );
        _;
    }

    modifier onlyMarketplaceContract() {
        require(
            msg.sender == marketplaceContract,
            "Function is restricted to the marketplace contract"
        );
        _;
    }

    modifier onlyTitleOwner(bytes32 titleId) {
        require(msg.sender == titleOwners[titleId], "msg.sender is not title owner");
        _;
    }

    //============================= PUBLIC / EXTERNAL FUNCTIONS ===============================//

    //================== STATE ALTERING FUNCTIONS ==================//

    /**
     * @dev Makes an API call to our in house title search API which will have information on the title
     * and it's whether it's been marked as verified.
     * @param titleId The primary identifier for performing title searches
     */
    function verifyTitleOwnership(bytes32 titleId)
        public
        whenNotPaused
        returns (bytes32 requestId)
    {
        require(titleOwners[titleId] == address(0), "title already verified");
        
        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillTitleOwnershipVerification.selector
        );

        request.add(
            "get",
            string(abi.encodePacked(titleSearchUri, bytes32ToString(titleId), ".json"))
        );

        requestId = sendChainlinkRequest(request, fee);
        
        require(requestIdToTitleId[requestId] == bytes32(""), "request already sent");
        
        requestIdToTitleId[requestId] = titleId;
    }

    /**
     * @dev Receive the response and store it in a mapping to track verified titles
     * @param requestId identifier of original request; used for finding titleId
     * @param _owner address of the title owner
     * @param _fractionalization amount of fractions allowed to mint (Max 52)
     * @param _verified boolean which determines whether the title has been verified by external sources
     */
    function fulfillTitleOwnershipVerification(
        bytes32 requestId,
        address _owner,
        uint8 _fractionalization,
        bool _verified
    ) public whenNotPaused recordChainlinkFulfillment(requestId) {
        bytes32 titleId = requestIdToTitleId[requestId];
        delete requestIdToTitleId[requestId];

        require(titleOwners[titleId] == address(0), "title already verified");
        require(_fractionalization <= 52, 
        "Deeds cannot be fractionalized into more than 52 fractions");

        if (_verified == false) {
            emit TitleRejected(titleId);
            return;
        }

        (address owner, uint8 fractionalization, bool verified) = (_owner, _fractionalization, _verified);

        titleOwners[titleId] = owner;
        deedsLeftToMint[titleId] = fractionalization;
        titledDeeds[titleId] = new uint256[](0);

        // If permitted to mint/sell then also permitted to buy.
        _verifiedAddresses[owner] = true;

        emit TitleVerified(titleId);
    }


    function mintDeeds(bytes32 titleId, uint8 howMany)
        external
        whenNotPaused
        onlyTitleOwner(titleId) // ensures title is verified
    {
        howMany = min(howMany, deedsLeftToMint[titleId]);
        deedsLeftToMint[titleId] -= howMany;

        for (uint256 i = 0; i < howMany; i++) {
            uint256 deedId = deeds.length; // id = length - 1, so doing this first works
            _safeMint(msg.sender, deedId);
            deeds.push(titleId);
            titledDeeds[titleId].push(deedId);
            emit DeedMinted(msg.sender, titleId, deedId);
        }
    }

    //================== NON-MODIFYING FUNCTIONS ==================//

    function getTitle(bytes32 titleId) public view returns (
      address owner, 
      uint8 deedsLeftToMint_, 
      uint256[] memory deeds
    ) {
        owner = titleOwners[titleId];
        deedsLeftToMint_ = deedsLeftToMint[titleId];
        
        deeds = new uint256[](titledDeeds[titleId].length);
        for (uint256 i; i < titledDeeds[titleId].length; i++) {
            deeds[i] = titledDeeds[titleId][i];
        }
    }

    /**
     * @dev returns true or false if the deed exists in the contract
     * @param deedId deed token id to check for
     */
    function exists(uint256 deedId) public view returns (bool) {
        return _exists(deedId);
    }

    /**
     * @dev returns the metadata uri for a given deedId
     * @param deedId the deedId id to return metadata for
     * @return uri string of the deedId metadata
     */
    function uri(uint256 deedId) public view returns (string memory) {
        require(_exists(deedId), "Deed does not exist");
        return
            string(
                abi.encodePacked(_baseURI(), Strings.toString(deedId), ".json")
            );
    }

    /**
     * @dev transfer function (Individual)
     * @param from address string to send the tokens from
     * @param to address string to send the tokens to
     * @param deedId deed token id to transfer
     * @param data additional data in case the minter is a contract
     **/
    function safeTransferFrom(
        address from,
        address to,
        uint256 deedId,
        bytes memory data
    )
        public
        virtual
        override
        whenNotPaused
        onlyVerifiedAddress(to)
        onlyMarketplaceContract
    {
        super.safeTransferFrom(from, to, deedId, data);
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    //============================== PRIVATE / INTERNAL FUNCTIONS  ==============================//

    //================== NON-MODIFYING FUNCTIONS ==================//

    /**
     * @dev returns the metadata base uri string for all tokens
     */
    function _baseURI() internal view override returns (string memory) {
        return baseTokenUri;
    }

    function min(uint8 left, uint8 right) pure private returns (uint8) {
        if (left < right) {
            return left;
        }
        return right;
    }


}
