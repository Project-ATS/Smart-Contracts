let accept_offer (param : accept_offer_param) (store : storage) : return =
  if store.paused then
    (failwith(error_MARKETPLACE_IS_PAUSED) : return)
  else
    let (owner, buyer, token_id) = ((Tezos.get_sender ()), param.buyer, param.token_id) in
    let offer_id = 
      {
          token_id = token_id;
          buyer = buyer;
          token_origin = param.token_origin;
      } in
    let offer =
      match Big_map.find_opt offer_id store.offers with
      | None -> (failwith(error_OFFER_DOES_NOT_EXIST) : offer_info)
      | Some offer -> offer in
    if (Tezos.get_now ()) < offer.start_time then
      (failwith error_ACCEPTING_OFFER_IS_TOO_EARLY : return)
    else
    if (Tezos.get_now ()) > offer.end_time then
      (failwith error_ACCEPTING_OFFER_IS_TOO_LATE : return)
    else
      let royalties_info = find_royalties offer.origin token_id store in
      let token_amount = offer.token_amount in
      let management_fee = offer.value * store.management_fee_rate / const_FEE_DENOM in
      let royalties = royalties_info.royalties * offer.value / const_FEE_DENOM in
      let seller_value =
        match is_a_nat (offer.value - (management_fee + royalties)) with
        | None -> (failwith error_FEE_GREATER_THAN_AMOUNT : nat)
        | Some n -> n in
      (* transfer tokens first from marketplace.
      if there are not enough tokens on marketplace, transfer from nft *)
      let swap_id =
        match Big_map.find_opt (token_id, owner) store.tokens with
        (* dummy swap id *)
        | None -> store.next_swap_id + 1n
        (* real swap id *)
        | Some swap_id -> swap_id in
      let swap =
        match Big_map.find_opt swap_id store.swaps with
            (* dummy swap *)
            | None -> {
              owner = (Tezos.get_self_address ());
              token_id = 0n;
              is_dutch = false;
              is_reserved = false;
              starting_price = 0n;
              token_price = 0n;
              start_time = (Tezos.get_now ());
              duration = 0;
              end_time = (Tezos.get_now ());
              token_amount = 0n;
              origin = offer.origin;
              recipient = (Tezos.get_self_address ());
              accepted_tokens = (Set.empty : string set);
              ft_symbol = offer.token_symbol;
            }
            (* real swap *)
            | Some swap -> swap in
      (* token assignment *)
      if (Tezos.get_source ()) <> swap.owner && (Tezos.get_source ()) <> owner then
        (failwith(error_CALLER_NOT_PERMITTED_TO_ACCEPT_OFFER) : return)
      else
      let (marketplace_tokens, owner_tokens, new_swaps, new_tokens) =
        match is_a_nat (swap.token_amount - token_amount) with
        (* transfer only from marketplace *)
        | Some n ->
          if n = 0n then
            (token_amount,
            0n,
            Big_map.update swap_id (maybe_swap n swap) store.swaps,
            Big_map.update (token_id, owner) (maybe n) store.tokens)
          else
            (token_amount,
            0n,
            Big_map.update swap_id (Some {swap with token_amount = n}) store.swaps,
            store.tokens)
        (* transfer from marketplace (if tokens exist on swap) and from owner account on nft *)
        | None ->
          (swap.token_amount,
          abs (token_amount - swap.token_amount),
          Big_map.update swap_id (None : swap_info option) store.swaps,
          Big_map.update (token_id, owner) (None : swap_id option) store.tokens) in
      (* operation assignment *)
      let ops = ([] : operation list) in
      (* token transfers *)
      let txs = ([] : transfer list) in
      let txs =
        if owner_tokens > 0n then
          {from_ = owner; txs = [{ to_ = buyer; token_id = token_id; amount = owner_tokens }]} :: txs
        else
          txs in
      let txs =
        if marketplace_tokens > 0n then
          {from_ = (Tezos.get_self_address ()); txs = [{ to_ = buyer; token_id = token_id; amount = marketplace_tokens }]} :: txs
        else
          txs in
      let ops = token_transfer offer.origin txs :: ops in
      let new_offers = Big_map.update offer_id (None : offer_info option) store.offers in
      let new_store =
        { store with
          offers = new_offers;
          swaps = new_swaps;
          tokens = new_tokens
        } in
      (* payment transfers *)
      let fa12_address = find_fa12 offer.token_symbol store in
      let ops = handout_op ops seller_value offer.token_symbol fa12_address (Tezos.get_self_address ()) owner in
      let ops = handout_op ops royalties offer.token_symbol fa12_address (Tezos.get_self_address ()) royalties_info.issuer in
      let ops = handout_fee_op ops management_fee offer.token_symbol fa12_address (Tezos.get_self_address ()) store.treasury in
      (ops, new_store)