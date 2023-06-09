pragma ton-solidity =0.58.1;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

interface IAuction {
	struct Bid {
		address addr;
		uint128 value;
	}

	event AuctionCreated(
		address marketRoot,
		address collection,
		address owner,
		address addrNft,
		address oldManager,
		uint128 price,
		uint256 auctionDuration
	);

	event BidPlaced(address buyerAddress, uint128 value);
	event BidDeclined(address buyerAddress, uint128 value);
	event AuctionFinished(
		address owner,
		address oldManager,
		address newOwner,
		uint128 price,
		uint128 startPrice
	);
	event EndTimeChanged(uint256 oldEndTime, uint256 newEndTime);
	event AuctionExpired();

	function finishAuction() external;

	function getAuctionInfo()
		external
		view
		responsible
		returns (
			uint8 bidDelta,
			uint256 extraSecondsAmount,
			uint256 auctionDuration,
			uint256 auctionEndTime,
			uint128 nexBidValue,
			uint128 currentBidValue,
			address currentBidAddress
		);
}
