pragma solidity ^0.4.21;

// Thanks to the guys at cryptozombies.io for the tutorial.

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


// ERC223 Interface
contract ERC223 {
  uint public totalSupply;
  function balanceOf(address who) public view returns (uint);
  
  function name() public view returns (string _name);
  function symbol() public view returns (string _symbol);
  function decimals() public view returns (uint8 _decimals);
  function totalSupply() public view returns (uint256 _supply);

  function transfer(address to, uint value) public returns (bool ok);
  function transfer(address to, uint value, bytes data) public returns (bool ok);
  function transfer(address to, uint value, bytes data, string custom_fallback) public returns (bool ok);
  
  event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}

// Burnable ERC223 Interface
contract BurnableERC223 is ERC223 {
    event Burn(address indexed burner, uint256 value);
    
    function burn(uint256 _value) public returns (bool success);
}

// ERC721 Interface
contract ERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);

    // required
    function balanceOf(address _owner) public view returns (uint256 _balance);
    function ownerOf(uint256 _tokenId) public view returns (address _owner);
    function transfer(address _to, uint256 _tokenId) public;
    function approve(address _to, uint256 _tokenId) public;
    function takeOwnership(uint256 _tokenId) public;
  
    // optional but recommended
    function name() public view returns (string _name);
    function symbol() public view returns (string _symbol);
    function totalSupply() public view returns (uint256 _totalSupply);
    function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint tokenId);
}

// Contract responsable for defining and creating animals.
contract AnimalFactory is Ownable {
    
    // prevent overflows
    using SafeMath for uint256;

    event NewAnimal(uint _animalId, string _name);

    address AAQAddress; // Address of the AAQ Token contract
    
    uint animalCount; // To store total amount of animals. needed for burning.

    string[] public animals;

    mapping (uint => address) animalToOwner;
    mapping (address => uint) ownerAnimalCount;
    mapping (address => mapping (uint => uint)) ownedTokenIds; // To allow checking an address's tokens
    mapping (address => bool) AAQBanked; // To check if a user has deposited a token
    
    // Constructor function
    function AnimalFactory() public {
        // Create NULL animal so tokenId 0 can be handled as an error.
        _createAnimal("NULL",address(this));
    }
    
    // Function to view the address of AAQ Tokens.
    function getAAQAddress() public view returns (address _AAQAddress) {
        return AAQAddress;
    }
    
    // Function for the owner to update the address of AAQ Tokens
    function setAAQAddress(address _newAddress) public onlyOwner returns (bool _success) {
        require(_newAddress!=address(0));
        AAQAddress = _newAddress;
        return true;
    }
    
    // Function to check if an address has a banked AAQ Token.
    function hasTokenBanked(address _owner) public view returns (bool _hasTokenBanked) {
        return AAQBanked[_owner];
    }
    
    // Function for receiving AAQ tokens.
    function tokenFallback(address _sender,uint _value,bytes _data) public returns (bool _success) {
        require(msg.sender==AAQAddress); // Require that this is an AAQ token transfer.
        require(_value==1); // Only one token may be sent
        if ((_sender==owner) && (_data.length>0)) {
            // Allows owner to transfer tokens without banking to allow for
            // recovery from a state where a user has a banked token but
            // there are no tokens left to burn.
            return true;
        }
        require(AAQBanked[_sender]==false); // Everyone is only allowed to have one token banked.
        AAQBanked[_sender]=true;
        return true;
    }
    
    // Function for owner to manually unbank user's tokens. 
    function unbank(address _addressToUnbank) public onlyOwner returns (bool _success) {
        require(AAQBanked[_addressToUnbank]);
        require(AAQAddress!=address(0));
        AAQBanked[_addressToUnbank]=false;
        BurnableERC223(AAQAddress).transfer(_addressToUnbank,1); // Transfer the banked AAQ token back
        return true;
    }
    
    // Function for users to create new animals.
    function mintAnimal(string _seed) public returns (bool _success) {
        // Most of the string validation is done in the app.
        require(bytes(_seed).length>4); // must be at least 5 characters
        require(AAQBanked[msg.sender]);
        AAQBanked[msg.sender]=false;
        BurnableERC223(AAQAddress).burn(1); // burn 1 AAQ token
        _createAnimal(_seed,msg.sender);
        return true;
    }
    
    // Internal function for the actual creation of an animal.
    function _createAnimal(string _name,address _owner) private returns (bool _success) {
        uint id = animals.push(_name) - 1;
        ownedTokenIds[_owner][ownerAnimalCount[_owner]] = id;
        animalToOwner[id] = _owner;
        ownerAnimalCount[_owner]=ownerAnimalCount[_owner].add(1);
        animalCount=animalCount.add(1);
        emit NewAnimal(id, _name);
        return true;
    }

}

// Contract to handle animal ownership.
contract AnimalOwnership is AnimalFactory, ERC721 {
    
    mapping (uint => address) animalApprovals; // to keep track of which address can take ownership
    
    // Modifier to only allow the owner of the target ANI Token to do something.
    modifier onlyOwnerOf(uint _animalId){
        require(msg.sender == animalToOwner[_animalId]);
        _; // continue with modified function's code
    }
    
    // Function to get an owned token's id by referencing the index of the user's owned tokens.
    // ex: user has 5 tokens, tokenOfOwnerByIndex(owner,3) will give the id of the 4th token.
    // note: returns 0 if reverted, which points to a null token via AnimalFactory
    function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint _tokenId) {
        require(_index<balanceOf(_owner)); // revert if outside range
        return ownedTokenIds[_owner][_index];
    }
    
    // Function to get the number of tokens an address owns.
    function balanceOf(address _owner) public view returns (uint256 _balance) {
        return ownerAnimalCount[_owner];
    }
    
    // Function to get the info string of a token by its id.
    function infoOf(uint256 _tokenId) public view returns (string _target) {
        return animals[_tokenId];
    }
    
    // Function to get the address that owns a particular token id.
    function ownerOf(uint256 _tokenId) public view returns (address _owner) {
        return animalToOwner[_tokenId];
    }
    
    // Private function for the actual transfer of a token
    function _transfer(address _from, address _to, uint256 _tokenId) private {
        require(animalToOwner[_tokenId]==_from); // function will bork up if this isn't true
        // first, find tokenId
        for (uint i=0;i<ownerAnimalCount[_from];i++){
            uint thisId = ownedTokenIds[_from][i];
            if (thisId==_tokenId){
                // move every next item back one index
                for (uint j=i;j<ownerAnimalCount[_from]-1;j++){
                    ownedTokenIds[_from][j]=ownedTokenIds[_from][j+1];
                }
                delete ownedTokenIds[_from][ownerAnimalCount[_from]]; // delete the last (duplicate) item
                break; // all done looking for _tokenId
            }
        }
        // This code is okay because of the require statement above;
        // it would be a problem if the token was not found in the loop above.
        ownedTokenIds[_to][ownerAnimalCount[_to]]=_tokenId;
        ownerAnimalCount[_to]=ownerAnimalCount[_to].add(1);
        ownerAnimalCount[_from]=ownerAnimalCount[_from].sub(1);
        animalToOwner[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }
    
    // Function for users to transfer their tokens.
    function transfer(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) {
        require(_to!=address(0)); // No accidental burning
        require(_to!=address(this)); // No transferring to this contract
        _transfer(msg.sender, _to, _tokenId);
    }
    
    // Function for users to approve a token id for takeOwnership().
    function approve(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) {
        animalApprovals[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
    }
    
    // Function for a user to claim an approved token.
    function takeOwnership(uint256 _tokenId) public {
        require(animalApprovals[_tokenId] == msg.sender);
        _transfer(ownerOf(_tokenId), msg.sender, _tokenId);
    }

}


// ANI Token main contract.
contract ANIToken is AnimalOwnership {
    
    string public name;
    string public symbol;
    
    // Contract creation.
    function ANIToken() public {
        name = "Animal Token";
        symbol = "ANI";
    }
    
    // Function to get the name of the token.
    function name() public view returns (string _name) {
        return name;
    }
    
    // Function to get the symbol of the token.
    function symbol() public view returns (string _symbol) {
        return symbol;
    }
    
    // Function to get the number of animals that have been created.
    function totalSupply() public view returns (uint256 _totalSupply){
        return animalCount; // from AnimalFactory
    }
}
