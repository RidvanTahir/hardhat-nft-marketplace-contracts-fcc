// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

///////////////////////////////
///          Errors         ///
///////////////////////////////

error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotApprovedFormarketPlace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner(address nftAddress, uint256 tokenId);
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace__NoProceeds();
error NftMarketplace__TransferFailed();

contract NftMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 price;
        address seller;
    }

    // NFT contract address => NFT token ID => Listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;

    // Seller address => amount earned
    mapping(address => uint256) private s_proceeds;

    ///////////////////////////////
    ///          Events         ///
    ///////////////////////////////

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemBought(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemCancelled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    ///////////////////////////////
    ///         Modifiers       ///
    ///////////////////////////////

    modifier NotListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
        _;
    }

    modifier IsListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) revert NftMarketplace__NotListed(nftAddress, tokenId);
        _;
    }

    modifier IsOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (owner != spender) revert NftMarketplace__NotOwner(nftAddress, tokenId);
        _;
    }

    ///////////////////////////////
    ///     Main functions      ///
    ///////////////////////////////

    /// @notice Method for listing your nft on the market place
    /// @dev Explain to a developer any extra details
    /// @param nftAddress: nft contract address
    /// @param tokenId: Token id of the Nft
    /// @param price: price of the listed NFT
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    ) external payable NotListed(nftAddress, tokenId) IsOwner(nftAddress, tokenId, msg.sender) {
        if (price <= 0) revert NftMarketplace__PriceMustBeAboveZero();

        IERC721 nft = IERC721(nftAddress);

        if (nft.getApproved(tokenId) != address(this))
            revert NftMarketplace__NotApprovedFormarketPlace();

        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);

        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    function buyItem(
        address nftAddress,
        uint256 tokenId
    ) external payable nonReentrant IsListed(nftAddress, tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];

        if (msg.value < listing.price)
            revert NftMarketplace__PriceNotMet(nftAddress, tokenId, listing.price);

        s_proceeds[listing.seller] = s_proceeds[listing.seller] + msg.value;

        delete (s_listings[nftAddress][tokenId]);

        IERC721(nftAddress).safeTransferFrom(listing.seller, msg.sender, tokenId);

        emit ItemBought(msg.sender, nftAddress, tokenId, listing.price);
    }

    function cancelItem(
        address nftAddress,
        uint256 tokenId
    ) external IsOwner(nftAddress, tokenId, msg.sender) IsListed(nftAddress, tokenId) {
        delete (s_listings[nftAddress][tokenId]);
        emit ItemCancelled(msg.sender, nftAddress, tokenId);
    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    ) external payable IsOwner(nftAddress, tokenId, msg.sender) {
        if (newPrice <= 0) revert NftMarketplace__PriceMustBeAboveZero();
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    function withdrawProceeds() external {
        uint256 proceeds = s_proceeds[msg.sender];

        if (proceeds <= 0) revert NftMarketplace__NoProceeds();

        s_proceeds[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: proceeds}("");

        if (!success) revert NftMarketplace__TransferFailed();
    }

    ///////////////////////////////
    ///         Getters         ///
    ///////////////////////////////

    function getListing(
        address nftAddress,
        uint256 tokenId
    ) external view returns (Listing memory) {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}

// 1. `listItem`: List NFTs on the marketplace
// 2. `buyItem`: Buy the NFTs
// 3. `cancelItem`: Cancel a listing
// 4. `updateListing`: Update price
// 5. `withdrawProceeds`: Withdraw payments for mu bought NFTs
