pragma ton-solidity =0.58.1;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "@itgold/everscale-tip/contracts/TIP4_1/interfaces/ITIP4_1NFT.sol";

interface ISell {
	event SellCreated(
		address marketRoot,
		address collection,
		address owner,
		address addrNft,
		address oldManager,
		uint128 price
	);
	event SellConfirmed(address newOwner);
	event SellCancelled();

	function cancelOrder() external;

	function cancelOrderWithCallbacks(
		mapping(address => ITIP4_1NFT.CallbackParams) changeManagerCallbacks
	) external;
}
