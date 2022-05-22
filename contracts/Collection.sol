// contracts/Collection.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "./chainlink/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
// import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Collection is ERC721, Ownable, Pausable {
    using Counters for Counters.Counter;
    using Chainlink for Chainlink.Request;

    //=============================== STORAGE ===================================//

    Counters.Counter private _deedIds;

    // Global variable used to store chainlinks per-title response when verifying title ownership
    mapping(bytes32 => bool) _verifiedTitles;

    // Mapping of authorized wallets that have been KYC'd
    mapping(address => bool) _verifiedAddresses;

    // Params for Chainlink Request
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    // Internal Struct for tracking Fractional Property Deeds
    struct FractionalDeed {
        uint256 id;
        bytes32 titleId;
        address payable owner;
    }

    // Token base URI string
    string internal baseTokenUri;

    // Title search api base URI string
    string internal titleSearchUri;

    // Marketplace smart contract address
    address internal marketplaceContract;

    // Key value pair containing a list of deeds in the contract
    mapping(uint256 => FractionalDeed) internal deeds;

    // Mapping from deed ID to owner address
    mapping(uint256 => address) internal _owners;

    //=============================== EVENTS ===================================//

    /**
     * @dev Event for deed mint logging
     * @param receiver who got the deed
     * @param deedId id of the deed purchased
     */
    event DeedMinted(address indexed receiver, uint256 deedId);

    /**
     * @dev Event for batch deed mint logging
     * @param receiver who got the deeds
     * @param deedIds ids of the deeds purchased
     */
    event DeedsMinted(
        address indexed receiver,
        uint256 amount,
        uint256[] deedIds
    );

    //=============================== INITIALIZATION ===================================//

    /**
     * @notice Initialize the link token and target oracle
     *
     * Kovan Testnet details:
     * Link Token: 0xa36085F69e2889c224210F603D836748e7dC0088
     * Oracle: 0x094C858cF9428a4c18023AA714d3e205b6Db6354 (Oracle Kovan Address)
     * jobId: 67bc04e4db32473bb5a893674f7e6342
     *
     */

    constructor() ERC721("NomadHouse", "NMH") ConfirmedOwner(msg.sender) {
        oracle = 0x094C858cF9428a4c18023AA714d3e205b6Db6354;
        setChainlinkToken(0xa36085F69e2889c224210F603D836748e7dC0088);
        setChainlinkOracle(oracle);
        titleSearchUri = "https://bafybeihuftdtf5rjkep52k5afrydtlo4mvznafhtmrsqaunaninykew3qe.ipfs.dweb.link/";
        jobId = "67bc04e4db32473bb5a893674f7e6342";
        fee = 0; // (Varies by network and job)
    }

    //=============================== OWNER-ONLY FUNCTIONS ===================================//

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev sets base uri for all deeds
     */
    function setTokenURI(string memory newURI)
        external
        whenNotPaused
        onlyOwner
    {
        baseTokenUri = newURI;
    }

    /**
     * @dev sets title search uri for title verification
     */
    function setTitleSearchURI(string memory newURI)
        external
        whenNotPaused
        onlyOwner
    {
        titleSearchUri = newURI;
    }

    /**
     * @dev sets marketplace smart contract address to restrict functions to
     * this contract only
     */
    function setMarketplaceContract(address newMarketplaceContract)
        external
        whenNotPaused
        onlyOwner
    {
        marketplaceContract = newMarketplaceContract;
    }

    /**
     * @dev add recipient addresses to the authorized wallets list and grant them the ability to mint
     */
    function authorizeWallet(address _wallet) external whenNotPaused onlyOwner {
        require(_wallet != address(0), "Wallet address cannot be zero address");
        _verifiedAddresses[_wallet] = true;
    }

    /**
     * @dev remove recipient addresses to the authorized wallets list and revoke their ability to mint
     */
    function deauthorizeWallet(address _wallet)
        external
        whenNotPaused
        onlyOwner
    {
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

    //============================= PUBLIC / EXTERNAL FUNCTIONS ===============================//

    //================== STATE ALTERING FUNCTIONS ==================//

    /**
     * @dev Makes an API call to our in house title search API which will have information on the title
     * and it's whether it's been marked as verified.
     * @param _titleId The primary identifier for performing title searches
     */
    function verifyTitleOwnership(bytes32 _titleId)
        public
        returns (bytes32 requestId)
    {
        require(
            bytes(titleSearchUri).length != 0,
            "Cannot execute ChainLink request: Title Search URI is empty"
        );
        require(
            _titleId.length != 0,
            "Cannot execute ChainLink request: Request Parameter Title ID is empty"
        );

        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillMultipleParameters.selector
        );

        // Set the URL to perform the GET request on
        request.add(
            "get",
            string(abi.encodePacked(titleSearchUri, _titleId, ".json"))
        );

        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }

    /**
     * @dev Receive the response and store it in a mapping to track verified titles
     */
    function fulfillTitleOwnershipVerification(
        bytes32 _requestId,
        bytes32 _titleId,
        bool _verified
    ) public recordChainlinkRequest(_requestId) {
        _verifiedTitles[_titleId] = _verified;
    }

    function mintDeed(
        address _address,
        bytes32 titleId,
        bytes memory data
    )
        external
        whenNotPaused
        onlyVerifiedAddress(_address)
        onlyMarketplaceContract
    {
        uint256 currentDeedId = _deedIds.current();
        require(deeds[currentDeedId] == 0, "Deed has already been minted");

        if (_verifiedTitles[titleId].length == 0) {
            verifyTitleOwnership(titleId);
        }
        require(
            _verifiedTitles[titleId] == true,
            "Title ownership has not been verified"
        );

        _safeMint(_address, currentDeedId);
        deeds[currentDeedId] = FractionalDeed(
            currentDeedId,
            _address,
            _verifiedTitles[titleId]
        );
        _owners[currentDeedId] = _address;
        _deedIds.increment();

        emit DeedsMinted(_address, currentDeedId);
    }

    //================== NON-MODIFYING FUNCTIONS ==================//

    /**
     * @dev returns address that is currently the owner of a specific deed Id
     * @param deedId deed token id to check for
     */
    function ownerOf(uint256 deedId)
        public
        view
        virtual
        override
        returns (address)
    {
        require(_exists(deedId), "Deed does not exist");

        return _owners[deedId];
    }

    /**
     * @dev returns true or false if the deed exists in the contract
     * @param deedId deed token id to check for
     */
    function exists(uint256 deedId) public view virtual returns (bool) {
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
    ) public virtual override onlyVerifiedAddress(to) onlyMarketplaceContract {
        super.safeTransferFrom(from, to, deedId, data);
        _owners[deedId] = to;
    }

    /**
     * @dev transfer function (Batch)
     * @param from address string to send the tokens from
     * @param to address string to send the tokens to
     * @param deedIds deed token ids to transfer
     * @param data additional data in case the minter is a contract
     **/
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory deedIds,
        bytes memory data
    ) public virtual onlyVerifiedAddress(to) onlyMarketplaceContract {
        for (uint256 i = 0; i < deedIds.length; i++) {
            super.safeTransferFrom(from, to, deedIds[i], data);
            _owners[deedIds[i]] = to;
        }
    }

    //============================== PRIVATE / INTERNAL FUNCTIONS  ==============================//

    //================== NON-MODIFYING FUNCTIONS ==================//

    /**
     * @dev returns the metadata base uri string for all tokens
     */
    function _baseURI() internal view returns (string memory) {
        return baseTokenUri;
    }
}
