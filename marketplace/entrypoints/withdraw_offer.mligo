let withdraw_offer (param : withdraw_offer_param) (store : storage) : return =
  if store.paused then
    (failwith(error_MARKETPLACE_IS_PAUSED) : return)
  else
    let offer_id =
        {
          token_id = param.token_id;
          buyer = (Tezos.get_sender ());
          token_origin = param.token_origin;
        } in
    match Big_map.find_opt offer_id store.offers with
    | None -> (failwith(error_NO_OFFER_PLACED) : return)
    | Some offer ->
      let op =
        if offer.token_symbol = "XTZ" then
          xtz_transfer (Tezos.get_sender ()) (natural_to_mutez offer.value)
        else
          let fa12_address =
            match Big_map.find_opt offer.token_symbol store.allowed_tokens with
            | None -> (failwith(error_TOKEN_INDEX_UNLISTED) : address)
            | Some token -> token.fa12_address in
          fa12_transfer fa12_address (Tezos.get_self_address ()) (Tezos.get_sender ()) offer.value in
      let new_offers = Big_map.update offer_id (None : offer_info option) store.offers in
      let new_store = { store with offers = new_offers } in
      [op], new_store