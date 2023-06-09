pragma ton-solidity =0.58.1;

interface IWhiteListManagement {
	event AddedToWhiteList(address[] addresses);
	event RemovedFromWhiteList(address[] addresses);

	function addToWhiteListInternal(address[] addresses, address sendGasTo)
		external
		internalMsg;

	function removeFromWhiteListInternal(address[] addresses, address sendGasTo)
		external
		internalMsg;

	function getWhiteList()
		external
		view
		responsible
		returns (mapping(address => bool) whiteList);

	function getWhiteListManager()
		external
		view
		responsible
		returns (address whiteListManager);
}
