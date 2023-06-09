pragma ton-solidity =0.58.1;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "@itgold/everscale-tip/contracts/TIP6/TIP6.sol";
import "@itgold/everscale-tip/contracts/TIP4_1/interfaces/INftChangeManager.sol";
import "@grandbazar-io/everscale-tip4-contracts/contracts/libraries/BaseErrors.sol";
import "../errors/OffersBaseErrors.sol";
import "../interfaces/IOffersRoot.sol";

abstract contract OffersRoot is
	IOffersRoot,
	INftChangeManager,
	TIP6
{
	uint256 _ownerPubkey;

	/// Market fee in percents
	uint8 _marketFee;
	uint8 _marketFeeDecimals;

	/// Value that will be sent to offer with counstructor init
	uint128 _deploymentFee;
	/// Value that will be stored on current root
	uint128 _creationPrice;
	/// Value that is needed to process deploy method
	uint128 _minimalGasAmount;
	/// Value to process NFT's changeManager method. Used only in generatePayload method
	uint128 _nftGasAmount;
	/// How many evers should be left on offer contracts after finish
	uint128 _leftOnOfferAfterFinish;
	/// NFT's transfer method fee
	uint128 _nftTransferFee;
	/// Amount of evers to be sent with various contracts methods calls
	uint128 _methodsCallsFee;

	TvmCell _offerCode;

	uint256 _totalDeployed;

	address _withdrawalAddress;

	bool _marketIsActive;

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
	) public {
		tvm.accept();
		_offerCode = offerCode;

		_ownerPubkey = ownerPubkey;

		_deploymentFee = deploymentFee;
		_creationPrice = creationPrice;
		_minimalGasAmount = minimalGasAmount;
		_leftOnOfferAfterFinish = leftOnOfferAfterFinish;
		_nftTransferFee = nftTransferFee;
		_methodsCallsFee = methodsCallsFee;
		_nftGasAmount = nftGasAmount;

		_marketFee = marketFee;
		_marketFeeDecimals = marketFeeDecimals;

		_withdrawalAddress = withdrawalAddress;

		_supportedInterfaces[
			bytes4(tvm.functionId(ITIP6.supportsInterface))
		] = true;

		_supportedInterfaces[
			bytes4(tvm.functionId(IOffersRoot.getOwner)) ^
				bytes4(tvm.functionId(IOffersRoot.getWithdrawalAddress)) ^
				bytes4(tvm.functionId(IOffersRoot.getFeesInfo)) ^
				bytes4(tvm.functionId(IOffersRoot.getMarketStatus)) ^
				bytes4(tvm.functionId(IOffersRoot.offerCode)) ^
				bytes4(tvm.functionId(IOffersRoot.offerCodeHash)) ^
				bytes4(tvm.functionId(IOffersRoot.offerAddress))
		] = true;

		_supportedInterfaces[
			bytes4(tvm.functionId(INftChangeManager.onNftChangeManager))
		] = true;

		_marketIsActive = true;
	}

	function onNftChangeManager(
		uint256 id,
		address owner,
		address oldManager,
		address newManager,
		address collection,
		address sendGasTo,
		TvmCell payload
	) external virtual override;

	function setDeploymentFee(uint128 value)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_deploymentFee = value;
	}

	function setMarketFee(uint8 value, uint8 decimals)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_marketFee = value;
		_marketFeeDecimals = decimals;
	}

	function setCreationPrice(uint128 value)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_creationPrice = value;
	}

	function setNftGasAmount(uint128 value)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_nftGasAmount = value;
	}

	function setMinimalGasAmount(uint128 value)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_minimalGasAmount = value;
	}

	function setLeftOnOfferAfterFinish(uint128 value)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_leftOnOfferAfterFinish = value;
	}

	function setNftTransferFee(uint128 value)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_nftTransferFee = value;
	}

	function setMethodsCallsFee(uint128 value)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_methodsCallsFee = value;
	}

	function setMarketActiveStatus(bool value)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_marketIsActive = value;
	}

	function setOfferCode(TvmCell newCode)
		external
		virtual
		externalMsg
		onlyOwner
	{
		tvm.accept();
		_offerCode = newCode;
	}

	function withdraw(uint128 value)
		external
		view
		virtual
		externalMsg
		onlyOwner
	{
		require(
			address(this).balance - value >= 2 ever,
			BaseErrors.not_enough_balance_to_withdraw
		);
		tvm.accept();
		_withdrawalAddress.transfer(value, true);
	}

	function changeWithdrawalAddress(address newAddress)
		external
		virtual
		internalMsg
		onlyWithdrawalAddress
	{
		require(newAddress.value != 0, 100);
		tvm.accept();
		_withdrawalAddress = newAddress;
	}

	function changeOwner(uint256 owner) external virtual externalMsg onlyOwner {
		tvm.accept();
		_ownerPubkey = owner;
	}

	function destroy() external virtual internalMsg onlyWithdrawalAddress {
		tvm.accept();
		selfdestruct(_withdrawalAddress);
	}

	function getOwner()
		external
		view
		virtual
		responsible
		override
		returns (uint256 ownerPubkey)
	{
		return {value: 0, flag: 64, bounce: false} (_ownerPubkey);
	}

	function getWithdrawalAddress()
		external
		view
		virtual
		responsible
		override
		returns (address withdrawalAddress)
	{
		return {value: 0, flag: 64, bounce: false} (_withdrawalAddress);
	}

	function getFeesInfo()
		external
		view
		virtual
		responsible
		override
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
		)
	{
		return
			{value: 0, flag: 64, bounce: false} (
				_deploymentFee,
				_creationPrice,
				_totalDeploymentPrice(),
				_minimalGasAmount,
				_nftGasAmount,
				_leftOnOfferAfterFinish,
				_nftTransferFee,
				_methodsCallsFee,
				_marketFee,
				_marketFeeDecimals
			);
	}

	function getMarketStatus()
		external
		view
		virtual
		responsible
		override
		returns (bool marketIsActive)
	{
		return {value: 0, flag: 64, bounce: false} (_marketIsActive);
	}

	function offerCode()
		external
		view
		virtual
		responsible
		override
		returns (TvmCell code)
	{
		return
			{value: 0, flag: 64, bounce: false} (
				_buildChildContractCode(address(this), _offerCode)
			);
	}

	function offerCodeHash()
		external
		view
		virtual
		responsible
		override
		returns (uint256 codeHash)
	{
		return
			{value: 0, flag: 64, bounce: false} (
				tvm.hash(_buildChildContractCode(address(this), _offerCode))
			);
	}

	function offerAddress(uint256 id)
		external
		view
		virtual
		responsible
		override
		returns (address offer)
	{
		return {value: 0, flag: 64, bounce: false} (_resolveOffer(id));
	}

	function _totalDeploymentPrice() internal view virtual returns (uint128) {
		return _deploymentFee + _creationPrice + _minimalGasAmount;
	}

	function _resolveOffer(uint256 id)
		internal
		view
		virtual
		returns (address offer)
	{
		TvmCell code = _buildChildContractCode(address(this), _offerCode);
		TvmCell state = _buildOfferState(code, id);
		uint256 hashState = tvm.hash(state);
		offer = address.makeAddrStd(address(this).wid, hashState);
	}

	function _buildChildContractCode(address rootAddress, TvmCell code)
		internal
		view
		virtual
		returns (TvmCell)
	{
		TvmBuilder salt;
		salt.store(rootAddress);
		return tvm.setCodeSalt(code, salt.toCell());
	}

	function _buildOfferState(TvmCell code, uint256 id)
		internal
		pure
		virtual
		returns (TvmCell)
	{
		// Override this function and pass desirable contract
		// return tvm.buildStateInit({contr: TIP4_1Nft, varInit: {_id: id, _marketRootAddr: address(this)}, code: code});
	}

	modifier onlyOwner() {
		require(
			msg.pubkey() == _ownerPubkey,
			BaseErrors.message_sender_is_not_my_owner
		);
		_;
	}

	modifier onlyWithdrawalAddress() {
		require(
			msg.sender == _withdrawalAddress,
			BaseErrors.message_sender_is_not_my_owner
		);
		_;
	}
}
