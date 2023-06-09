pragma ton-solidity =0.58.1;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "@itgold/everscale-tip/contracts/TIP6/TIP6.sol";
import "../errors/OffersBaseErrors.sol";
import "@grandbazar-io/everscale-tip4-contracts/contracts/interfaces/IRoyalty.sol";
import "@itgold/everscale-tip/contracts/TIP4_1/interfaces/ITIP4_1NFT.sol";
import "@grandbazar-io/everscale-tip4-contracts/contracts/libraries/BaseErrors.sol";
import "../interfaces/IOffer.sol";

abstract contract Offer is IRoyalty, IOffer, TIP6 {
	address static _marketRootAddr;
	uint256 static _id;

	uint128 _price;
	address _addrNft;

	address _tokenRootAddr;
	address _owner;
	address _oldManager;
	address _sendGasTo;

	uint128 _leftOnOfferAfterFinish;
	uint128 _nftTransferFee;
	uint128 _methodsCallsFee;

	uint128 _marketFee;
	uint8 _marketFeeDecimals;

	bool _isActive;

	mapping(address => uint8) _royalty;

	/// @param tokenRootAddr NFT Collection address
	/// @param addrOwner Address of NFT owner
	/// @param addrNft Address of NFT
	/// @param oldManager Address of NFT manager that called changeManager method
	/// @param sendGasTo Address that will get all the change after offer finish, cancelation or expiration
	/// @param price Amount of evers
	/// @param marketFee Market fee percent
	/// @param leftOnOfferAfterFinish Amount of evers to be left on offers after finish to cover storage fee
	/// @param nftTransferFee Amount of evers to be sent with NFT's transfer method call
	/// @param methodsCallsFee Amount of evers to be sent with various contracts methods calls
	/// @param marketFeeDecimals Market Fee percent decimal
	constructor(
		address tokenRootAddr,
		address addrOwner,
		address addrNft,
		address oldManager,
		address sendGasTo,
		uint128 price,
		uint128 marketFee,
		uint128 leftOnOfferAfterFinish,
		uint128 nftTransferFee,
		uint128 methodsCallsFee,
		uint8 marketFeeDecimals
	) public {
		require(
			msg.sender == _marketRootAddr,
			OffersBaseErrors.message_sender_is_not_my_root
		);
		tvm.accept();

		_tokenRootAddr = tokenRootAddr;
		_owner = addrOwner;
		_oldManager = oldManager;
		_sendGasTo = sendGasTo;

		_marketFee = marketFee;
		_marketFeeDecimals = marketFeeDecimals;
		_price = price;
		_addrNft = addrNft;

		_leftOnOfferAfterFinish = leftOnOfferAfterFinish;
		_nftTransferFee = nftTransferFee;
		_methodsCallsFee = methodsCallsFee;

		_supportedInterfaces[
			bytes4(tvm.functionId(ITIP6.supportsInterface))
		] = true;

		_supportedInterfaces[
			bytes4(tvm.functionId(IRoyalty.royaltyInfo))
		] = true;

		_supportedInterfaces[
			bytes4(tvm.functionId(IOffer.setRoyalty)) ^
				bytes4(tvm.functionId(IOffer.getOfferInfo)) ^
				bytes4(tvm.functionId(IOffer.getFeesInfo)) ^
				bytes4(tvm.functionId(IOffer.getFeesValues))
		] = true;

		IRoyalty(addrNft).royaltyInfo{
			value: _methodsCallsFee,
			flag: 0,
			bounce: true,
			callback: Offer.setRoyalty
		}();
	}

	function setRoyalty(
		mapping(address => uint8) royalty
	) external virtual override {
		require(
			msg.sender == _addrNft,
			BaseErrors.message_sender_is_not_my_owner
		);

		_royalty = royalty;
		_isActive = true;

		emit OfferIsActivated();
	}

	function _getFeesValues(
		uint128 price
	)
		internal
		view
		virtual
		returns (
			uint128 totalFeeValue,
			mapping(address => uint128) royalties,
			uint128 marketFeeValue
		)
	{
		uint128 marketFeeDecimalsValue = uint128(
			uint128(10) ** uint128(_marketFeeDecimals)
		);
		marketFeeValue = math.divc(
			math.muldiv(price, uint128(_marketFee), uint128(100)),
			marketFeeDecimalsValue
		);
		totalFeeValue = marketFeeValue;

		for ((address royaltyAddress, uint8 value): _royalty) {
			uint128 royaltyValue = value > 0
				? math.muldiv(price, uint128(value), uint128(100))
				: 0;
			totalFeeValue += royaltyValue;
			royalties[royaltyAddress] = royaltyValue;
		}
	}

	/// @notice Bounce means that nft doesn't support royalty, just ignore them
	onBounce(TvmSlice body) external virtual {
		_isActive = true;

		emit OfferIsActivated();
	}

	function getOfferInfo()
		external
		view
		virtual
		responsible
		override
		returns (
			uint256 id,
			address nft,
			address rootAddress,
			address owner,
			address oldManager,
			address sendGasTo,
			uint128 price,
			bool isActive
		)
	{
		return
			{value: 0, flag: 64, bounce: false} (
				_id,
				_addrNft,
				_marketRootAddr,
				_owner,
				_oldManager,
				_sendGasTo,
				_price,
				_isActive
			);
	}

	function getFeesInfo()
		external
		view
		virtual
		responsible
		override
		returns (
			uint128 marketFee,
			uint8 marketFeeDecimals,
			uint128 leftOnOfferAfterFinish,
			uint128 nftTransferFee,
			uint128 methodsCallsFee
		)
	{
		return
			{value: 0, flag: 64, bounce: false} (
				_marketFee,
				_marketFeeDecimals,
				_leftOnOfferAfterFinish,
				_nftTransferFee,
				_methodsCallsFee
			);
	}

	function royaltyInfo()
		external
		view
		virtual
		responsible
		override
		returns (mapping(address => uint8) royalty)
	{
		return {value: 0, flag: 64, bounce: false} (_royalty);
	}

	modifier onlyOwner() {
		require(
			msg.sender == _owner,
			BaseErrors.message_sender_is_not_my_owner
		);
		_;
	}

	modifier onlyManager() {
		require(
			msg.sender == _oldManager,
			BaseErrors.message_sender_is_not_my_owner
		);
		_;
	}

	modifier onlyMarketRoot() {
		require(
			msg.sender == _marketRootAddr,
			OffersBaseErrors.message_sender_is_not_my_root
		);
		_;
	}
}
