let withdraw_counter_offer (param : withdraw_counter_offer_param) (store : storage) : return =
  if store.paused then
    (failwith(error_MARKETPLACE_IS_PAUSED) : return)
  else
    let offer_id =
      {
        token_id = param.token_id;
        buyer = param.buyer;
        token_origin = param.token_origin;
      } in
    let counter_offer_id =
      {
        token_id = param.token_id;
        buyer = param.buyer;
        seller = (Tezos.get_sender ());
        token_origin = param.token_origin;
      } in
    let offer = 
      match Big_map.find_opt offer_id store.offers with
      | None -> (failwith(error_NO_OFFER_PLACED) : offer_info)
      | Some offer -> offer in
    if (not Big_map.mem counter_offer_id store.counter_offers) then
      (failwith(error_NO_COUNTER_OFFER) : return)
    else
      let op =
        token_transfer 
            offer.origin 
            [
              {
                from_ = (Tezos.get_self_address ()); 
                txs = 
                  [
                    { 
                      to_ = (Tezos.get_sender ()); 
                      token_id = param.token_id; 
                      amount = offer.token_amount 
                    }
                  ]
              }
            ]
        in
        let new_counter_offers = Big_map.update counter_offer_id (None : counter_offer option) store.counter_offers in
        [op], { store with counter_offers = new_counter_offers }