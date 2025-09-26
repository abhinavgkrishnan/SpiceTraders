// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract Tokens is ERC1155, Ownable, ERC1155Pausable, ERC1155Burnable, ERC1155Supply {
    enum ResourceType {
        METAL,       // Industrial materials (formerly IRON)
        SAPHO_JUICE, // Mentat computational enhancer (formerly COPPER/TECH)
        WATER,       // Life essence
        SPICE        // The only fuel source that powers everything (formerly FUEL)
    }

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public authorizedMinters;

    event AuthorizedMinterSet(address indexed minter, bool authorized);
    event TokenURISet(uint256 indexed tokenId, string uri);

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized to mint");
        _;
    }

    constructor(address initialOwner, string memory baseURI)
        ERC1155(baseURI)
        Ownable(initialOwner)
    {
        authorizedMinters[initialOwner] = true;
    }

    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterSet(minter, authorized);
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyAuthorizedMinter {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyAuthorizedMinter {
        _mintBatch(to, ids, amounts, data);
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyOwner {
        _tokenURIs[tokenId] = tokenURI;
        emit TokenURISet(tokenId, tokenURI);
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setURI(baseURI);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }
        return super.uri(tokenId);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}