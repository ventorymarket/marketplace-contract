pragma ton-solidity =0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./abstract/OffersRoot.sol";
import "./interfaces/ISellRoot.sol";
import "./Sell.sol";
import "@itgold/everscale-tip/contracts/TIP4_1/interfaces/ITIP4_1NFT.sol";
import "@grandbazar-io/everscale-tip4-contracts/contracts/Nft.sol";

contract VentoryFactory is OffersRoot, ISellRoot {
	/// @param ownerPubkey External owner pubkey
	/// @param offerCode Code of the offer to be deployed
	/// @param deploymentFee Amount of evers that will be sent to the offer
	/// @param creationPrice Amount of evers that will be stored on the root
	/// @param minimalGasAmount Amount of evers that will be used to process deployment method
	/// @param leftOnOfferAfterFinish Amount of evers to be left on offers after finish to cover storage fee
	/// @param nftTransferFee Amount of evers to be sent with NFT's transfer method call
	/// @param methodsCallsFee Amount of evers to be sent with various contracts methods calls
	/// @param nftGasAmount Amount of evers to be used in nft's changeManager method
	/// 	It is used for returning in generatePayload only. Change will be sent to owner
	/// @param marketFee Market fee percent that will be sent to the offer
	/// @param marketFeeDecimals Percent decimal that will be sent to the offer
	/// @param withdrawalAddress Address to withdraw evers
	constructor(
		uint256 ownerPubkey,
		TvmCell offerCode,
		uint128 deploymentFee,
		uint128 creationPrice,
		uint128 minimalGasAmount,
		uint128 leftOnOfferAfterFinish,
		uint128 nftTransferFee,
		uint128 methodsCallsFee,
		uint128 nftGasAmount,
		uint8 marketFee,
		uint8 marketFeeDecimals,
		address withdrawalAddress
	)
		public
		OffersRoot(
			ownerPubkey,
			offerCode,
			deploymentFee,
			creationPrice,
			minimalGasAmount,
			leftOnOfferAfterFinish,
			nftTransferFee,
			methodsCallsFee,
			nftGasAmount,
			marketFee,
			marketFeeDecimals,
			withdrawalAddress
		)
	{
		tvm.accept();
	}

	/// @param payload Payload should contain only price in uint128
	function onNftChangeManager(
		uint256 id,
		address owner,
		address oldManager,
		address newManager,
		address collection,
		address sendGasTo,
		TvmCell payload
	) external virtual override {
		if (
			msg.value < _totalDeploymentPrice() ||
			!_marketIsActive
		) {
			tvm.rawReserve(0, 4);
			_rejectOffer(owner, oldManager, sendGasTo);
		} else {
			uint128 price = payload.toSlice().decode(uint128);

			if (price != 0) {
				tvm.rawReserve(_creationPrice, 4);
				_totalDeployed++;

				TvmCell offerCode = _buildChildContractCode(
					address(this),
					_offerCode
				);
				TvmCell stateOffer = _buildOfferState(
					offerCode,
					_totalDeployed
				);
				address offerAddress = new Sell{
					wid: address(this).wid,
					value: _deploymentFee,
					stateInit: stateOffer
				}(
					collection,
					owner,
					msg.sender,
					oldManager,
					sendGasTo,
					price,
					_marketFee,
					_leftOnOfferAfterFinish,
					_nftTransferFee,
					_methodsCallsFee,
					_marketFeeDecimals
				);

				emit SellDeployed(
					MarketOffer(
						collection,
						owner,
						msg.sender,
						oldManager,
						offerAddress,
						price
					)
				);
				ITIP4_1NFT(msg.sender).changeManager{value: 0, flag: 128}(
					offerAddress,
					sendGasTo,
					emptyMap
				);
			} else {
				tvm.rawReserve(0, 4);
				_rejectOffer(owner, oldManager, sendGasTo);
			}
		}
	}

	function onOfferFinish(
		uint256 id,
		address owner,
		address data,
		address oldManager,
		address newOwner,
		uint128 price
	) external virtual override {
		require(
			msg.sender == _resolveOffer(id),
			OffersBaseErrors.message_sender_is_not_my_offer
		);

		emit SellConfirmed(
			msg.sender,
			data,
			owner,
			oldManager,
			newOwner,
			price
		);
	}

	function onOfferCancel(
		uint256 id,
		address owner,
		address data,
		address oldManager,
		address sendGasTo,
		uint128 price
	) external virtual override {
		require(
			msg.sender == _resolveOffer(id),
			OffersBaseErrors.message_sender_is_not_my_offer
		);

		tvm.rawReserve(0, 4);
		emit SellCancelled(msg.sender, data, owner, oldManager, price);
		sendGasTo.transfer({value: 0, flag: 128});
	}

	/// @return payload onNftChangeManager call params
	/// totalDeploymentValue can contain _totalDeploymentPrice + _nftGasAmount (used only to call NFT's changeManger method)
	function generatePayload(uint128 price)
		external
		view
		virtual
		responsible
		override
		returns (
			TvmCell payload,
			uint128 totalDeploymentValue,
			uint128 totalValueWithNftGas
		)
	{
		require(price > 0, OffersBaseErrors.price_cannot_be_zero);
		TvmBuilder payloadBuilder;

		payloadBuilder.store(price);

		return
			{value: 0, flag: 64} (
				payloadBuilder.toCell(),
				_totalDeploymentPrice(),
				_totalDeploymentPrice() + _nftGasAmount
			);
	}

	function _rejectOffer(
		address owner,
		address oldManager,
		address sendGasTo
	) internal pure virtual {
		emit SellRejected(msg.sender, owner, oldManager);
		ITIP4_1NFT(msg.sender).changeManager{value: 0, flag: 128}(
			oldManager,
			sendGasTo,
			emptyMap
		);
	}

	function _buildOfferState(TvmCell code, uint256 id)
		internal
		pure
		virtual
		override
		returns (TvmCell)
	{
		return
			tvm.buildStateInit({
				contr: Sell,
				varInit: {_id: id, _marketRootAddr: address(this)},
				code: code
			});
	}
}
