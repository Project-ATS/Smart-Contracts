#if !AUCTION_ERRORS
#define AUCTION_ERRORS

[@inline] let error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT = 201n
[@inline] let error_SWAP_ID_DOES_NOT_EXIST = 202n
[@inline] let error_ONLY_OWNER_CAN_REMOVE_FROM_MARKETPLACE = 203n
[@inline] let error_FEE_GREATER_THAN_AMOUNT = 204n
[@inline] let error_INVALID_TO_ADDRESS = 205n
[@inline] let error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT = 206n
[@inline] let error_NO_PAST_TIME_ALLOWED_AS_AUCTION_START_TIME = 207n
[@inline] let error_NO_ZERO_PERIOD_ALLOWED = 208n
[@inline] let error_AMOUNT_NOT_ENOUGH = 209n
[@inline] let error_AUCTION_NOT_ACTIVE = 210n
[@inline] let error_NOT_TIME_TO_REVEAL = 211n
[@inline] let error_NO_COLLECTING_UNTIL_AUCTION_IS_OVER = 212n
[@inline] let error_NO_AMOUNT_CAN_BE_SENT_WHEN_COLLECTING = 213n
[@inline] let error_ADDING_PERIOD_IS_OUT_OF_BOUNDS = 214n
[@inline] let error_ONLY_OWNER_CAN_CALL_THIS_ENTRYPOINT =215n
[@inline] let error_NO_MORE_REVELATION_TRIES = 216n
[@inline] let error_WRONG_RESERVED_PRICE_OR_SECRET = 217n
[@inline] let error_NO_REMOVING_WHILE_AUCTION_IS_ACTIVE = 218n
[@inline] let error_CONTRACT_IS_PAUSED =220n
[@inline] let error_ONLY_OWNER_CAN_REMOVE_TOKENS = 221n
[@inline] let error_ONLY_FA2_CAN_CALL_THIS_ENTRYPOINT = 222n
[@inline] let error_OWNER_CAN_NOT_BID = 223n
[@inline] let error_ROYALTIES_CONTRACT_MUST_HAVE_A_GET_ROYALTIES_ENTRYPOINT = 224n
[@inline] let error_AUCTION_NOT_STARTED = 225n
[@inline] let error_AUCTION_FINISHED = 226n
[@inline] let error_NO_ZERO_TOKEN_AMOUNT_ALLOWED = 227n

#endif
