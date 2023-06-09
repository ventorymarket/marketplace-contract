pragma ton-solidity =0.58.1;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

interface IOffer {
	event OfferIsActivated();
	event OfferIsBounced();

	function setRoyalty(mapping(address => uint8) royalty) external;

	function getOfferInfo()
		external
		view
		responsible
		returns (
			uint256 id,
			address nft,
			address rootAddress,
			address owner,
			address oldManager,
			address sendGasTo,
			uint128 price,
			bool isActive
		);

	function getFeesInfo()
		external
		view
		responsible
		returns (
			uint128 marketFee,
			uint8 marketFeeDecimals,
			uint128 leftOnOfferAfterFinish,
			uint128 nftTransferFee,
			uint128 methodsCallsFee
		);

	function getFeesValues()
		external
		view
		responsible
		returns (
			uint128 totalFeeValue,
			mapping(address => uint128) royalties,
			uint128 marketFeeValue
		);
}
