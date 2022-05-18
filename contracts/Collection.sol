// contracts/Collection.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.7/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract Collection is 
    ERC721,
    Ownable,
    Pausable
  {
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
      uint id;
      bytes32 titleId;
      address payable owner;
    }

    // Token base URI string 
    string internal baseTokenUri;

    // Title search api base URI string 
    string internal titleSearchUri;
        
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
    event DeedMinted(
       address indexed receiver,
       uint256 deedId
    );

     /**
      * @dev Event for batch deed mint logging
      * @param receiver who got the deeds
      * @param deedIds ids of the deeds purchased
     */
    event DeedsMinted(
       address indexed receiver,
       uint256[] deedIds
    );

    //=============================== INITIALIZATION ===================================//

    constructor() ERC721("NomadHouse", "NMH") {
      setPublicChainlinkToken();
      titleSearchUri = "https://bafybeihuftdtf5rjkep52k5afrydtlo4mvznafhtmrsqaunaninykew3qe.ipfs.dweb.link/";
      oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8; // Change this to our oracle contract address
      jobId = "d5270d1c311941d0b08bead21fea7747"; // Change this to the actual job id we use once it's built out
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
    function setTokenURI(string memory newURI) external whenNotPaused onlyOwner {
      baseTokenUri = newURI;
    }

    /**
      * @dev sets title search uri for title verification
    */
    function setTitleSearchURI(string memory newURI) external whenNotPaused onlyOwner {
      titleSearchUri = newURI;
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
    function deauthorizeWallet(address _wallet) external whenNotPaused onlyOwner {
      require(_wallet != address(0), "Wallet address cannot empty");
      _verifiedAddresses[_wallet] = false;
    }

    //============================= MODIFIERS ===============================//

    modifier onlyVerifiedAddress(address _address) {
      require(_verifiedAddresses[_address] == true);
      _;
    }

    //============================= PUBLIC / EXTERNAL FUNCTIONS ===============================//

    //================== STATE ALTERING FUNCTIONS ==================//

     /**
      * @dev Makes an API call to our in house title search API which will have information on the title
      * and it's whether it's been marked as verified.
      * @param _titleId The primary identifier for performing title searches
    */
    function verifyTitleOwnership(bytes32 _titleId) public returns(bytes32 requestId) {
      require(titleSearchUri.length != 0, 'Cannot execute ChainLink request: Title Search URI is empty');
      Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
      // Set the URL to perform the GET request on
      request.add("get", titleSearchURI);
      
      // Set the path to find the desired data in the API response, where the response format is:
      // {"TITLEID":
      //   {
      //    "VERIFIED": true,
      //   }
      //  }
      
      request.add("titleId", _titleId); // Chainlink nodes 1.0.0 and later support this format
      
      // Sends the request
      return sendChainlinkRequestTo(oracle, request, fee);
    }

    /**
     * Receive the response in the form of a boolean
     */ 
    function fulfillTitleOwnership(bytes32 _requestId, bytes32 titleId, bool _verified) public recordChainlinkFullfillment(_requestId) {
        _verifiedTitles[titleId] = _verified;
    }

    function withdrawLink() public onlyOwner {
      LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
      require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }


    function mintFractionalDeed(
      address _address,
      bytes32 titleId,
      bytes memory data
    ) external whenNotPaused onlyVerifiedAddress(_address) {
      uint256 currentDeedId = _deedIds.current();
      require(deeds[currentDeedId] == 0, 'Deed has already been minted');

      verifyTitleOwnership(titleId);
      require(_verifiedTitles[titleId] == true, 'Title ownership has not been verified');

      _safeMint(_address, currentDeedId);
      deeds[currentDeedId] = FractionalDeed(
        currentDeedId,
        _address,
        _currentTitleVerified
      );
      _owners[currentDeedId] = _address;
      _deedIds.increment();

      emit DeedsMinted(_address, currentDeedId);
    }


    /**
      * @dev Deed batch minting functionality
      * @param _address the _address to mint the Deeds to
      * @param amount the amount of deeds to mint
      * @param titleId the 
      * @param data the 
      * @return uri string of the deedId metadata
     */
    function batchMintFractionalDeeds(
      address _address,
      uint memory amount,
      bytes32 titleId,
      bytes memory data
    ) external whenNotPaused onlyVerifiedAddress(_address) {
      uint[] memory tempDeedIds;
      uint256 currentDeedId = _deedIds.current();
      tempDeedIds.push(currentDeedId);

      // Creates an array of deed ids in incremental order
      // This is used later to mint each id through a loop
      for (uint i = 1; i < amount; i++) {
        tempDeedIds.push(currentDeedId + i);
      }

      verifyTitleOwnership(titleId);
      require(_verifiedTitles[titleId] == true, 'Title ownership has not been verified');
      
      // Minting deeds through a loop
      for (uint i = 0; i < amount; i++) {
        require(_deedIds[tempDeedIds[i]] == 0, 'Deed has already been minted');

        _safeMint(_address, tempDeedIds[i]);

        // Returning array to default values (saves gas)
        delete tempDeedIds;

        deeds[deedId] = FractionalDeed(
          currentDeedId,
          _address,
          _currentTitleVerified
        );
        _owners[deedId] = _address;

        _deedIds.increment();
      }

      emit DeedsMinted(_address, tempDeedIds);
    }


  //================== NON-MODIFYING FUNCTIONS ==================//

  /**
    * @dev returns address that is currently the owner of a specific deed Id
    * @param deedId deed token id to check for
  */
  function ownerOf(uint256 deedId) public view virtual override returns (address) {
    require(_exists(deedId), "Deed does not exist");

    return  _owners[deedId];
  }

  /**
    * @dev returns true or false if the deed exists in the contract
    * @param deedId deed token id to check for
  */
  function exists(uint256 deedId) public view virtual returns (bool) {
    return  _exists(deedId);
  }

  /**
    * @dev returns the metadata uri for a given deedId
    * @param deedId the deedId id to return metadata for
    * @return uri string of the deedId metadata
  */
  function uri(uint256 deedId) public view returns (string memory) {
    require(_exists(deedId), "Deed does not exist");
    return string(abi.encodePacked(_baseURI(), Strings.toString(deedId), ".json"));
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
  ) public virtual override onlyVerifiedAddress(_to) {
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
  ) public virtual onlyVerifiedAddress(_to) {
    for (uint i=0; i < deedIds.length; i++) {
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