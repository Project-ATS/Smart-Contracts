#include "swap_interface.mligo"

let error_FA12_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT = 1n
let error_CALLER_IS_NOT_ADMIN = 2n
let error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT = 3n
let error_SWAP_IS_PAUSED = 4n
let error_INVALID_TO_ADDRESS = 5n
let error_INVALID_AMOUNT = 6n



let xtz_transfer (to_ : address) (amount_ : tez) : operation =
    match (Tezos.get_contract_opt to_ : unit contract option) with
    | None -> (failwith error_INVALID_TO_ADDRESS : operation)
    | Some to_contract -> Tezos.transaction () amount_ to_contract


let fa12_transfer (fa12_address : address) (from_ : address) (to_ : address) (value : nat) : operation =
  let fa12_contract : fa12_contract_transfer contract =
    match (Tezos.get_entrypoint_opt "%transfer" fa12_address : fa12_contract_transfer contract option) with
    | None -> (failwith(error_FA12_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT) : fa12_contract_transfer contract)
    | Some contract -> contract in
    let transfer = {address_from = from_; address_to = to_; value = value} in
    Tezos.transaction transfer 0mutez fa12_contract


[@inline]
let token_transfer (token_address: address) (txs : transfer list) : operation =
    let token_contract: token_contract_transfer contract =
    match (Tezos.get_entrypoint_opt "%transfer" token_address : token_contract_transfer contract option) with
    | None -> (failwith error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT : token_contract_transfer contract)
    | Some contract -> contract in
    let transfers = List.map (fun (tx : transfer) -> tx.from_, List.map (fun  (dst : transfer_destination) -> (dst.to_, (dst.token_id, dst.amount))) tx.txs) txs in
    Tezos.transaction transfers 0mutez token_contract

let set_pause (param : bool) (store : storage) : return =
  if (Tezos.get_sender()) <> store.admin then
       (failwith(error_CALLER_IS_NOT_ADMIN) : return)
  else
    ([] : operation list), {store with paused = param}

let set_token_in (param : address) (store : storage) : return =
  if (Tezos.get_sender()) <> store.admin then
       (failwith(error_CALLER_IS_NOT_ADMIN) : return)
  else
    ([] : operation list), {store with token_in_address = param}

let set_token_out (param : address) (store : storage) : return =
  if (Tezos.get_sender()) <> store.admin then
       (failwith(error_CALLER_IS_NOT_ADMIN) : return)
  else
    ([] : operation list), {store with token_out_address = param}

let set_treasury (param : address) (store : storage) : return =
  if (Tezos.get_sender ()) <> store.admin then
       (failwith(error_CALLER_IS_NOT_ADMIN) : return)
  else
    ([] : operation list), {store with treasury = param}

let set_token_price (param : nat) (store : storage) : return =
  if (Tezos.get_sender()) <> store.admin then
       (failwith(error_CALLER_IS_NOT_ADMIN) : return)
  else
    ([] : operation list), {store with token_price = param}

let set_currency (param : string) (store : storage) : return =
  if (Tezos.get_sender()) <> store.admin then
       (failwith(error_CALLER_IS_NOT_ADMIN) : return)
  else
    ([] : operation list), {store with currency = param}


let buy(param : buy_param) (store : storage) : return =
  if store.paused then
     (failwith(error_SWAP_IS_PAUSED) : return)
 else
  let ops = ([] : operation list) in  


   let ops =
          if store.currency = "XTZ" then
            if (Tezos.get_amount ()) <> (param.amount * 1mutez) then
              (failwith error_INVALID_AMOUNT : operation list)
            else
              xtz_transfer store.treasury (param.amount * 1mutez) :: ops 
          else
             token_transfer 
        store.token_in_address 
          [
            {
              from_ = Tezos.get_sender();
              txs =
                [{
                  to_ = store.treasury;
                  token_id = 0n;
                  amount = param.amount;
                }]
            }
          ] :: ops 
        in
 
  let ops = fa12_transfer store.token_out_address (Tezos.get_self_address ()) (param.address_to) (param.amount * store.factor_decimals / store.token_price)  :: ops in

(ops, store)

let main (action, store : parameter * storage) : return =
 match action with
 | SetPause p -> set_pause p store
 | SetTokenIn p -> set_token_in p store
 | SetTokenOut p -> set_token_out p store
 | SetTreasury p -> set_treasury p store
 | SetTokenPrice p -> set_token_price p store
 | SetCurrency p -> set_currency p store
 | Buy p -> buy p store


