pragma solidity ^0.4.21;


 /* https://github.com/LykkeCity/EthereumApiDotNetCore/blob/master/src/ContractBuilder/contracts/token/SafeMath.sol */
contract SafeMath {
    uint256 constant public MAX_UINT256 =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    function safeAdd(uint256 x, uint256 y) pure internal returns (uint256 z) {
        if (x > MAX_UINT256 - y) revert();
        return x + y;
    }

    function safeSub(uint256 x, uint256 y) pure internal returns (uint256 z) {
        if (x < y) revert();
        return x - y;
    }

    function safeMul(uint256 x, uint256 y) pure internal returns (uint256 z) {
        if (y == 0) return 0;
        if (x > MAX_UINT256 / y) revert();
        return x * y;
    }
}


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

/*
 * Contract that is working with ERC223 tokens
 */
 
 contract ContractReceiver {
     
    struct TKN {
        address sender;
        uint value;
        bytes data;
        bytes4 sig;
    }
    
    
    function tokenFallback(address _from, uint _value, bytes _data) public pure {
      TKN memory tkn;
      tkn.sender = _from;
      tkn.value = _value;
      tkn.data = _data;
      uint32 u = uint32(_data[3]) + (uint32(_data[2]) << 8) + (uint32(_data[1]) << 16) + (uint32(_data[0]) << 24);
      tkn.sig = bytes4(u);
      
      /* tkn variable is analogue of msg variable of Ether transaction
      *  tkn.sender is person who initiated this token transaction   (analogue of msg.sender)
      *  tkn.value the number of tokens that were sent   (analogue of msg.value)
      *  tkn.data is data of token transaction   (analogue of msg.data)
      *  tkn.sig is 4 bytes signature of function
      *  if data of token transaction is a function execution
      */
    }
}

/**
 * ERC223 token by Dexaran
 *
 * https://github.com/Dexaran/ERC223-token-standard
 */
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

contract BurnableERC223 is ERC223 {
    event Burn(address indexed burner, uint256 value);
    
    function burn(uint256 _value) public returns (bool success);
}


/**
 * @title AAQ Token main contract
 */
 
contract AAQToken is BurnableERC223, SafeMath, Ownable {

  mapping(address => uint) balances;
  
  string public name;
  string public symbol;
  uint8 public decimals = 0;
  uint256 public totalSupply;
  uint256 public cost;
  
  // Contract Creation
  function AAQToken() public {
      name = "Animal Acquisition Token";
      symbol = "AAQ";
      totalSupply = 10000000;
      balances[address(this)] = 9000000; // unpurchased
      cost = 1000000000000000; // in wei (.001 ETH)
      balances[owner]=safeSub(totalSupply,balances[address(this)]);
  }
  
  // Fallback function to purchase tokens.
  function () public payable {
      // The owner cannot buy tokens, only deposit ETH
      if (msg.sender!=owner) {
          require(msg.value>0);
          require(balances[address(this)]>0);
          require(msg.value%cost==0); // require a whole amount
          uint256 amountToBuy=msg.value/cost; 
          require(amountToBuy<=balances[address(this)]);
          
          balances[msg.sender] = safeAdd(balances[msg.sender],amountToBuy);
          balances[address(this)] = safeSub(balances[address(this)],amountToBuy);
          bytes memory empty;
          emit Transfer(address(this),msg.sender,amountToBuy,empty);
      }
  }
  
  // Function for receiving AAQ tokens. Only accepts from owner.
  function tokenFallback(address _sender,uint _value,bytes _data) public returns (bool success) {
      require(msg.sender==address(this)); // Require that this is an AAQ token transfer.
      require(_sender==owner); // Only the owner is allowed to put more tokens for sale.
      
      return true;
  }
  
  // Function to access number tokens available for purchase.
  function unpurchased() public view returns (uint256 _unpurchased) {
      return balances[address(this)];
  }
  
  // Function to access cost of the token.
  function cost() public view returns (uint256 _cost) {
      return cost;
  }
  
  // Function to access name of token.
  function name() public view returns (string _name) {
      return name;
  }
  // Function to access symbol of token.
  function symbol() public view returns (string _symbol) {
      return symbol;
  }
  // Function to access decimals of token.
  function decimals() public view returns (uint8 _decimals) {
      return decimals;
  }
  // Function to access total supply of tokens.
  function totalSupply() public view returns (uint256 _totalSupply) {
      return totalSupply;
  }
  
  // Function for owner to retrieve all Wei gained from token sales.
  function withdrawAllProceeds() public onlyOwner returns (bool success){
      require(address(this).balance>0);
      owner.transfer(address(this).balance);
      return true;
  }
  
  // Function for owner to retrieve some Wei gained from token sales.
  function withdrawSomeProceeds(uint256 _value) public onlyOwner returns (bool success) {
      require(_value>0);
      require(_value<=address(this).balance);
      require(address(this).balance>0);
      owner.transfer(_value); // Note that this is in Wei
      return true;
  }
  
  // from BurnableToken zeppelin https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/token/ERC20/BurnableToken.sol
  /**
   * @dev Burns a specific amount of tokens.
   * @param _value The amount of token to be burned.
   */
  function burn(uint256 _value) public returns (bool success){
    require(_value <= balances[msg.sender]);
    // no need to require value <= totalSupply, since that would imply the
    // sender's balance is greater than the totalSupply, which *should* be an assertion failure

    address burner = msg.sender;
    bytes memory empty;
    balances[burner] = safeSub(balances[burner],_value);
    totalSupply = safeSub(totalSupply,_value);
    emit Burn(burner, _value);
    emit Transfer(burner, address(0), _value, empty);
    return true;
  }
  
  // Function that is called when a user or another contract wants to transfer funds.
  function transfer(address _to, uint _value, bytes _data, string _custom_fallback) public returns (bool success) {
      
    if(isContract(_to)) {
        if (balanceOf(msg.sender) < _value) revert();
        balances[msg.sender] = safeSub(balanceOf(msg.sender), _value);
        balances[_to] = safeAdd(balanceOf(_to), _value);
        assert(_to.call.value(0)(bytes4(keccak256(_custom_fallback)), msg.sender, _value, _data));
        emit Transfer(msg.sender, _to, _value, _data);
        return true;
    }
    else {
        return transferToAddress(_to, _value, _data);
    }
}
  

  // Function that is called when a user or another contract wants to transfer funds.
  function transfer(address _to, uint _value, bytes _data) public returns (bool success) {
      
    if(isContract(_to)) {
        return transferToContract(_to, _value, _data);
    }
    else {
        return transferToAddress(_to, _value, _data);
    }
}
  
  // Standard function transfer similar to ERC20 transfer with no _data.
  // Added due to backwards compatibility reasons.
  function transfer(address _to, uint _value) public returns (bool success) {
      
    //standard function transfer similar to ERC20 transfer with no _data
    //added due to backwards compatibility reasons
    bytes memory empty;
    if(isContract(_to)) {
        return transferToContract(_to, _value, empty);
    }
    else {
        return transferToAddress(_to, _value, empty);
    }
}

  //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
  function isContract(address _addr) private view returns (bool is_contract) {
      uint length;
      assembly {
            //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
      }
      return (length>0);
    }

  //function that is called when transaction target is an address
  function transferToAddress(address _to, uint _value, bytes _data) private returns (bool success) {
    if (balanceOf(msg.sender) < _value) revert();
    balances[msg.sender] = safeSub(balanceOf(msg.sender), _value);
    balances[_to] = safeAdd(balanceOf(_to), _value);
    emit Transfer(msg.sender, _to, _value, _data);
    return true;
  }
  
  //function that is called when transaction target is a contract
  function transferToContract(address _to, uint _value, bytes _data) private returns (bool success) {
    if (balanceOf(msg.sender) < _value) revert();
    balances[msg.sender] = safeSub(balanceOf(msg.sender), _value);
    balances[_to] = safeAdd(balanceOf(_to), _value);
    ContractReceiver receiver = ContractReceiver(_to);
    receiver.tokenFallback(msg.sender, _value, _data);
    emit Transfer(msg.sender, _to, _value, _data);
    return true;
}


  function balanceOf(address _owner) public view returns (uint balance) {
    return balances[_owner];
  }
}
