pragma ton-solidity =0.58.1;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "./abstract/Offer.sol";
import "./interfaces/ISellRoot.sol";
import "./interfaces/ISell.sol";

contract SellItem is Offer, ISell {
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
	)
		public
		Offer(
			tokenRootAddr,
			addrOwner,
			addrNft,
			oldManager,
			sendGasTo,
			price,
			marketFee,
			leftOnOfferAfterFinish,
			nftTransferFee,
			methodsCallsFee,
			marketFeeDecimals
		)
	{
		tvm.accept();

		_supportedInterfaces[bytes4(tvm.functionId(ISell.cancelOrder))] = true;

		emit SellCreated(
			_marketRootAddr,
			tokenRootAddr,
			addrOwner,
			addrNft,
			oldManager,
			price
		);
	}

	receive() external virtual {
		require(_isActive, OffersBaseErrors.offer_is_not_active);
		require(msg.value >= _price, OffersBaseErrors.not_enough_value_to_buy);
		require(msg.sender != _owner, OffersBaseErrors.buyer_is_my_owner);

		_isActive = false;

		(
			uint128 totalFeeValue,
			mapping(address => uint128) royalties,
			uint128 marketFeeValue
		) = _getFeesValues(_price);

		for ((address royaltyAddress, uint128 value): royalties) {
			royaltyAddress.transfer(value, false, 1);
		}

		ITIP4_1NFT(_addrNft).transfer{value: _nftTransferFee, bounce: false}(
			msg.sender,
			_sendGasTo,
			emptyMap
		);
		ISellRoot(_marketRootAddr).onOfferFinish{
			value: marketFeeValue,
			bounce: false
		}(_id, _owner, _addrNft, _oldManager, msg.sender, _price);
		emit SellConfirmed(msg.sender);

		tvm.rawReserve(_leftOnOfferAfterFinish, 2);
		if (_sendGasTo == _owner) {
			_owner.transfer(0, false, 128);
		} else {
			_owner.transfer(_price - totalFeeValue, false, 1);
			_sendGasTo.transfer(0, false, 128);
		}
	}

	function cancelOrder() external virtual override onlyManager {
		tvm.accept();

		_cancelOrder(emptyMap);
	}

	function cancelOrderWithCallbacks(
		mapping(address => ITIP4_1NFT.CallbackParams) changeManagerCallbacks
	) external virtual override onlyManager {
		tvm.accept();

		_cancelOrder(changeManagerCallbacks);
	}

	function getFeesValues()
		external
		view
		virtual
		responsible
		override
		returns (
			uint128 totalFeeValue,
			mapping(address => uint128) royalties,
			uint128 marketFeeValue
		)
	{
		return _getFeesValues(_price);
	}

	function _cancelOrder(
		mapping(address => ITIP4_1NFT.CallbackParams) changeManagerCallbacks
	) internal virtual {
		_isActive = false;
		ITIP4_1NFT(_addrNft).changeManager{
			value: changeManagerCallbacks.empty()
				? _methodsCallsFee
				: msg.value,
			bounce: false
		}(_oldManager, _sendGasTo, changeManagerCallbacks);
		ISellRoot(_marketRootAddr).onOfferCancel{
			value: _methodsCallsFee,
			bounce: false
		}(_id, _owner, _addrNft, _oldManager, _sendGasTo, _price);
		emit SellCancelled();

		selfdestruct(_sendGasTo);
	}
}
