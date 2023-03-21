#if !MARKETPLACE_ERRORS
#define MARKETPLACE_ERRORS

[@inline] let error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT = 101n
[@inline] let error_TOKEN_CONTRACT_MUST_HAVE_A_MINT_ENTRYPOINT = 102n
[@inline] let error_SWAP_ID_DOES_NOT_EXIST = 103n
[@inline] let error_ONLY_OWNER_CAN_REMOVE_FROM_MARKETPLACE = 104n
[@inline] let error_FEE_GREATER_THAN_AMOUNT = 105n
[@inline] let error_INVALID_TO_ADDRESS = 106n
[@inline] let error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT = 107n
[@inline] let error_ROYALTIES_TOO_HIGH = 108n
[@inline] let error_SALE_IS_NOT_STARTED_YET = 109n
[@inline] let error_SALE_IS_FINISHED = 110n
[@inline] let error_ACCEPTING_OFFER_IS_TOO_EARLY = 111n
[@inline] let error_ACCEPTING_OFFER_IS_TOO_LATE =112n
[@inline] let error_OFFER_DOES_NOT_EXIST = 113n
[@inline] let error_AMOUNT_IS_NOT_EQUAL_TO_PRICE = 114n
[@inline] let error_OFFER_ALREADY_PLACED = 115n
[@inline] let error_NO_OFFER_PLACED = 116n
[@inline] let error_MARKETPLACE_IS_PAUSED = 117n
[@inline] let error_TOKEN_IS_ALREADY_ON_SALE = 118n
[@inline] let error_INSUFFICIENT_TOKEN_BALANCE = 119n
[@inline] let error_START_TIME_IS_LATER_THAN_END_TIME = 120n
[@inline] let error_NO_ZERO_TOKEN_AMOUNT_ALLOWED = 121n
[@inline] let error_ONLY_OWNER_CAN_CALL_THIS_ENTRYPOINT = 122n
[@inline] let error_ROYALTIES_CONTRACT_MUST_HAVE_A_ROYALTIES_MINT_ENTRYPOINT = 123n
[@inline] let error_ONLY_CALLBACK_CONTRACT_CAN_CALL_THIS_ENTRYPOINT = 124n
[@inline] let error_CALLER_NOT_PERMITTED_TO_ACCEPT_OFFER = 125n
[@inline] let error_DUTCH_AUCTION_ACTIVE = 126n
[@inline] let error_DURATION_IS_LONGER_THAN_SWAP_DURATION = 127n
[@inline] let error_ONLY_RECIPIENT_CAN_COLLECT = 128n
[@inline] let error_CAN_NOT_UPDATE_DURATION_FOR_THIS_SWAP = 129n
[@inline] let error_CAN_NOT_UPDATE_STARTING_PRICE_FOR_THIS_SWAP = 130n

#endif
