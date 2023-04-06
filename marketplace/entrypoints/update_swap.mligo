let update_swap (param : update_swap_param) (store : storage) : return =
  if store.paused then
    (failwith error_MARKETPLACE_IS_PAUSED : return)
  else
    let swap =
      match Big_map.find_opt param.swap_id store.swaps with
      | None -> (failwith(error_SWAP_ID_DOES_NOT_EXIST) : swap_info)
      | Some swap -> swap in
    if (Tezos.get_sender ()) <> swap.owner then
      (failwith(error_ONLY_OWNER_CAN_CALL_THIS_ENTRYPOINT) : return)
    else match param.action with
    | Add_amount token_amount ->
    if token_amount = 0n then
      (failwith(error_NO_ZERO_TOKEN_AMOUNT_ALLOWED) : return)
    else if swap.is_dutch && (Tezos.get_now ()) >= swap.start_time then
      (failwith(error_DUTCH_AUCTION_ACTIVE) : return)
    else
      let op = token_transfer swap.origin [{ from_ = (Tezos.get_sender ()); txs = [{ to_ = (Tezos.get_self_address ()); token_id = swap.token_id; amount = token_amount }]}] in
      let new_swaps = Big_map.update param.swap_id (Some {swap with token_amount = swap.token_amount + token_amount}) store.swaps in
      [op], {store with swaps = new_swaps}
    | Reduce_amount token_amount ->
    if token_amount = 0n then
      (failwith(error_NO_ZERO_TOKEN_AMOUNT_ALLOWED) : return)
    else if swap.is_dutch && (Tezos.get_now ()) >= swap.start_time then
      (failwith(error_DUTCH_AUCTION_ACTIVE) : return)
    else
      let new_token_amount =
        match is_a_nat (swap.token_amount - token_amount) with
        | None -> (failwith(error_INSUFFICIENT_TOKEN_BALANCE) : nat)
        | Some n -> n in
      let op = token_transfer swap.origin [{ from_ = (Tezos.get_self_address ()); txs = [{ to_ = (Tezos.get_sender ()); token_id = swap.token_id; amount = token_amount }]}] in
      let (new_swaps, new_tokens) =
        if new_token_amount <> 0n then
          (Big_map.update param.swap_id (Some {swap with token_amount = new_token_amount}) store.swaps,
          store.tokens)
        else
          (Big_map.update param.swap_id (None : swap_info option) store.swaps,
          Big_map.update (swap.token_id, (Tezos.get_sender ())) (None : swap_id option) store.tokens) in
      [op], {store with swaps = new_swaps; tokens = new_tokens}
    | Update_price price ->
    if swap.is_dutch && (Tezos.get_now ()) >= swap.start_time then
      (failwith(error_DUTCH_AUCTION_ACTIVE) : return)
    else
      let new_swaps = Big_map.update param.swap_id (Some {swap with token_price = price}) store.swaps in
      ([] : operation list), { store with swaps = new_swaps }
    | Update_times p ->
    if p.start_time >= p.end_time then
      (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return)
    else if swap.is_dutch && (Tezos.get_now ()) >= swap.start_time then
      (failwith(error_DUTCH_AUCTION_ACTIVE) : return)
    else
      let new_swaps = Big_map.update param.swap_id (Some { swap with start_time = p.start_time; end_time = p.end_time }) store.swaps in
      ([] : operation list), { store with swaps = new_swaps }
    | Update_reserved_address p ->
    let new_swaps = Big_map.update param.swap_id (Some {swap with recipient = p; is_reserved = true}) store.swaps in
    ([] : operation list), { store with swaps = new_swaps }
    | Update_duration p ->
    if swap.is_dutch = false || (swap.is_dutch && (Tezos.get_now ()) >= swap.start_time) then
      (failwith(error_CAN_NOT_UPDATE_DURATION_FOR_THIS_SWAP) : return)
    else
      let new_swaps = Big_map.update param.swap_id (Some { swap with duration = int p }) store.swaps in
      ([] : operation list), {store with swaps = new_swaps}
    | Update_starting_price p ->
    if swap.is_dutch = false || (swap.is_dutch && (Tezos.get_now ()) >= swap.start_time) then
      (failwith(error_CAN_NOT_UPDATE_STARTING_PRICE_FOR_THIS_SWAP) : return)
    else
      let new_swaps = Big_map.update param.swap_id (Some { swap with starting_price = p }) store.swaps in
      ([] : operation list), {store with swaps = new_swaps}