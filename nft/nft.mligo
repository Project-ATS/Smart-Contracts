(**
Implementation of the FA2 interface for the NFT contract supporting multiple
types of NFTs. Each NFT type is represented by the range of token IDs - `token_def`.
 *)

#include "../common/interface.mligo"
#include "./fa2_errors.mligo"
#include "./fa2_interface.mligo"
#include "./fa2_operator_lib.mligo"

(* range of nft tokens *)
type token_def =
[@layout:comb]
{
  from_ : nat;
  to_ : nat;
}

type nft_meta = (token_def, token_metadata) big_map

type token_storage = {
  token_defs : token_def set;
  metadata : nft_meta;
}

type ledger_key = address * token_id

type ledger_amount = nat

type ledger = (ledger_key, ledger_amount) big_map

type nft_token_storage = {
  admin : address;
  ledger : ledger;
  operators : operator_storage;
  metadata : token_storage;
  token_metadata : token_metadata_storage;
  proxy : address set;
  paused : bool;
}

let set_pause (pause : bool) (store : nft_token_storage) : operation list * nft_token_storage = 
  if Tezos.sender <> store.admin then 
    (failwith(error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT) : operation list * nft_token_storage) 
  else 
    ([] : operation list), {store with paused = pause} 

(**
Retrieve the balances for the specified tokens and owners
@return callback operation
*)
let get_balance (p, ledger : balance_of_param * ledger) : operation =
  let to_balance = fun (r : balance_of_request) ->
    let owner = Big_map.find_opt (r.owner, r.token_id) ledger in
    match owner with 
    | None -> (failwith fa2_token_undefined : balance_of_response)
    | Some o ->
      let bal = o in
      { request = r; balance = bal; }
  in
  let responses = List.map to_balance p.requests in
  Tezos.transaction responses 0mutez p.callback

(**
Update leger balances according to the specified transfers. Fails if any of the
permissions or constraints are violated.
@param txs transfers to be applied to the ledger
@param validate_op function that validates of the tokens from the particular owner can be transferred.
 *)
let transfer (txs, validate_op, ops_storage, ledger
    : (transfer list) * operator_validator * operator_storage * ledger) : ledger =
    (* process individual transfer *)
    let make_transfer = (fun (l, tx : ledger * transfer) ->
      List.fold
        (fun (ll, dst : ledger * transfer_destination) ->
            let tokens = Big_map.find_opt (tx.from_, dst.token_id) ll in
            match tokens with
            | None -> (failwith fa2_token_undefined : ledger)
            | Some t ->
              if t < dst.amount
              then (failwith fa2_insufficient_balance : ledger)
              else
                let new_to_amount = match Big_map.find_opt (dst.to_, dst.token_id) ll with
                | Some a -> a + dst.amount
                | None -> dst.amount in
                let new_from_amount = abs (t - dst.amount) in
                let _u = validate_op (tx.from_, Tezos.sender, dst.token_id, ops_storage) in
                let new_ledger = Big_map.update (dst.to_, dst.token_id) (Some new_to_amount) ll in
                let new_ledger = 
                  if dst.amount = 0n then 
                    ll
                  else 
                    Big_map.update (tx.from_, dst.token_id) (Some new_from_amount) new_ledger in
                new_ledger
        ) tx.txs l
    )
    in

    List.fold make_transfer txs ledger

(** Finds a definition of the token type (token_id range) associated with the provided token id *)
let find_token_def (tid, token_defs : token_id * (token_def set)) : token_def =
  let tdef = Set.fold (fun (res, d : (token_def option) * token_def) ->
    match res with
    | Some _r -> res
    | None ->
      if tid >= d.from_ && tid < d.to_
      then  Some d
      else (None : token_def option)
  ) token_defs (None : token_def option)
  in
  match tdef with
  | None -> (failwith fa2_token_undefined : token_def)
  | Some d -> d



let update_proxy (action, storage : update_proxy_param * nft_token_storage) : nft_token_storage =
  if Tezos.sender <> storage.admin then
    failwith error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT
  else
  match action with
  | Add_proxy p -> 
  if Set.mem p storage.proxy then
    (failwith(error_ADDRESS_ALREADY_PROXY) : nft_token_storage)
  else
    { storage with proxy = Set.add p storage.proxy }
  | Remove_proxy p ->
  if Set.mem p storage.proxy = false then
    (failwith(error_ADDRESS_NOT_PROXY) : nft_token_storage)
  else
    { storage with proxy = Set.remove p storage.proxy }

let update_admin (new_admin, storage : update_admin_param * nft_token_storage) : nft_token_storage =
  if Tezos.sender <> storage.admin then
    failwith error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT
  else
    { storage with admin = new_admin }

let mint (param, storage : nft_mint_param * nft_token_storage) : nft_token_storage =
  if storage.paused then 
    (failwith (error_FA2_CONTRACT_IS_PAUSED) : nft_token_storage) 
  else if Set.mem Tezos.sender storage.proxy = false then
    failwith error_ONLY_PROXY_CAN_CALL_THIS_ENTRYPOINT
  else
    (* MINT TOKEN *)
    let { token_id = token_id ;
          token_metadata = token_metadata;
          amount_ = amount_;
        } = param in
    let _check_if_token_already_exists = match Big_map.find_opt (Tezos.source, token_id) storage.ledger with
      | Some _v -> failwith "token aleardy exists"
      | None -> ()
    in
    let new_ledger = Big_map.update (Tezos.source, token_id) (Some amount_) storage.ledger in

    (* ADD METADATA URL *)
    let nft_metadata = {
      token_id = token_id ;
      metadata = token_metadata ;
    } in
    let new_token_metadata = Big_map.update
      token_id
      (Some nft_metadata)
      storage.token_metadata
    in
    { storage with ledger = new_ledger ; token_metadata = new_token_metadata }


let main (param, storage : fa2_entry_points * nft_token_storage)
    : (operation  list) * nft_token_storage =
  match param with
  | UpdateProxy action ->
    (([] : operation list), update_proxy (action, storage))
  | UpdateAdmin new_admin ->
    (([] : operation list), update_admin (new_admin, storage))
  | Mint param ->
    (([] : operation list), mint (param, storage))
  | Transfer txs ->
    if storage.paused then 
      (failwith (error_FA2_CONTRACT_IS_PAUSED) : (operation  list) * nft_token_storage) 
    else 
      let new_ledger = transfer
        (txs, default_operator_validator, storage.operators, storage.ledger) in
      let new_storage = { storage with ledger = new_ledger; } in
      ([] : operation list), new_storage
  | Balance_of p ->
    let op = get_balance (p, storage.ledger) in
    [op], storage
  | Update_operators updates ->
    let new_ops = fa2_update_operators (updates, storage.operators) in
    let new_storage = { storage with operators = new_ops; } in
    ([] : operation list), new_storage
  | SetPause p -> set_pause p storage 
