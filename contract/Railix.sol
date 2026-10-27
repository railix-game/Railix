// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/// @title RAILIX — Small runs. Endless rails.
/// 4,444 rail lines on BNB Chain. Each token stores a seed; the open drawing
/// code on railix.xyz redraws any line from it.
contract Railix is ERC721, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 4444;
    uint256 public constant MAX_PER_WALLET = 5;

    uint256 public totalSupply;
    uint256 private _price = 0.0004 ether;
    bool public mintOpen = true;
    string private _baseTokenURI;

    mapping(uint256 => bytes32) public seedOf;
    mapping(address => uint256) public mintedBy;

    event LineLaid(address indexed to, uint256 indexed tokenId, bytes32 seed);

    constructor() ERC721("Railix", "RAILIX") Ownable(msg.sender) {}

    /// Price per line, in wei. Agents read this before calling mint().
    function currentPrice() external view returns (uint256) {
        return _price;
    }

    /// One call, no arguments. Send exactly currentPrice().
    function mint() external payable {
        require(mintOpen, "Mint closed");
        require(msg.sender == tx.origin, "No contracts");
        require(msg.value == _price, "Wrong fare");
        require(totalSupply < MAX_SUPPLY, "Sold out");
        require(mintedBy[msg.sender] < MAX_PER_WALLET, "Wallet limit");

        uint256 id = ++totalSupply;
        mintedBy[msg.sender] += 1;
        bytes32 seed = keccak256(abi.encodePacked(blockhash(block.number - 1), block.prevrandao, msg.sender, id));
        seedOf[id] = seed;
        _safeMint(msg.sender, id);
        emit LineLaid(msg.sender, id, seed);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        _requireOwned(id);
        if (bytes(_baseTokenURI).length > 0) {
            return string.concat(_baseTokenURI, id.toString());
        }
        string memory n = id.toString();
        string memory svg = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
            '<rect width="400" height="400" fill="#F2EEE5"/>',
            '<text x="24" y="40" font-family="monospace" font-size="12" fill="#17161A">RAILIX</text>',
            '<text x="376" y="40" text-anchor="end" font-family="monospace" font-size="12" fill="#17161A">N&#176; ', n, ' / 4444</text>',
            '<circle cx="200" cy="200" r="10" fill="#D8432A"/>',
            '<text x="200" y="370" text-anchor="middle" font-family="monospace" font-size="11" fill="#6E685E">railix.xyz</text></svg>'
        );
        string memory json = string.concat(
            '{"name":"Railix Line #', n,
            '","description":"One rail line on BNB Chain, laid from a seed. Redraw it at railix.xyz.",',
            '"external_url":"https://railix.xyz/",',
            '"attributes":[{"trait_type":"Seed","value":"', uint256(seedOf[id]).toHexString(32), '"}],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    // ── owner ──
    function setPrice(uint256 newPrice) external onlyOwner { _price = newPrice; }
    function setMintOpen(bool open) external onlyOwner { mintOpen = open; }
    function setBaseURI(string calldata uri) external onlyOwner { _baseTokenURI = uri; }
    function withdraw() external onlyOwner {
        (bool ok, ) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }
}
