#if !MARKETPLACE_INTERFACE 
#define MARKETPLACE_INTERFACE 

#include "../common/interface.mligo"

type counter_offer =
{
    start_time : timestamp;
    end_time : timestamp;
    token_symbol: token_symbol;
    ft_amount : nat;
    owner : address;
}

type offer_info = 
[@layout:comb] 
{ 
    token_amount : nat; 
    value : nat; 
    start_time: timestamp; 
    end_time : timestamp; 
    origin : address;
    token_symbol : token_symbol;
} 

type swap_info = 
[@layout:comb] 
{ 
  owner : address; 
  token_id : token_id; 
  is_dutch : bool;
  is_reserved : bool;
  starting_price : nat;
  token_price : nat; 
  start_time : timestamp; 
  duration : int;
  end_time : timestamp; 
  token_amount : nat; 
  origin : address;
  recipient : address;
  ft_symbol : token_symbol;
  accepted_tokens : token_symbol set;
  is_multi_token : bool;
} 

type storage = 
[@layout:comb] 
{ 
  nft_address : address; 
  royalties_address : address;
  next_token_id : token_id; 
  tokens : ((token_id * address), swap_id) big_map;
  counter_offers : (counter_offer_id, counter_offer) big_map; 
  swaps : (swap_id, swap_info) big_map; 
  offers : (offer_id , offer_info) big_map; 
  management_fee_rate : nat; 
  paused : bool; 
  allowed_tokens : (token_symbol, fun_token) big_map;
  available_pairs : ((token_symbol * token_symbol), string) big_map;
  single_tokens : string set;
  oracle : address;
  multisig : address;
  treasury : address;
} 

type marketplace_mint_param = 
[@layout:comb] 
{ 
  metadata_url: string; 
  royalties: nat; 
  amount_: nat;
  owner : address;
} 

type recipient_type = 
| General of unit
| Reserved of address

type dutch_swap_param =
[@layout:comb]
{
  starting_price : nat;
  duration : nat;
}

type swap_type =
| Regular of unit
| Dutch of dutch_swap_param

type add_to_marketplace_param = 
[@layout:comb] 
{ 
  swap_type : swap_type;
  token_id : token_id; 
  token_price : nat; 
  start_time : timestamp; 
  end_time : timestamp; 
  token_amount : nat; 
  token_origin : address; 
  recipient : recipient_type;
  token_symbol : token_symbol;
  accepted_tokens : token_symbol set;
  is_multi_token : bool;
} 

type remove_from_marketplace_param = swap_id

type offer_param = 
[@layout:comb] 
{ 
    token_amount : nat; 
    token_id : token_id; 
    start_time: timestamp; 
    end_time : timestamp; 
    token_origin : address;
    token_symbol : token_symbol;
    ft_amount : nat;
} 

type accept_offer_param = 
[@layout:comb] 
{ 
  buyer : address;
  token_id : token_id;
  token_symbol : token_symbol;
  token_origin : address;
} 

type counter_offer_param =
[@layout:comb]
{
  token_id : token_id;
  buyer : address;
  start_time : timestamp;
  end_time : timestamp;
  token_symbol: token_symbol;
  ft_amount : nat;
  token_origin : address;
}

type accept_counter_offer_param =
[@layout:comb]
{
  token_id : token_id; 
  seller : address;
  token_origin : address;
}

type withdraw_counter_offer_param =
[@layout:comb]
{
  token_id : token_id;
  buyer : address;
  token_origin : address;
}

type withdraw_offer_param =
{
  token_id : token_id;
  token_origin : address;
}

type update_times_param = 
[@layout:comb]
{ 
  start_time : timestamp; 
  end_time : timestamp 
}

type update_swap_actions =
| Add_amount of nat
| Reduce_amount of nat
| Update_price of nat
| Update_times of update_times_param
| Update_duration of nat
| Update_starting_price of nat
| Update_reserved_address of address

type update_swap_param =
[@layout:comb]
{
  swap_id : swap_id;
  action : update_swap_actions;
}

type parameter = 
| SetPause of bool 
| UpdateFee of update_fee_param 
| UpdateRoyalties of update_royalties_param 
| UpdateOracleAddress of address
| UpdateAllowedTokens of update_allowed_tokens_param
| MintNft of marketplace_mint_param 
| UpdateNftAddress of update_nft_address_param 
| UpdateRoyaltiesAddress of update_royalties_address_param
| AddToMarketplace of add_to_marketplace_param 
| RemoveFromMarketplace of remove_from_marketplace_param 
| Collect of collect_marketplace_param
| SendOffer of offer_param 
| UpdateOffer of offer_param
| WithdrawOffer of withdraw_offer_param 
| AcceptOffer of accept_offer_param
| MakeCounterOffer of counter_offer_param
| WithdrawCounterOffer of withdraw_counter_offer_param
| AcceptCounterOffer of accept_counter_offer_param
| UpdateSwap of update_swap_param

type return = operation list * storage 

let pseudo_swap : swap_info =
{
  owner = ("" : address);
  token_id = 0n;
  is_dutch = false;
  is_reserved = false;
  starting_price = 0n;
  token_price = 0n;
  start_time = (0 : timestamp);
  duration = 0;
  end_time = (0 : timestamp);
  token_amount = 0n;
  origin = ("" : address);
  recipient = ("" : address);
  accepted_tokens = (Set.empty : string set);
  ft_symbol = "";
  is_multi_token = false;
}

#endif 
