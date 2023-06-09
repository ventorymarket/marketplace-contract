pragma ton-solidity =0.58.1;

interface IOffersRoot {
	function getOwner() external view responsible returns (uint256 ownerPubkey);

	function getWithdrawalAddress()
		external
		view
		responsible
		returns (address withdrawalAddress);

	function getFeesInfo()
		external
		view
		responsible
		returns (
			uint128 deploymentFee,
			uint128 creationPrice,
			uint128 totalDeploymentPrice,
			uint128 minimalGasAmount,
			uint128 nftGasAmount,
			uint128 leftOnOfferAfterFinish,
			uint128 nftTransferFee,
			uint128 methodsCallsFee,
			uint8 marketFee,
			uint8 marketFeeDecimals
		);

	function getMarketStatus()
		external
		view
		responsible
		returns (bool marketIsActive);

	function offerCode() external view responsible returns (TvmCell code);

	function offerCodeHash()
		external
		view
		responsible
		returns (uint256 codeHash);

	function offerAddress(uint256 id)
		external
		view
		responsible
		returns (address offer);
}
