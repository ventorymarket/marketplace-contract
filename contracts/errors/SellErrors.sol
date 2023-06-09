pragma ton-solidity =0.58.1;

library SellErrors {
    uint8 constant wrong_pubkey = 230;
    uint8 constant wrong_price = 231;
    uint8 constant wrong_seller_address = 232;
    uint8 constant wrong_token_id = 233;
    uint8 constant message_sender_is_not_good_wallet = 234;
    uint8 constant not_enough_value_to_buy = 235;
    uint8 constant message_sender_is_not_my_owner = 236;
    uint8 constant buyer_is_my_owner = 237;
    uint8 constant wrong_dest_wallet = 238;
    uint8 constant message_sender_is_not_my_deployer = 239;
}