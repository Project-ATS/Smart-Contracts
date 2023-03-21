#if !COMMON_INTERFACE
#define COMMON_INTERFACE

type token_id = nat

type offer_id = (token_id * address * address) // (token_id, buyer, seller)

type token_key = 
[@layout:comb]
{
  token_id : token_id;
  origin : address;
}

type transfer_destination =
[@layout:comb]
{
  to_ : address;
  token_id : token_id;
  amount : nat;
}

type transfer =
[@layout:comb]
{
  from_ : address;
  txs : transfer_destination list;
}

type swap_id = nat

type royalties_amount = nat

type royalties_info = 
[@layout:comb]
{
  issuer: address;
  royalties: royalties_amount;
}

type update_royalties_param = 
[@layout:comb] 
{ 
  token_id : token_id; 
  royalties : nat; 
} 

type update_fee_param =  nat 

type update_admin_param = address 

type update_proxy_param = 
[@layout:comb]
| Add_proxy of address
| Remove_proxy of address

type update_nft_address_param = address 

type update_royalties_address_param = address

type nft_mint_param = 
[@layout:comb] 
{ 
  token_id: nat; 
  token_metadata: (string, bytes) map; 
  amount_ : nat; 
} 

type royalties_mint_param = 
[@layout:comb]
{
  token_id : token_id;
  royalties : nat;
}

type accept_offer_param = 
[@layout:comb] 
{ 
  buyer : address;
  token_id : token_id;
} 

type collect_param = 
[@layout:comb]
{
  swap_id : swap_id;
  token_amount : nat; 
}

type swap_royalties_param = 
[@layout:comb] 
{ 
  token_id : token_id; 
  swap_id : swap_id; 
  token_amount : nat; 
} 

type token_contract_transfer = (address * (address * (token_id * nat)) list) list 

#endif