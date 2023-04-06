let update_offer (param : offer_param) (store : storage) : return =
  if store.paused then
    (failwith(error_MARKETPLACE_IS_PAUSED) : return)
  else if (not (param.token_symbol = "XTZ")) && (Tezos.get_amount ()) <> 0tez then
    (failwith(error_NO_XTZ_AMOUNT_TO_BE_SENT) : return)
  else if param.start_time > param.end_time then
    (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return)
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
      let new_offer = {offer with
            token_amount = param.token_amount;
            value = param.ft_amount;
            start_time = param.start_time;
            end_time = param.end_time;
            origin = param.token_origin;
            token_symbol = param.token_symbol;
            } in

      (* we have to take care of different cases and subcases:
    1: incoming token_symbol is the same as the former token_symbol.
    1.1: if token_symbol is "XTZ": we return the former value.
    1.2: other token_symbol (requires fa12 transfer)
    1.2.1: if the new offer is higher: incoming_amount will be sent, no outgoing_amount.
    1.2.2: if the new offer is lower: no incoming_amount, outgoing_amount will be sent.
    2: incoming token_symbol is not the same as outgoing token_symbol.
    2.1: incoming_symbol is "XTZ": no incoming_amount, outgoing_amount will be sent.
    2.2: outgoing_symbol is "XTZ": incoming_amount will be sent, outgoing_amount will be sent.
    2.3: both symbols are not "XTZ": incoming amount will be sent, outgoing_amount will be sent.
    (2.2 and 2.3 are the same, but need to be treated differently at transfers) *)
      let ops = ([] : operation list) in
      let ops =
        (* 1 *)
        if param.token_symbol = offer.token_symbol then
          (* 1.1 *)
          if param.token_symbol = "XTZ" then
            (* check that values are valid *)
            if mutez_to_natural (Tezos.get_amount ()) <> param.ft_amount then
              (failwith(error_OFFER_VALUE_IS_NOT_EQUAL_TO_XTZ_AMOUNT) : operation list)
            else
              [xtz_transfer (Tezos.get_sender ()) (natural_to_mutez offer.value)]
          else
            let fa12_address = find_fa12 param.token_symbol store in
            (* 1.2 *)
            match is_a_nat (param.ft_amount - offer.value) with
            | None -> [fa12_transfer fa12_address (Tezos.get_self_address ()) (Tezos.get_sender ()) (abs (param.ft_amount - offer.value))]
            | Some n -> if n <> 0n then [fa12_transfer fa12_address (Tezos.get_sender ()) (Tezos.get_self_address ()) n] else ops
        else
          (* 2.1 *)
            let fa12_address_out = find_fa12 offer.token_symbol store in
            let fa12_address_in = find_fa12 param.token_symbol store in
          if param.token_symbol = "XTZ" then
            [fa12_transfer fa12_address_out (Tezos.get_self_address ()) (Tezos.get_sender ()) offer.value]
          else if offer.token_symbol = "XTZ" then
            [fa12_transfer fa12_address_in (Tezos.get_sender ()) (Tezos.get_self_address ()) param.ft_amount; xtz_transfer (Tezos.get_sender ()) (natural_to_mutez offer.value)]
          else
            let op_out = fa12_transfer fa12_address_out (Tezos.get_self_address ()) (Tezos.get_sender ()) offer.value in
            let op_in = fa12_transfer fa12_address_in (Tezos.get_sender ()) (Tezos.get_self_address ()) param.ft_amount in
            (* 2.2 and 2.3 *)
            [op_out; op_in] in
      let new_offers = Big_map.update offer_id (Some new_offer) store.offers in
      ops, {store with offers = new_offers}