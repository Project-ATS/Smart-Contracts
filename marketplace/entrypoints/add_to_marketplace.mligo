let add_to_marketplace (param : add_to_marketplace_param) (store : storage) : return =
  if store.paused then
    (failwith error_MARKETPLACE_IS_PAUSED : return)
  else
    let swap_id =
      match Big_map.find_opt (param.token_id, (Tezos.get_sender ())) store.tokens with
      | Some _swap_id -> (failwith(error_TOKEN_IS_ALREADY_ON_SALE) : swap_id)
      | None -> store.next_swap_id in
  if param.start_time >= param.end_time then
    (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return)
  else if (not param.is_multi_token) && (not Set.mem param.token_symbol store.single_tokens) then
    (failwith(error_ONLY_XTZ_OR_TOKEN_CAN_BE_CHOSEN) : return)
  else
    let _ = Set.iter (fun (symbol : string) ->
      assert_with_code (Big_map.mem symbol store.allowed_tokens) error_TOKEN_LIST_INVALID ) param.accepted_tokens in
    let payment_token =
      match Big_map.find_opt param.token_symbol store.allowed_tokens with
      | None ->
        (failwith(error_TOKEN_INDEX_UNLISTED) : string)
      | Some t -> t.token_symbol in
    let (starting_price, duration, is_dutch) =
      match param.swap_type with
      | Regular -> (param.token_price, 0, false)
      | Dutch p ->
        if int p.duration > param.end_time - param.start_time then
          (failwith(error_DURATION_IS_LONGER_THAN_SWAP_DURATION) : (nat * int * bool))
        else
          (p.starting_price, int p.duration, true)
      in
    let (recipient, is_reserved) =
      match param.recipient with
      | Reserved p -> (p, true)
      | General -> ((Tezos.get_self_address ()), false)
      in
    if param.token_amount = 0n then
      (failwith(error_NO_ZERO_TOKEN_AMOUNT_ALLOWED) : return)
    else
      let op =
      (
        token_transfer
          param.token_origin
          [
            {
              from_ = (Tezos.get_sender ());
              txs =
                [
                  {
                    to_ = (Tezos.get_self_address ());
                    token_id = param.token_id;
                    amount = param.token_amount;
                  }
                ]
            }
          ]
      ) in
      let ops = [op] in
      let new_swaps =
          Big_map.update swap_id (Some {
          owner = (Tezos.get_sender ());
          token_id = param.token_id;
          is_dutch = is_dutch;
          is_reserved = is_reserved;
          starting_price = starting_price;
          token_price = param.token_price;
          start_time = param.start_time;
          duration = duration;
          end_time = param.end_time;
          token_amount = param.token_amount;
          origin = param.token_origin;
          recipient = recipient;
          ft_symbol = payment_token;
          accepted_tokens = if (not param.is_multi_token) then Set.literal [payment_token] else param.accepted_tokens;
          is_multi_token = param.is_multi_token;
          }) store.swaps in
      let new_tokens =
        Big_map.update (param.token_id, (Tezos.get_sender ())) (Some swap_id) store.tokens in
      let new_store =
        {
          store with
          next_swap_id = store.next_swap_id + 1n;
          swaps = new_swaps;
          tokens = new_tokens;
        } in
      ops, new_store