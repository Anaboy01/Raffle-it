// SPDX-License-Identifier: MIT
pragma solidity >=0.8.27;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract RealToken is ERC721 {
    string constant baseURI = "https://tan-electrical-capybara-861.mypinata.cloud/ipfs/QmaknQPxf89JbhUYq15gVhYSM8E9uxQJiwzYoD9PBJGG4Y";
    address public raffleContract;

    constructor() ERC721("RealToken", "RTK") {
        raffleContract = msg.sender;
    }

    modifier onlyRaffle() {
        require(msg.sender == raffleContract, "Only raffle contract can mint");
        _;
    }

    function mint(address to, uint256 tokenId) external onlyRaffle {
        _mint(to, tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked(baseURI, "/", uint2str(tokenId)));
    }

    // Utility function to convert uint to string for token URI
    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}