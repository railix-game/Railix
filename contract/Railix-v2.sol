// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title RAILIX
/// @notice ERC-721 on BNB Chain (chain 56). 4,444 rail lines.
/// Mint is FREE as a token price in both phases; what the minter sends
/// with mint() is a creator fee forwarded to the owner wallet:
///   mints 1-200:   exactly 0.00015 BNB (150,000,000,000,000 wei)
///   mints 201-4444: exactly 0.00025 BNB (250,000,000,000,000 wei)
/// Network gas on BNB Chain is charged separately by the network.
/// Mint: one call, no arguments. Calls from smart contracts are rejected
/// (msg.sender must equal tx.origin). Max 5 lines per wallet in total.
/// No Binance Agent ID gate in this version: any personal wallet can mint.
/// The block sets the seed; seedOf(tokenId) stores it on-chain.
/// Owner can open/close mint, update baseURI, and withdraw any balance.
/// Initial baseURI is a pattern and MUST be updated by the owner after
/// the real metadata location is known.
contract Railix is ERC721, Ownable, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 4444;
    uint256 public constant EARLY_LIMIT = 200;
    uint256 public constant FEE_EARLY = 0.00015 ether;
    uint256 public constant FEE_LATE = 0.00025 ether;
    uint256 public constant MAX_PER_WALLET = 5;

    uint256 public totalMinted;
    bool public mintOpen = true;
    string private _baseTokenURI = "ipfs://RAILIX/";

    mapping(uint256 => uint256) private _seeds;
    mapping(address => uint256) public mintedByWallet;

    error MintClosed();
    error ContractCaller();
    error SoldOut();
    error OverLimit();
    error WrongFee();

    constructor() ERC721("Railix", "RAILIX") {}

    /// @notice Creator fee for the next mint, based on how many are minted.
    function currentPrice() public view returns (uint256) {
        return totalMinted < EARLY_LIMIT ? FEE_EARLY : FEE_LATE;
    }

    /// @notice Alias kept so agents and sites reading currentFee() get the same tier fee.
    function currentFee() public view returns (uint256) {
        return currentPrice();
    }

    function seedOf(uint256 tokenId) public view returns (uint256) {
        _requireMinted(tokenId);
        return _seeds[tokenId];
    }

    function mint() external payable nonReentrant {
        if (!mintOpen) revert MintClosed();
        if (msg.sender != tx.origin) revert ContractCaller();
        if (totalMinted >= MAX_SUPPLY) revert SoldOut();
        if (mintedByWallet[msg.sender] >= MAX_PER_WALLET) revert OverLimit();
        uint256 fee = currentPrice();
        if (msg.value != fee) revert WrongFee();

        totalMinted += 1;
        uint256 tokenId = totalMinted;
        mintedByWallet[msg.sender] += 1;
        _seeds[tokenId] = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, tokenId)
            )
        );
        _safeMint(msg.sender, tokenId);
        payable(owner()).transfer(msg.value);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        return string(abi.encodePacked(_baseTokenURI, _toString(tokenId), ".json"));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
    }

    function withdraw() external onlyOwner nonReentrant {
        (bool ok, ) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }
}
