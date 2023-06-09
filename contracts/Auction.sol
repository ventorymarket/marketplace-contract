pragma ton-solidity =0.58.1;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "./abstract/Offer.sol";
import "./interfaces/IAuctionRoot.sol";
import "./errors/AuctionErrors.sol";
import "./interfaces/IAuction.sol";

contract Auction is Offer, IAuction {
	uint8 _bidDelta;

	uint256 _auctionDuration;
	uint256 _auctionEndTime;
	uint256 _extraSecondsAmount;

	uint128 _nextBidValue;

	Bid _currentBid;

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
		uint8 marketFeeDecimals,
		uint8 bidDelta,
		uint256 auctionDuration,
		uint256 extraSecondsAmount
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

		_bidDelta = bidDelta;
		_auctionDuration = auctionDuration;
		_auctionEndTime = now + _auctionDuration;
		_nextBidValue = price;
		_extraSecondsAmount = extraSecondsAmount;

		_supportedInterfaces[
			bytes4(tvm.functionId(IAuction.finishAuction)) ^
				bytes4(tvm.functionId(IAuction.getAuctionInfo))
		] = true;

		emit AuctionCreated(
			_marketRootAddr,
			tokenRootAddr,
			addrOwner,
			addrNft,
			oldManager,
			price,
			auctionDuration
		);
	}

	receive() external virtual {
		require(_isActive, OffersBaseErrors.offer_is_not_active);
		require(_owner != msg.sender, OffersBaseErrors.buyer_is_my_owner);
		require(msg.value >= _nextBidValue, AuctionErrors.bid_is_too_low);

		int256 timeDiff = int256(_auctionEndTime) - int256(now);
		if (timeDiff > 0 && timeDiff < int256(_extraSecondsAmount)) {
			uint256 oldEndTime = _auctionEndTime;
			_auctionEndTime = _auctionEndTime + _extraSecondsAmount;
			emit EndTimeChanged(oldEndTime, _auctionEndTime);
		}

		if (timeDiff > 0) {
			processBid(msg.sender, msg.value);
		} else {
			emit BidDeclined(msg.sender, msg.value);
			msg.sender.transfer(msg.value, false);
			_finishAuction();
		}
	}

	function finishAuction() external virtual override {
		require(_isActive, OffersBaseErrors.offer_is_not_active);
		require(
			now >= _auctionEndTime,
			AuctionErrors.auction_still_in_progress
		);
		tvm.accept();

		_finishAuction();
	}

	function processBid(address newBidSender, uint128 bid) internal virtual {
		Bid currentBid = _currentBid;
		Bid newBid = Bid(newBidSender, bid);
		_currentBid = newBid;
		calculateAndSetNextBid();
		emit BidPlaced(newBidSender, bid);

		// Return lowest bid value to the bidder's address
		if (currentBid.value > 0) {
			currentBid.addr.transfer(currentBid.value, false);
		}
	}

	function _finishAuction() internal virtual {
		_isActive = false;

		if (_currentBid.value > 0) {
			(
				uint128 totalFeeValue,
				mapping(address => uint128) royalties,
				uint128 marketFeeValue
			) = _getFeesValues(_currentBid.value);

			for ((address royaltyAddress, uint128 value): royalties) {
				royaltyAddress.transfer(value, false, 1);
			}

			ITIP4_1NFT(_addrNft).transfer{
				value: _nftTransferFee,
				bounce: false
			}(_currentBid.addr, _sendGasTo, emptyMap);
			IAuctionRoot(_marketRootAddr).onOfferFinish{
				value: marketFeeValue,
				bounce: false
			}(
				_id,
				_owner,
				_addrNft,
				_oldManager,
				_currentBid.addr,
				_currentBid.value,
				_price
			);
			emit AuctionFinished(
				_owner,
				_oldManager,
				_currentBid.addr,
				_currentBid.value,
				_price
			);

			tvm.rawReserve(_leftOnOfferAfterFinish, 2);
			if (_sendGasTo == _owner) {
				_owner.transfer(0, false, 128);
			} else {
				_owner.transfer(_currentBid.value - totalFeeValue, false, 1);
				_sendGasTo.transfer(0, false, 128);
			}
		} else {
			ITIP4_1NFT(_addrNft).changeManager{
				value: _methodsCallsFee,
				bounce: false
			}(_oldManager, _sendGasTo, emptyMap);
			IAuctionRoot(_marketRootAddr).onOfferExpiration{
				value: _methodsCallsFee,
				bounce: false
			}(_id, _owner, _addrNft, _oldManager, _sendGasTo, _price);
			emit AuctionExpired();

			selfdestruct(_sendGasTo);
		}
	}

	function calculateAndSetNextBid() internal virtual {
		_nextBidValue =
			_currentBid.value +
			math.muldiv(_currentBid.value, uint128(_bidDelta), uint128(100));
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
		return _getFeesValues(_currentBid.value);
	}

	function getAuctionInfo()
		external
		view
		virtual
		responsible
		override
		returns (
			uint8 bidDelta,
			uint256 extraSecondsAmount,
			uint256 auctionDuration,
			uint256 auctionEndTime,
			uint128 nexBidValue,
			uint128 currentBidValue,
			address currentBidAddress
		)
	{
		return
			{value: 0, flag: 64, bounce: false} (
				_bidDelta,
				_extraSecondsAmount,
				_auctionDuration,
				_auctionEndTime,
				_nextBidValue,
				_currentBid.value,
				_currentBid.addr
			);
	}
}
