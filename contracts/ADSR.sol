pragma solidity ^0.4.4;

contract ADSR {
  /*
   * A container for publisher profile metadata.
   */
  struct Publisher {
    address id; // "0xabcde1234...20"
    string domain; // "nytimes.com"
    string name; // "New York Times"
  }

  /*
   * A container for publisher-reseller relationship data.
   * This is the equivalent of a single row in ads.txt
   */
  struct Seller {
    address id; // SellerAccountID
    string domain; // SSP/Exchange Domain
    Relationship rel; // PaymentsType
    string tagId; // TAGID - Trustworthy Accountability Group ID
  }

  /*
   * The various types of relationships
   * (can be extended along with ads.txt spec)
   */
  enum Relationship {
    Direct,
    Reseller
  }

  /*
   * a mapping of publisher addresses to their profile metadata.
   *
   * example
   * "0xabcd" -> Publisher = { address: "0xabcd", string: "nytimes.com", name: "New York Times" }
   *
   * publishers["0xabcd"]
   */
  mapping (address => Publisher) public publishers;

  /* a mapping of domains to publisher ids;
   *
   * example
   * "nytimes.com" -> "0xabcd"
   */
  mapping (bytes32 => address) public domainPublisher;

   /*
    * a mapping of publisher addresses to
    * their authorized sellers and their data.
    *
    * example
    * sellers[publisherAddress][resellerAddress] -> Seller
    *
    * Publishers ads.txt
    * Row 1 - reseller1.com, 1293sdf, direct, tagId
    * Row 2 - reseller2.com, 1293sdf, direct, tagId
    */
  mapping (address => mapping (address => Seller)) public sellers;

  /*
   * The owner of this contract.
   */
  address owner;

  /*
   * Events, when triggered, record logs in the blockchain.
   * Clients can listen on specific events to get fresh data.
   */
  event _PublisherRegistered(address indexed id);
  event _PublisherDeregistered(address indexed id);
  event _SellerAdded(address indexed publisherId, address indexed sellerId);
  event _SellerRemoved(address indexed publisherId, address indexed sellerId);

  /*
   * A function modifier which limits execution
   * of the function to the "owner".
   */
  modifier only_owner () {
    if (msg.sender != owner) {
      revert();
    }

    // continue with code execution
    _;
  }

  /*
   * The constructor function, called only
   * once when this contract is initially deployed.
   */
  function ADSR() {
    owner = msg.sender;
  }

  /*
   * Only the owner of the contract can register new publishers.
   */
  function registerPublisher(address id, string domain, string name) only_owner external {
    publishers[id] = Publisher(id, domain, name);
    domainPublisher[sha3(domain)] = id;
    _PublisherRegistered(id);
  }

  /*
   * The owner can also deregister existing publishers.
   */
  function deregisterPublisher(address id) only_owner external {
    string storage domain = publishers[id].domain;
    delete domainPublisher[sha3(domain)];
    delete publishers[id];
    _PublisherDeregistered(id);
  }

  /*
   * Once registered, publishers are free to add certified sellers.
   */
  function addSeller(address id, string domain, Relationship rel, string tagId) external {
    address sender = msg.sender;

    /*
     * First, check that this ethereum address
     * is a registered publisher.

     * If their "id" has been set, then they have
     * been registered by the owner.

     * Note - in Ethereum, mapping values are initiated
     * to all 0s if not set.
     */
    if (publishers[sender].id != 0) {
      sellers[sender][id] = Seller(id, domain, rel, tagId);
      _SellerAdded(sender, id);
    }
  }

  /*
   * Publishers can also remove sellers at will.
   */
  function removeSeller(address id) external {
    address sender = msg.sender;

    /*
     * Check that this ethereum address is a registered publisher.
     */
    if (publishers[sender].id != 0) {
      delete sellers[sender][id];
      _SellerRemoved(sender, id);
    }
  }

  /*
   * Return seller struct for publisher id
   */
  function getSellerForPublisher(address id, address sellerId) external constant returns (address, string, uint, string) {
    Seller storage seller = sellers[id][sellerId];

    // TODO: better way
    uint rel = 0;

    if (seller.rel == Relationship.Reseller) {
      rel = 1;
    }

    return (seller.id, seller.domain, rel, seller.tagId);
  }

  /*
   * Return seller struct for publisher domain
   */
  function getSellerForPublisherDomain(string domain, address sellerId) external constant returns (address, string, uint, string) {
    address publisher = domainPublisher[sha3(domain)];

    Seller storage seller = sellers[publisher][sellerId];

    // TODO: better way
    uint rel = 0;

    if (seller.rel == Relationship.Reseller) {
      rel = 1;
    }

    return (seller.id, seller.domain, rel, seller.tagId);
  }
}
