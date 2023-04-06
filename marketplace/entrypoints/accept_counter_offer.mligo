let accept_counter_offer (param : accept_counter_offer_param) (store : storage) : return =
  if store.paused then
    (failwith(error_MARKETPLACE_IS_PAUSED) : return)
  else
    let offer_id =
      {
        token_id = param.token_id;
        buyer = (Tezos.get_sender ());
        token_origin = param.token_origin;
      } in
    let counter_offer_id =
      {
        token_id = param.token_id;
        buyer = (Tezos.get_sender ());
        seller = param.seller;
        token_origin = param.token_origin;
      } in
    let (offer, new_offers) = 
      match Big_map.find_opt offer_id store.offers with
      | None -> (failwith(error_NO_OFFER_PLACED) : offer_info * (offer_id, offer_info) big_map)
      | Some offer -> offer, Big_map.update offer_id (None : offer_info option) store.offers in
    let (counter_offer, new_counter_offers) =
      match Big_map.find_opt counter_offer_id store.counter_offers with
      | None -> (failwith(error_NO_COUNTER_OFFER) : counter_offer * (counter_offer_id, counter_offer) big_map)
      | Some countof -> countof, Big_map.update counter_offer_id (None : counter_offer option) store.counter_offers in
    if (Tezos.get_now ()) < counter_offer.start_time then
      (failwith(error_COUNTER__OFFER_IS_TOO_EARLY) : return)
    else if (Tezos.get_now ()) > counter_offer.end_time then
      (failwith(error_COUNTER__OFFER_IS_TOO_LATE) : return)
    else if counter_offer.token_symbol = "XTZ" && mutez_to_natural (Tezos.get_amount ()) <> counter_offer.ft_amount then
      (failwith(error_AMOUNT_IS_NOT_EQUAL_TO_PRICE) : return)
    else 
    // return original offer to buyer
      let ops = ([] : operation list) in
      let ops =
        if offer.token_symbol = "XTZ" then
          xtz_transfer (Tezos.get_sender ()) (natural_to_mutez offer.value) :: ops
        else
          let fa12_address = find_fa12 offer.token_symbol store in
          fa12_transfer fa12_address (Tezos.get_self_address ()) (Tezos.get_sender ()) offer.value :: ops in
    // get transaction details
      let royalties_info = find_royalties offer.origin param.token_id store in
      let token_amount = offer.token_amount in
      let management_fee = counter_offer.ft_amount * store.management_fee_rate / const_FEE_DENOM in
      let royalties = royalties_info.royalties * counter_offer.ft_amount / const_FEE_DENOM in
      let seller_value =
        match is_a_nat (counter_offer.ft_amount - (management_fee + royalties)) with
        | None -> (failwith error_FEE_GREATER_THAN_AMOUNT : nat)
        | Some n -> n in
      (* operation assignment *)
      (* token transfer *)
      let ops = 
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
                    amount = token_amount 
                  }
                ]
            }
          ] :: ops in
      let new_store =
        { store with
          offers = new_offers;
          counter_offers = new_counter_offers;
        } in
      (* payment transfers *)
      let fa12_address = find_fa12 counter_offer.token_symbol store in
      let ops = handout_op ops seller_value counter_offer.token_symbol fa12_address (Tezos.get_sender ()) param.seller in
      let ops = handout_op ops royalties counter_offer.token_symbol fa12_address (Tezos.get_sender ()) royalties_info.issuer in
      let ops = handout_fee_op ops management_fee counter_offer.token_symbol fa12_address (Tezos.get_sender ()) store.treasury in
      (ops, new_store)