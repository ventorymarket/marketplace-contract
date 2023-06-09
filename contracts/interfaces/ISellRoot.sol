pragma ton-solidity =0.58.1;

interface ISellRoot {
	struct MarketOffer {
		address collection;
		address owner;
		address addrNft;
		address oldManager;
		address offer;
		uint128 price;
	}

	event SellDeployed(MarketOffer offerInfo);
	event SellConfirmed(
		address offer,
		address addrNft,
		address owner,
		address oldManager,
		address newOwner,
		uint128 price
	);
	event SellCancelled(
		address offer,
		address addrNft,
		address owner,
		address oldManager,
		uint128 price
	);
	event SellRejected(address addrNft, address owner, address oldManager);

	function onOfferFinish(
		uint256 id,
		address owner,
		address data,
		address oldManager,
		address newOwner,
		uint128 price
	) external;

	function onOfferCancel(
		uint256 id,
		address owner,
		address data,
		address oldManager,
		address sendGasTo,
		uint128 price
	) external;

	function generatePayload(uint128 price)
		external
		view
		responsible
		returns (
			TvmCell payload,
			uint128 totalDeploymentValue,
			uint128 totalValueWithNftGas
		);
}
