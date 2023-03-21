#if !COMMON_HELPERS
#define COMMON_HELPERS

[@inline] 
let is_a_nat (i : int) : nat option = Michelson.is_nat i 

[@inline] 
let mutez_to_natural (a: tez) : nat =  a / 1mutez 

[@inline] 
let natural_to_mutez (a: nat): tez = a * 1mutez 

[@inline] let calculate_price (start_time, duration, starting_price, token_price : timestamp * int * tez * tez) : tez =
  match is_a_nat ((start_time + duration) - Tezos.now) with
  | None -> token_price
  | Some t -> t * (starting_price - token_price)/ abs duration + token_price 

[@inline]
let token_transfer (token_address: address) (txs : transfer list) : operation =
    let token_contract: token_contract_transfer contract =
    match (Tezos.get_entrypoint_opt "%transfer" token_address : token_contract_transfer contract option) with
    | None -> (failwith error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT : token_contract_transfer contract)
    | Some contract -> contract in 
    let transfers = List.map (fun (tx : transfer) -> tx.from_, List.map (fun  (dst : transfer_destination) -> (dst.to_, (dst.token_id, dst.amount))) tx.txs) txs in
    Tezos.transaction transfers 0mutez token_contract

[@inline] 
let xtz_transfer (to_ : address) (amount_ : tez) : operation = 
    let to_contract : unit contract = 
        match (Tezos.get_contract_opt to_ : unit contract option) with 
        | None -> (failwith error_INVALID_TO_ADDRESS : unit contract) 
        | Some c -> c in 
    Tezos.transaction () amount_ to_contract 

let set_pause (pause : bool) (store : storage) : return = 
  if Tezos.sender <> store.admin then 
    (failwith(error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT) : return) 
  else 
    ([] : operation list), {store with paused = pause} 

let update_fee (param : update_fee_param) (store : storage) : return = 
    if Tezos.sender <> store.admin then 
        (failwith error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT : return) 
    else 
        ([] : operation list), { store with management_fee_rate = param } 

let update_admin (new_admin: update_admin_param) (storage : storage) : return = 
  if Tezos.sender <> storage.admin then 
    (failwith(error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT) : return) 
  else 
    ([] : operation list), { storage with admin = new_admin } 

let update_nft_address (new_nft_address: update_nft_address_param) (store : storage) : return =
  if Tezos.sender <> store.admin then
    (failwith(error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT) : return)
  else
    ([] : operation list), { store with nft_address = new_nft_address }

let update_royalties_address (new_royalties_address: update_royalties_address_param) (store : storage) : return =
  if Tezos.sender <> store.admin then
    (failwith(error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT) : return)
  else
    ([] : operation list), { store with royalties_address = new_royalties_address }


#endif
