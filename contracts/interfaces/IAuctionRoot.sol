pragma ton-solidity =0.58.1;

interface IAuctionRoot {
	struct MarketOffer {
		address collection;
		address owner;
		address addrNft;
		address oldManager;
		address offer;
		uint128 price;
		uint256 auctionDuration;
	}

	event AuctionDeployed(MarketOffer offerInfo);
	event AuctionFinished(
		address offer,
		address owner,
		address addrNft,
		address oldManager,
		address newOwner,
		uint128 price,
		uint128 startPrice
	);
	event AuctionExpired(
		address offer,
		address owner,
		address addrNft,
		address oldManager,
		uint128 startPrice
	);
	event AuctionRejected(address addrNft, address owner, address oldManager);

	function onOfferFinish(
		uint256 id,
		address owner,
		address data,
		address oldManager,
		address newOwner,
		uint128 price,
		uint128 startPrice
	) external;

	function onOfferExpiration(
		uint256 id,
		address owner,
		address data,
		address oldManager,
		address sendGasTo,
		uint128 startPrice
	) external;

	function generatePayload(
		uint128 price,
		uint256 auctionDuration
	)
		external
		view
		responsible
		returns (
			TvmCell payload,
			uint128 totalDeploymentValue,
			uint128 totalValueWithNftGas
		);

	/// @return bidDelta
	function getAuctionSettings()
		external
		view
		responsible
		returns (uint8 bidDelta, uint256 extraSecondsAmount);
}
