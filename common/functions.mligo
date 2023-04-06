#if !COMMON_HELPERS
#define COMMON_HELPERS

[@inline]
let is_a_nat (i : int) : nat option = is_nat i

[@inline]
let mutez_to_natural (a: tez) : nat =  a / 1mutez

[@inline]
let natural_to_mutez (a: nat): tez = a * 1mutez

[@inline]
let maybe (n : nat) : nat option =
  if n = 0n
  then (None : nat option)
  else Some n

let maybe_swap (n : nat) (swap : swap_info) : swap_info option =
  if n = 0n then
    (None : swap_info option)
  else (Some {swap with token_amount = n})

[@inline] let calculate_price (start_time, duration, starting_price, token_price : timestamp * int * nat * nat) : nat =
  match is_a_nat ((start_time + duration) - (Tezos.get_now ())) with
  | None -> token_price
  | Some t -> t * abs (starting_price - token_price)/ abs duration + token_price

[@inline] let assert_with_code (condition : bool) (code : nat) : unit =
  if (not condition) then failwith(code)
  else ()

[@inline] let find_royalties (origin : address) (token_id : token_id) (store : storage) : royalties_info =
  if origin <> store.nft_address then
    {
      issuer = (Tezos.get_self_address ());
      royalties = 0n;
    }
  else
    match (Tezos.call_view "get_royalties" token_id store.royalties_address : royalties_info option) with
    | None -> (failwith("no royalties") : royalties_info)
    | Some r -> r 

[@inline] let find_nft_type (origin : address) (store : storage) : royalties_info =
  if origin <> store.nft_address then
    {
      issuer = (Tezos.get_self_address ());
      royalties = 0n;
    }
  else
    match (Tezos.call_view "get_royalties" token_id store.royalties_address : royalties_info option) with
    | None -> (failwith("no royalties") : royalties_info)
    | Some r -> r 



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

let convert_tokens (input_token : token_symbol) (input_amount : nat) (output_token : token_symbol) (store : storage) : nat =
  if input_token = output_token then
    input_amount
  else
  (* 
    The harbinger normalizer contract converts from all currencies only to USD
    we have to handle different cases differently:
    1: conversion fits the direct conversion cases of harbinger (XTZ-USD, ETH-USD, etc)
    2: conversion is the opposite of direct conversion cases of harbinger (USD-XTZ, USD-ETH, etc)
    3: conversion is between two currencies different than USD (XTZ-ETH, ETH-XTZ, etc)
 *)
    let (first_pair, first_ordered, second_pair) =
      if output_token = "USD" then
      (* case 1 *)
        match Big_map.find_opt (input_token, output_token) store.available_pairs with
        | None ->  (failwith(error_NO_AVAILABLE_CONVERSION_RATE) : string * bool * string)
        | Some pair -> (pair, true, "")
      else if input_token = "USD" then
      (* case 2 *)
        match Big_map.find_opt (output_token, input_token) store.available_pairs with
        | None -> (failwith(error_NO_AVAILABLE_CONVERSION_RATE) : string * bool * string)
        | Some pair -> (pair, false, "")
      else
      (* case 3 *)
        let first = 
          match Big_map.find_opt (input_token, "USD") store.available_pairs with
          | None -> (failwith(error_NO_AVAILABLE_CONVERSION_RATE) : string)
          | Some pair -> pair in
        let second = 
          match Big_map.find_opt (output_token, "USD") store.available_pairs with
          | None -> (failwith(error_NO_AVAILABLE_CONVERSION_RATE) : string)
          | Some pair -> pair in
        (first, true, second) in

    (* convert according to the different 5 cases *)
    let output_amount =
      let mu = 1_000_000n in
      if second_pair = "" then
      (* cases 1 & 2 *)
        let _, conversion_rate =
          match (Tezos.call_view "getPrice" first_pair store.oracle : (timestamp * nat) option) with
          | None -> (failwith(error_ORACLE_FAILED_TO_SUPPLY_CONVERSION_RATE) : timestamp * nat)
          | Some value -> value in
          if first_ordered then
          (* case 1 *)
            input_amount * conversion_rate / mu
          else
          (* case 2 *)
            input_amount * mu / conversion_rate
      else
      (* case 3 *)
        let _, first_conversion_rate =
          match (Tezos.call_view "getPrice" first_pair store.oracle : (timestamp * nat) option) with
          | None -> (failwith(error_ORACLE_FAILED_TO_SUPPLY_CONVERSION_RATE) : timestamp * nat)
          | Some value -> value in
        let _, second_conversion_rate =
          match (Tezos.call_view "getPrice" second_pair store.oracle : (timestamp * nat) option) with
          | None -> (failwith(error_ORACLE_FAILED_TO_SUPPLY_CONVERSION_RATE) : timestamp * nat)
          | Some value -> value in
          input_amount * first_conversion_rate / second_conversion_rate in
    output_amount

let find_fa12 (symbol : token_symbol) (store : storage) : address =
  let addr = match Big_map.find_opt symbol store.allowed_tokens with
  | None -> (failwith(error_TOKEN_INDEX_UNLISTED) : address)
  | Some token -> token.fa12_address in
  addr

[@inline]
let fa12_transfer (fa12_address : address) (from_ : address) (to_ : address) (value : nat) : operation =
  let fa12_contract : fa12_contract_transfer contract =
    match (Tezos.get_entrypoint_opt "%transfer" fa12_address : fa12_contract_transfer contract option) with
    | None -> (failwith(error_FA12_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT) : fa12_contract_transfer contract)
    | Some contract -> contract in
    let transfer = {address_from = from_; address_to = to_; value = value} in
    Tezos.transaction transfer 0mutez fa12_contract

[@inline]
let handout_op (ops : operation list) (value : nat) (symbol : token_symbol) (fa12_address : address) (from_ : address) (to_ : address) : operation list =
  if value > 0n then
      let ops =
        if symbol = "XTZ" then
          xtz_transfer to_ (natural_to_mutez value) :: ops
        else
          fa12_transfer fa12_address from_ to_ value :: ops in
      ops
  else
    ops


(* used to transfer management fees to treasury contract *)
let handout_fee_op (ops : operation list) (value : nat) (symbol : token_symbol) (fa12_address : address) (from_ : address) (to_ : address) : operation list =
  if value > 0n then
      match (Tezos.get_entrypoint_opt "%deposit" to_ : deposit_param contract option) with
      | None -> (failwith("wrong treasury contract") : operation list)
      | Some contr -> 
        let deposit = 
        {
          token = symbol;
          fa12_address = fa12_address;
          token_amount = value;
        } in
        let ops = 
          if symbol = "XTZ" then
            Tezos.transaction deposit (natural_to_mutez value) contr :: ops
          else
            let ops = fa12_transfer fa12_address from_ to_ value :: ops in
            let ops = Tezos.transaction deposit 0tez contr :: ops in
            ops in
        ops
  else
    ops

let set_pause (param : bool) (store : storage) : return =
  let sender_address = (Tezos.get_self_address ()) in
  if (Tezos.get_sender ()) <> store.multisig then
        let func () =
          match (Tezos.get_entrypoint_opt "%setPause" sender_address : bool contract option) with
          | None -> (failwith("no setPause entrypoint") : operation list)
          | Some set_pause_entrypoint -> [Tezos.transaction param 0mutez set_pause_entrypoint] in
      (prepare_multisig "setPause" param func store), store
    else
    ([] : operation list), {store with paused = param}

let update_fee (param : update_fee_param) (store : storage) : return =
    if (Tezos.get_sender ()) <> store.multisig then
      let sender_address = (Tezos.get_self_address ()) in
      let func () =
        match (Tezos.get_entrypoint_opt "%updateFee" sender_address : update_fee_param contract option) with
          | None -> (failwith("no updateFee entrypoint") : operation list)
          | Some update_fee_entrypoint ->
            [Tezos.transaction param 0mutez update_fee_entrypoint]
        in
        (prepare_multisig "updateFee" param func store), store
    else
        ([] : operation list), { store with management_fee_rate = param }

let update_nft_address (param : update_nft_address_param) (store : storage) : return =
  if (Tezos.get_sender ()) <> store.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%updateNftAddress" sender_address : update_nft_address_param contract option) with
        | None -> (failwith("no updateNftAddress entrypoint") : operation list)
        | Some update_nft_entrypoint ->
          [Tezos.transaction param 0mutez update_nft_entrypoint]
      in
      (prepare_multisig "updateNftAddress" param func store), store
  else
    ([] : operation list), { store with nft_address = param }

let update_multisig_address (param : address) (store : storage) : return =
  if (Tezos.get_sender ()) <> store.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%updateMultisigAddress" sender_address : address contract option) with
        | None -> (failwith("no updateMultisigAddress entrypoint") : operation list)
        | Some update_mutisig_entrypoint ->
          [Tezos.transaction param 0mutez update_mutisig_entrypoint]
      in
      (prepare_multisig "updateMultisigAddress" param func store), store
  else
    ([] : operation list), { store with multisig = param }

let update_royalties_address (param : update_royalties_address_param) (store : storage) : return =
  if (Tezos.get_sender ()) <> store.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%updateRoyaltiesAddress" sender_address : update_royalties_address_param contract option) with
        | None -> (failwith("no updateRoyaltiesAddress entrypoint") : operation list)
        | Some update_royalties_entrypoint ->
          [Tezos.transaction param 0mutez update_royalties_entrypoint]
      in
      (prepare_multisig "updateNftAddress" param func store), store
  else
    ([] : operation list), { store with royalties_address = param }

let update_oracle_address (param : address) (store : storage) : return =
  if (Tezos.get_sender ()) <> store.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%updateOracleAddress" sender_address : address contract option) with
        | None -> (failwith("no updateOracleAddress entrypoint") : operation list)
        | Some update_oracle_entrypoint ->
          [Tezos.transaction param 0mutez update_oracle_entrypoint]
      in
      (prepare_multisig "updateOracleAddress" param func store), store
  else
    ([] : operation list), { store with oracle = param }

let update_allowed_tokens (param : update_allowed_tokens_param) (store : storage) : return =
  if (Tezos.get_sender ()) <> store.multisig then
    let sender_address = (Tezos.get_self_address ()) in
    let func () =
      match (Tezos.get_entrypoint_opt "%updateAllowedTokens" sender_address : update_allowed_tokens_param contract option) with
        | None -> (failwith("no updateAllowedTokens entrypoint") : operation list)
        | Some update_allowed_tokens_entrypoint ->
          [Tezos.transaction param 0mutez update_allowed_tokens_entrypoint]
      in
      (prepare_multisig "updateAllowedTokens" param func store), store
  else
    match param.direction with
    | Remove_token ->
      let new_allowed_tokens = Big_map.update param.token_symbol (None : fun_token option) store.allowed_tokens in
      let new_available_pairs = Big_map.update (param.token_symbol, "USD") (None : string option) store.available_pairs in
      ([] : operation list), {store with allowed_tokens = new_allowed_tokens; available_pairs = new_available_pairs}
    | Add_token fa12_address ->
      let fun_token = 
        {
          fa12_address = fa12_address; 
          token_symbol = param.token_symbol
        } in
      if Big_map.mem param.token_symbol store.allowed_tokens then
        (failwith(error_TOKEN_INDEX_LISTED) : return)
      else if Big_map.mem (param.token_symbol, "USD") store.available_pairs then
        (failwith(error_PAIR_ALREADY_EXISTS) : return)
      else
        let new_allowed_tokens = Big_map.update param.token_symbol (Some fun_token) store.allowed_tokens in
        let pair = param.token_symbol ^ "-USD" in
        let new_available_pairs = Big_map.update (param.token_symbol, "USD") (Some pair) store.available_pairs in
        ([] : operation list), {store with allowed_tokens = new_allowed_tokens; available_pairs = new_available_pairs}

#endif
