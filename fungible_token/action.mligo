type transfer =
[@layout:comb] {
  [@annot:from] address_from : address;
  [@annot:to] address_to : address;
  value : nat
}

type transfer_batch = transfer list

type approve =
[@layout:comb] {
  spender : address;
  value : nat
}

type allowance_key =
[@layout:comb] {
  owner : address;
  spender : address
}

type get_allowance =
[@layout:comb] {
  request : allowance_key;
  callback : nat contract
}

type get_balance =
[@layout:comb] {
  owner : address;
  callback : nat contract
}

type get_total_supply =
[@layout:comb] {
  request : unit ;
  callback : nat contract
}

type burn =
[@layout:comb] {
  address_from : address;
  value : nat
}

type mint =
[@layout:comb] {
  address_to : address;
  value : nat
}

type set_token_metadata =
[@layout:comb] {
  uri : bytes;
  name : bytes;
  symbol : bytes;
  decimals : bytes;
  shouldPreferSymbol : bytes;
  thumbnailUri : bytes;
}

type set_metadata_param = bytes

type entrypoint_signature =
[@layout:comb]
{
    name : string;
    params : bytes;
    source_contract : address;
}

type call_param =
[@layout:comb]
{
    entrypoint_signature : entrypoint_signature;
    callback : unit -> operation list;
}

type token_id = nat
type ledger = (address, nat) big_map
type allowances = (allowance_key, nat) big_map

type metadata = (string, bytes) big_map
type token_metadata = (string, bytes) map
type token_metadata_item =
[@layout:comb] {
  token_id: token_id;
  token_info: token_metadata;
}
type token_metadata_storage = (token_id, token_metadata_item) big_map

type storage = {
  paused: bool;
  burn_paused: bool;
  ledger : ledger;
  allowances : allowances;
  total_supply : nat;
  metadata : metadata;
  token_metadata : token_metadata_storage;
  multisig : address;
}

type parameter =
  | Transfer of transfer
  | TransferBatch of transfer_batch
  | Approve of approve
  | Mint of mint
  | Burn of burn
  | GetAllowance of get_allowance
  | GetBalance of get_balance
  | GetTotalSupply of get_total_supply
  | SetPause of bool
  | SetBurnPause of bool
  | SetMultisig of address
  | SetTokenMetadata of set_token_metadata
  | SetMetadata of set_metadata_param

type result = operation list * storage

[@inline]
let prepare_multisig (type p) (entrypoint_name: string) (param: p) (func: unit -> operation list) (store : storage) : operation list =
    match (Tezos.get_entrypoint_opt "%callMultisig" store.multisig : call_param contract option ) with
    | None -> (failwith("no call entrypoint") : operation list)
    | Some contract ->
        let packed = Bytes.pack param in
        let param_hash = Crypto.sha256 packed in
        let entrypoint_signature =
          {
            name = entrypoint_name;
            params = param_hash;
            source_contract = (Tezos.get_self_address ());
          }
        in
        let call_param =
        {
          entrypoint_signature = entrypoint_signature;
          callback = func;
        }
        in
        let set_storage = Tezos.transaction call_param 0mutez contract in
        [set_storage]

[@inline]
let positive (n : nat) : nat option =
  if n = 0n
    then (None : nat option)
  else
    Some n

let transfer (param, storage : transfer * storage) : storage =
  if storage.paused = true then
    (failwith("contract in pause") : storage)
  else
    let allowances = storage.allowances in
    let ledger = storage.ledger in

    let new_allowances =
      if (Tezos.get_sender()) = param.address_from then allowances
      else
        let allowance_key = { owner = param.address_from ; spender = (Tezos.get_sender()) } in
        let authorized_value = match Big_map.find_opt allowance_key allowances with
          | Some value -> value
          | None -> 0n in
        let new_authorized_value = match is_nat (authorized_value - param.value) with
          | None -> (failwith "NotEnoughAllowance" : nat)
          | Some new_authorized_value -> new_authorized_value in
        Big_map.update allowance_key (positive new_authorized_value) allowances in

    let ledger =
      let from_balance = match Big_map.find_opt param.address_from ledger with
        | Some value -> value
        | None -> 0n in
      let new_from_balance = match is_nat (from_balance - param.value) with
        | None -> (failwith "NotEnoughBalance" : nat)
        | Some new_from_balance -> new_from_balance in
      Big_map.update param.address_from (positive new_from_balance) ledger in

    let ledger =
      let to_balance = match Big_map.find_opt param.address_to ledger with
        | Some value -> value
        | None -> 0n in
      let new_to_balance = to_balance + param.value in
      Big_map.update param.address_to (positive new_to_balance) ledger in
    { storage with ledger = ledger; allowances = new_allowances }

let transfer_batch (param, storage : transfer_batch * storage) : result =
  if storage.paused = true then
    (failwith("contract in pause") : result)
  else
    let transfer_single (st, tr : storage * transfer) : storage =
      transfer (tr, st)
    in
    let new_storage = List.fold transfer_single param storage in
    (([] : operation list), new_storage)

let approve (param, storage : approve * storage) : result =
  if storage.paused = true then
    (failwith("contract in pause") : result)
  else
    let allowances = storage.allowances in
    let allowance_key = { owner = (Tezos.get_sender()) ; spender = param.spender } in
    let previous_value =
      match Big_map.find_opt allowance_key allowances with
      | Some value -> value
      | None -> 0n
    in
    begin
      if previous_value > 0n && param.value > 0n
        then (failwith "UnsafeAllowanceChange")
      else ();
      let allowances = Big_map.update allowance_key (positive param.value) allowances in
      (([] : operation list), { storage with allowances = allowances })
    end

let get_allowance (param, storage : get_allowance * storage) : result =
  let value =
    match Big_map.find_opt param.request storage.allowances with
    | Some value -> value
    | None -> 0n in
  [Tezos.transaction value 0mutez param.callback], storage

let get_balance (param, storage : get_balance * storage) : result =
  let value =
    match Big_map.find_opt param.owner storage.ledger with
    | Some value -> value
    | None -> 0n in
  [Tezos.transaction value 0mutez param.callback], storage

let get_total_supply (param, storage : get_total_supply * storage) : result =
  let total = storage.total_supply in
  [Tezos.transaction total 0mutez param.callback], storage

let set_pause (param, storage : bool * storage): result =
  if (Tezos.get_sender()) <> storage.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%setPause" sender_address : bool contract option) with
      | None -> (failwith("no setPause entrypoint") : operation list)
      | Some set_pause_entrypoint -> [Tezos.transaction param 0mutez set_pause_entrypoint] in
    (prepare_multisig "setPause" param func storage), storage
  else
    (([] : operation list), { storage with paused = param })

let set_burn_pause (param, storage : bool * storage): result =
  if (Tezos.get_sender()) <> storage.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%setBurnPause" sender_address : bool contract option) with
      | None -> (failwith("no setBurnPause entrypoint") : operation list)
      | Some set_burn_pause_entrypoint -> [Tezos.transaction param 0mutez set_burn_pause_entrypoint] in
    (prepare_multisig "setBurnPause" param func storage), storage
  else
    (([] : operation list), { storage with burn_paused = param })


let set_multisig (param, storage : address * storage) : result =
  if (Tezos.get_sender()) <> storage.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%setMultisig" sender_address : address contract option) with
      | None -> (failwith("no setMultisig entrypoint") : operation list)
      | Some set_multisig_entrypoint -> [Tezos.transaction param 0mutez set_multisig_entrypoint] in
    (prepare_multisig "setMultisig" param func storage), storage
  else
    ([] : operation list), { storage with multisig = param }

let set_token_metadata (param, storage : set_token_metadata * storage): result =
  if (Tezos.get_sender()) <> storage.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%setTokenMetadata" sender_address : set_token_metadata contract option) with
      | None -> (failwith("no setTokenMetadata entrypoint") : operation list)
      | Some set_token_metadata_entrypoint -> [Tezos.transaction param 0mutez set_token_metadata_entrypoint] in
    (prepare_multisig "setTokenMetadata" param func storage), storage
  else
    let token_id = 0n in
    let token_info = Map.literal [
      ("", param.uri);
      ("name", param.name);
      ("symbol", param.symbol);
      ("decimals", param.decimals);
      ("shouldPreferSymbol", param.shouldPreferSymbol);
      ("thumbnailUri", param.thumbnailUri);
    ] in
    let new_token_metadata_entry = {
      token_id = token_id;
      token_info = token_info
    } in
    let new_token_metadata = Big_map.update token_id (Some new_token_metadata_entry) storage.token_metadata in
    (([] : operation list), { storage with token_metadata = new_token_metadata })

let set_metadata (param, storage : set_metadata_param * storage): result =
  if (Tezos.get_sender()) <> storage.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%setMetadata" sender_address : set_metadata_param contract option) with
      | None -> (failwith("no setMetadata entrypoint") : operation list)
      | Some set_metadata_entrypoint -> [Tezos.transaction param 0mutez set_metadata_entrypoint] in
    (prepare_multisig "setMetadata" param func storage), storage
  else
    let metadata_content = Big_map.update "content" (Some param) storage.metadata in
    ([] : operation list), { storage with metadata = metadata_content }

let mint (param, storage : mint * storage): result =
  if (Tezos.get_sender()) <> storage.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%mint" sender_address : mint contract option) with
      | None -> (failwith("no mint entrypoint") : operation list)
      | Some mint_entrypoint -> [Tezos.transaction param 0mutez mint_entrypoint] in
    (prepare_multisig "mint" param func storage), storage
  else
    let new_to_balance =
        match Big_map.find_opt param.address_to storage.ledger with
        | Some value -> value + param.value
        | None -> param.value in
    let new_ledger = Big_map.update param.address_to (Some new_to_balance) storage.ledger in

    let new_total_supply = storage.total_supply + param.value in
    (([] : operation list), { storage with ledger = new_ledger; total_supply = new_total_supply})



let burn (param, storage : burn * storage): result =
  if storage.burn_paused = true then
    (failwith("burn in pause") : result)
  else
    let allowances = storage.allowances in
    let ledger = storage.ledger in

    let new_allowances =
      if (Tezos.get_sender()) = param.address_from then allowances
      else
        let allowance_key = { owner = param.address_from ; spender = (Tezos.get_sender()) } in
        let authorized_value = match Big_map.find_opt allowance_key allowances with
          | Some value -> value
          | None -> 0n in
        let authorized_value = match is_nat (authorized_value - param.value) with
          | None -> (failwith "NotEnoughAllowance" : nat)
          | Some authorized_value -> authorized_value in
        Big_map.update allowance_key (positive authorized_value) allowances in

    let new_ledger =
      let from_balance = match Big_map.find_opt param.address_from ledger with
        | Some value -> value
        | None -> 0n in
      let new_from_balance = match is_nat (from_balance - param.value) with
        | None -> (failwith "NotEnoughBalance" : nat)
        | Some new_from_balance -> new_from_balance in
      Big_map.update param.address_from (positive new_from_balance) ledger in

    let new_total_supply =
      match is_nat (storage.total_supply - param.value) with
      | None -> (failwith "NotEnoughBalance" : nat)
      | Some new_total_supply -> new_total_supply in
    (([] : operation list), { storage with ledger = new_ledger; total_supply = new_total_supply; allowances = new_allowances })

let main (param, storage : parameter * storage) : result =
  begin
    if (Tezos.get_amount()) <> 0mutez
      then failwith "DontSendTez"
    else ();
    match param with
    | Transfer param -> ([] : operation list), transfer (param, storage)
    | TransferBatch param -> transfer_batch (param, storage)
    | Approve param -> approve (param, storage)
    | Burn param -> burn (param, storage)
    | Mint param -> mint (param, storage)
    | GetAllowance param -> get_allowance (param, storage)
    | GetBalance param -> get_balance (param, storage)
    | GetTotalSupply param -> get_total_supply (param, storage)
    | SetPause param -> set_pause (param, storage)
    | SetBurnPause param -> set_burn_pause (param, storage)
    | SetMultisig param -> set_multisig (param, storage)
    | SetTokenMetadata param -> set_token_metadata (param, storage)
    | SetMetadata param-> set_metadata (param, storage)
  end

[@view] let get_balance_view (owner, store : address * storage) : nat =
    let balance = Big_map.find_opt owner store.ledger in
    match balance with 
    | None -> 0n
    | Some n -> n
