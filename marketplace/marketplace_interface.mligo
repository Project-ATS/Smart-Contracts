#if !MARKETPLACE_INTERFACE 
#define MARKETPLACE_INTERFACE 

type offer_info = 
[@layout:comb] 
{ 
    token_amount : nat; 
    value : tez; 
    start_time: timestamp; 
    end_time : timestamp; 
    origin : address;
} 

type swap_info = 
[@layout:comb] 
{ 
  owner : address; 
  token_id : token_id; 
  is_dutch : bool;
  is_reserved : bool;
  starting_price : tez;
  token_price : tez; 
  start_time : timestamp; 
  duration : int;
  end_time : timestamp; 
  token_amount : nat; 
  origin : address;
  recipient : address;
} 

type storage = 
[@layout:comb] 
{ 
  admin : address; 
  nft_address : address; 
  royalties_address : address;
  next_token_id : token_id; 
  next_swap_id : swap_id; 
  tokens : ((token_id * address), swap_id) big_map; 
  swaps : (swap_id, swap_info) big_map; 
  offers : (offer_id , offer_info) big_map; 
  management_fee_rate : nat; 
  paused : bool; 
} 

type marketplace_mint_param = 
[@layout:comb] 
{ 
  metadata_url: string; 
  royalties: nat; 
  amount_: nat; 
} 

type recipient_type = 
| General of unit
| Reserved of address

type dutch_swap_param =
[@layout:comb]
{
  starting_price : tez;
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
  token_price : tez; 
  start_time : timestamp; 
  end_time : timestamp; 
  token_amount : nat; 
  token_origin : address; 
  recipient : recipient_type;
} 

type remove_from_marketplace_param = swap_id

type offer_param = 
[@layout:comb] 
{ 
    token_amount : nat; 
    token_id : token_id; 
    start_time: timestamp; 
    end_time : timestamp; 
    owner : address; 
    token_origin : address;
} 

type withdraw_offer_param = 
[@layout:comb] 
{ 
  owner : address; 
  token_id : token_id; 
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
| Update_price of tez
| Update_times of update_times_param
| Update_duration of nat
| Update_starting_price of tez
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
| UpdateMarketplaceAdmin of update_admin_param 
| MintNft of marketplace_mint_param 
| UpdateNftAddress of update_nft_address_param 
| UpdateRoyaltiesAddress of update_royalties_address_param
| AddToMarketplace of add_to_marketplace_param 
| RemoveFromMarketplace of remove_from_marketplace_param 
| Collect of collect_param
| SendOffer of offer_param 
| UpdateOffer of offer_param
| WithdrawOffer of withdraw_offer_param 
| AcceptOffer of accept_offer_param
| UpdateSwap of update_swap_param

type return = operation list * storage 

#endif 
