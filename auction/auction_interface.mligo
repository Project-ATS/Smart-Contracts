#if !AUCTION_INTERFACE
#define AUCTION_INTERFACE

type revealed_price = 
[@layout:comb]
{
    price : tez;
    secret : string;
}

type auction_info = 
[@layout:comb]
{
    current_price : tez;
    current_highest_bidder : address;
    start_time : timestamp;
    end_time : timestamp;
    reserved_price_hashed : bytes;
    reserved_price_xtz : tez;
    permit_lower : bool;
    reveal_time : timestamp;
    adding_period : nat;
    extra_duration : nat;
    reveal_counter : nat;
}

type swap_info = 
[@layout:comb]
{
    owner : address;
    token_id : token_id;
    auction : auction_info;
    token_amount : nat;
    origin : address;
}

type storage =
[@layout:comb]
{
  admin: address;
  nft_address: address;
  royalties_address : address;
  swaps: (swap_id, swap_info) big_map;
  next_swap_id: swap_id;
  management_fee_rate : nat; 
  paused : bool;
}

type start_auction_param = 
[@layout:comb]
{
    token_id : token_id;
    start_time : timestamp;
    period : nat;
    starting_price : tez;
    reveal_time : nat;
    reserved_price_hashed : bytes;
    adding_period : nat;
    extra_duration : nat;
    token_amount : nat;
    token_origin : address;
}

type bid_param = swap_id

type reveal_price_param = 
[@layout:comb]
{
    swap_id : swap_id;
    revealed_price : revealed_price;
    permit_lower : bool;
}

type remove_from_auction_param = swap_id

type parameter =
[@layout:comb]
| PauseAuction of bool 
| UpdateMarketplaceAdmin of update_admin_param
| UpdateNftAddress of update_nft_address_param
| UpdateRoyaltiesAddress of update_royalties_address_param
| UpdateFee of update_fee_param
| StartAuction of start_auction_param
| Bid of bid_param
| RevealPrice of reveal_price_param
| RemoveFromMarketplace of remove_from_auction_param
| Collect of collect_param

type return = operation list * storage

#endif
