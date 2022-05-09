// contracts/Collection.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.7/ChainlinkClient.sol";

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
    
    // Params for Chainlink Request
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    // Internal Struct for tracking Fractional Deeds
    struct FractionalDeed {
      uint id;
      bytes32 titleId;
      address payable owner;
      bool verified;
    }

    // Contract base URI string
    string internal globalTokenURI;
        
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

    function setURI(string memory newURI) external onlyOwner {
      globalTokenURI = newURI;
    }

    //============================= PUBLIC / EXTERNAL FUNCTIONS ===============================//

    //================== STATE ALTERING FUNCTIONS ==================//



    function verifyTitleOwnership(bytes32 titleId) public returns(bytes32 requestId) {
      Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
      // Set the URL to perform the GET request on
      request.add("get", "https://some-title-search-api.com/");
      
      // Set the path to find the desired data in the API response, where the response format is:
      // {"TITLEID":
      //   {
      //    "OWNER": "JOHN DOE"
      //    "VERIFIED": true,
      //   }
      //  }
      
      request.add("path", string(abi.encodePacked(titleId, ",OWNER,VERIFIED"))); // Chainlink nodes 1.0.0 and later support this format
      
      // Sends the request
      return sendChainlinkRequestTo(oracle, request, fee);
    }

    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _verified) public recordChainlinkFulfillment(_requestId) {
        verified = _verified;
    }


    function mintFractionalDeed(
      address account,
      bytes32 titleId,
      bytes memory data
    ) external whenNotPaused {
      uint256 currentDeedId = _deedIds.current();
      require(deeds[currentDeedId] == 0, 'Deed has already been minted');

      bool titleVerified = verifyTitleOwnership(titleId);
      require(titleVerified == true, 'Title ownership has not been verified');

      _safeMint(account, currentDeedId);
      deeds[currentDeedId] = FractionalDeed(
        currentDeedId,
        account,
        isVerified
      );
      _owners[currentDeedId] = account;
      _deedIds.increment();

      emit DeedsMinted(account, currentDeedId);
    }


    /**
      * @dev Deed batch minting functionality
      * @param account the account to mint the Deeds to
      * @param amount the amount of deeds to mint
      * @param titleId the 
      * @param data the 
      * @return uri string of the deedId metadata
     */
    function batchMintFractionalDeeds(
      address account,
      uint memory amount,
      bytes32 titleId,
      bytes memory data
    ) external whenNotPaused {
      uint[] tempDeedIds;
      uint256 currentDeedId = _deedIds.current();
      tempDeedIds.push(currentDeedId);

      // Creates an array of deed ids in incremental order
      // This is used later to mint each id through a loop
      for (uint i = 1; i < amount; i++) {
        tempDeedIds.push(currentDeedId + i);
      }

      bool titleVerified = verifyTitleOwnership(titleId);
      require(titleVerified == true, 'Title ownership has not been verified');
      
      // Minting deeds through a loop
      for (uint i = 0; i < amount; i++) {
        require(_deedIds[tempDeedIds[i]] == 0, 'Deed has already been minted');

        _safeMint(account, tempDeedIds[i]);

        deeds[deedId] = FractionalDeed(
          currentDeedId,
          account,
          titleVerified
        );
        _owners[deedId] = account;

        _deedIds.increment();
      }

      // Returning array to default values (saves gas)
      delete tempDeedIds;

      emit DeedsMinted(account, tempDeedIds);
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

  //============================== PRIVATE / INTERNAL FUNCTIONS  ==============================//

  //================== NON-MODIFYING FUNCTIONS ==================//

  /**
    * @dev returns the metadata base uri string for all tokens
  */
  function _baseURI() internal view returns (string memory) {
    return globalTokenURI;
  }
  
}