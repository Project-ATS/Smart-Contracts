let remove_from_marketplace (swap_id : remove_from_marketplace_param) (store : storage) : return =
  if store.paused then
    (failwith error_MARKETPLACE_IS_PAUSED : return)
  else
    let swap =
      match Big_map.find_opt swap_id store.swaps with
      | None -> (failwith error_SWAP_ID_DOES_NOT_EXIST : swap_info)
      | Some swap_info -> swap_info in
    if (Tezos.get_sender ()) <> swap.owner then
      (failwith error_ONLY_OWNER_CAN_REMOVE_FROM_MARKETPLACE : return)
    else
      let token_id = swap.token_id in
      let token_amount = swap.token_amount in
      let op = token_transfer swap.origin [{ from_ = (Tezos.get_self_address ()); txs = [{ to_ = (Tezos.get_sender ()); token_id = token_id; amount = token_amount }]}] in
      let (new_swaps, new_tokens) =
          (Big_map.update swap_id (None : swap_info option) store.swaps,
          Big_map.update (token_id, (Tezos.get_sender ())) (None : swap_id option) store.tokens) in
      let new_store = { store with swaps = new_swaps; tokens = new_tokens } in
      [op], new_store