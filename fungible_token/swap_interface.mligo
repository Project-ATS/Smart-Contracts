#if !SWAP_INTERFACE 
#define SWAP_INTERFACE 

type token_id = nat

type buy_param = 
[@layout:comb] 
{ 
  address_to : address;
  amount: nat;
} 

type fa12_contract_transfer =
[@layout:comb]
  { [@annot:from] address_from : address;
    [@annot:to] address_to : address;
    value : nat }


type token_contract_transfer = (address * (address * (token_id * nat)) list) list 

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


type storage = 
[@layout:comb] 
{ 
  token_in_address : address; 
  token_out_address : address; 
  treasury : address; 
  token_price : nat; 
  admin : address;
  paused : bool;
  currency: string;
  factor_decimals : nat;
} 

type parameter = 
| SetPause of bool
| SetTokenIn of address
| SetTokenOut of address
| SetTreasury of address
| SetTokenPrice of nat
| SetCurrency of string
| Buy of buy_param

type return = operation list * storage 

#endif 