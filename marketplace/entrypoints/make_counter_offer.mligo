let make_counter_offer (param : counter_offer_param) (store : storage) : return =
  if store.paused then
    (failwith(error_MARKETPLACE_IS_PAUSED) : return)
  else if param.start_time >= param.end_time then
    (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return)
  else if param.end_time = (0 : timestamp) then
    (failwith(error_END_TIME_CANNOT_BE_ZERO) : return)
  else
    let counter_offer_id =
    {
      token_id = param.token_id;
      buyer = param.buyer;
      seller = (Tezos.get_sender ());
      token_origin = param.token_origin;
    } in
    let counter_offer =
      match Big_map.find_opt counter_offer_id store.counter_offers with
      | Some _ -> (failwith(error_COUNTER_OFFER_ALREADY_EXISTS) : counter_offer)
      | None -> 
        {
          start_time = param.start_time;
          end_time = param.end_time;
          token_symbol = param.token_symbol;
          ft_amount = param.ft_amount;
          owner = (Tezos.get_sender ());
        } in
    let offer_id =
      {
        token_id = param.token_id;
        buyer = param.buyer;
        token_origin = param.token_origin;
      } in
    let offer = 
      match Big_map.find_opt offer_id store.offers with
      | None -> (failwith(error_NO_OFFER_PLACED) : offer_info)
      | Some offer -> offer in
      let op = 
        (
          token_transfer
            offer.origin
            [
              {
                from_ = (Tezos.get_sender ());
                txs =
                  [
                    {
                      to_ = (Tezos.get_self_address ());
                      token_id = param.token_id;
                      amount = offer.token_amount;
                    }
                  ]
              }
            ]
        ) in 
      let new_counter_offers = Big_map.update counter_offer_id (Some counter_offer) store.counter_offers in
      let new_store = { store with counter_offers = new_counter_offers } in
      [op], new_store