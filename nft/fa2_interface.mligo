#if !FA2_INTERFACE
#define FA2_INTERFACE

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

type balance_of_request =
[@layout:comb]
{
  owner : address;
  token_id : token_id;
}

type balance_of_response =
[@layout:comb]
{
  request : balance_of_request;
  balance : nat;
}

type balance_of_param =
[@layout:comb]
{
  requests : balance_of_request list;
  callback : (balance_of_response list) contract;
}

type operator_param =
[@layout:comb]
{
  owner : address;
  operator : address;
  token_id: token_id;
}

type update_operator =
[@layout:comb]
  | Add_operator of operator_param
  | Remove_operator of operator_param

type token_metadata = (string, bytes) map
type token_metadata_item = 
[@layout:comb]
{
  token_id: token_id;
  metadata: token_metadata;
}

(*
One of the options to make token metadata discoverable is to declare
`token_metadata : token_metadata_storage` field inside the FA2 contract storage
*)
type token_metadata_storage = (token_id, token_metadata_item) big_map

(**
Optional type to define view entry point to expose token_metadata on chain or
as an external view
 *)
type token_metadata_param =
[@layout:comb]
{
  token_ids : token_id list;
  handler : (token_metadata list) -> unit;
}

type fa2_entry_points =
  | UpdateProxy of update_proxy_param
  | UpdateAdmin of update_admin_param
  | Mint of nft_mint_param
  | Transfer of transfer list
  | Balance_of of balance_of_param
  | Update_operators of update_operator list
  | SetPause of bool

(*
 TZIP-16 contract metadata storage field type.
 The contract storage MUST have a field
 `metadata : contract_metadata`
*)
type contract_metadata = (string, bytes) big_map

(* FA2 hooks interface *)

type transfer_destination_descriptor =
[@layout:comb]
{
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type transfer_descriptor =
[@layout:comb]
{
  from_ : address option;
  txs : transfer_destination_descriptor list
}

type transfer_descriptor_param =
[@layout:comb]
{
  batch : transfer_descriptor list;
  operator : address;
}



(*
Entrypoints for sender/receiver hooks
type fa2_token_receiver =
  ...
  | Tokens_received of transfer_descriptor_param
type fa2_token_sender =
  ...
  | Tokens_sent of transfer_descriptor_param
*)

#endif
