let send_offer (param : offer_param) (store : storage) : return =
  if store.paused then
    (failwith(error_MARKETPLACE_IS_PAUSED) : return)
  else if param.start_time > param.end_time then
    (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return)
  else
    let offer_id = 
      {
        buyer = (Tezos.get_sender ());
        token_id = param.token_id;
        token_origin = param.token_origin;
      } in
    match Big_map.find_opt offer_id store.offers with
    | Some _ -> (failwith(error_OFFER_ALREADY_PLACED) : return)
    | None ->
      let ft_amount =
        if param.token_symbol = "XTZ" then
          if param.ft_amount <> mutez_to_natural (Tezos.get_amount ()) then
            (failwith(error_OFFER_VALUE_IS_NOT_EQUAL_TO_XTZ_AMOUNT) : nat)
          else
            mutez_to_natural (Tezos.get_amount ())
        else param.ft_amount in
      let new_offer = {
        token_amount = param.token_amount;
        value = ft_amount;
        start_time = param.start_time;
        end_time = param.end_time;
        origin = param.token_origin;
        token_symbol = param.token_symbol;
        } in
      let new_offers = Big_map.update offer_id (Some new_offer) store.offers in
      let ops = ([] : operation list) in
      let ops =
        if param.token_symbol = "XTZ" then
          ops
        else
          match Big_map.find_opt param.token_symbol store.allowed_tokens with
          | None -> (failwith(error_TOKEN_INDEX_UNLISTED) : operation list)
          | Some fun_t -> [fa12_transfer fun_t.fa12_address (Tezos.get_sender ()) (Tezos.get_self_address ()) ft_amount] in
      ops, {store with offers = new_offers}