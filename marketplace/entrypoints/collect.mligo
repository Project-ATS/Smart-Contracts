let collect (param : collect_marketplace_param) (store : storage) : return =
  if store.paused then
    (failwith error_MARKETPLACE_IS_PAUSED : return)
    (* payment token was specified as token other than XTZ, but XTZ amount was sent *)
  else if (not (param.token_symbol = "XTZ")) && (Tezos.get_amount ()) <> 0tez then
    (failwith(error_NO_XTZ_AMOUNT_TO_BE_SENT) : return)
  else
    let swap =
      match Big_map.find_opt param.swap_id store.swaps with
      | None -> (failwith error_SWAP_ID_DOES_NOT_EXIST : swap_info)
      | Some swap_info -> swap_info in
    let buyer =
      if swap.is_reserved && (Tezos.get_sender ()) <> swap.recipient then
        (failwith(error_ONLY_RECIPIENT_CAN_COLLECT) : address)
      else
        (Tezos.get_sender ()) in
    if (Tezos.get_now ()) < swap.start_time then
        (failwith error_SALE_IS_NOT_STARTED_YET : return)
      else if (Tezos.get_now ()) > swap.end_time then
        (failwith error_SALE_IS_FINISHED : return)
      else
    (* token price set to zero by the seller.
    only token is transferred *)
    if swap.token_price = 0n then
      let op = token_transfer swap.origin [{ from_ = (Tezos.get_self_address ()); txs = [{ to_ = buyer; token_id = swap.token_id; amount = param.token_amount }]}] in
      let new_token_amount =
        match is_a_nat (swap.token_amount - param.token_amount) with
        | None -> (failwith(error_INSUFFICIENT_TOKEN_BALANCE) : nat)
        | Some token_amount -> token_amount in
      let (new_swaps, new_tokens) =
        if new_token_amount = 0n then
          (Big_map.update param.swap_id (None : swap_info option) store.swaps,
          Big_map.update (swap.token_id, swap.owner) (None : swap_id option) store.tokens)
        else
          (Big_map.update param.swap_id (Some { swap with token_amount = new_token_amount }) store.swaps,
          store.tokens) in
      [op], { store with swaps = new_swaps; tokens = new_tokens }
    else
    (* non-zero price.
    royalties are fetched from royalties contract *)
      let royalties_info = find_royalties swap.origin swap.token_id store in
        (* set the amount of fungible tokens to be sent from buyer (in buyer currency) *)
        let transfer_amount =
          let price =
            if swap.is_dutch then
              calculate_price (swap.start_time, swap.duration, swap.starting_price, swap.token_price)
            else
              swap.token_price in
          let buyer_amount_nat =
          (* check that the payment token is one permitted by the seller *)
            let _ = (assert_with_code (Set.mem param.token_symbol swap.accepted_tokens) error_TOKEN_NOT_PERMITTED_BY_SELLER) in
          (* considers the case of XTZ transfer, convert the amount type to nat *)
            if param.token_symbol = "XTZ" then
              mutez_to_natural (Tezos.get_amount ())
            else
              param.amount_ft in
          (* convert and check equality of amounts *)
          let converted_price =
            if (not swap.is_multi_token) then 
                if(param.token_symbol <> swap.ft_symbol) then
                  (failwith(error_NOT_REQUIRED_TOKEN) : return)
                else 
                  price
            else  
                if(param.token_symbol = swap.ft_symbol) then
            (* no conversion needed *)
                  price
                else
                  convert_tokens swap.ft_symbol price param.token_symbol store in
          
          let _ = (assert_with_code (converted_price * param.token_amount <= buyer_amount_nat) error_AMOUNT_IS_NOT_EQUAL_TO_PRICE) in
          (* transfer_amount = converted_price *)
          converted_price in

        (* calculate the new swap.token_amount *)
        let new_token_amount =
          match is_a_nat (swap.token_amount - param.token_amount) with
          | None -> (failwith(error_INSUFFICIENT_TOKEN_BALANCE) : nat)
          | Some token_amount -> token_amount in
        let management_fee =
          transfer_amount * store.management_fee_rate / const_FEE_DENOM in
        let royalties = royalties_info.royalties * transfer_amount / const_FEE_DENOM in
        let seller_value =
          match is_a_nat (transfer_amount - (management_fee + royalties)) with
          | None -> (failwith error_FEE_GREATER_THAN_AMOUNT : nat)
          | Some n -> n in
        let fa12_address =
          match Big_map.find_opt param.token_symbol store.allowed_tokens with
          | None -> (failwith(error_NO_FA12_ADDRESS_LISTED_FOR_THIS_TOKEN) : address)
          | Some token -> token.fa12_address in
        let op_seller =
          if param.token_symbol = "XTZ" then
            xtz_transfer swap.owner (natural_to_mutez seller_value)
          else
            fa12_transfer fa12_address (Tezos.get_sender ()) swap.owner seller_value in
        let op_buyer =
          token_transfer
          swap.origin
          [{
              from_ = (Tezos.get_self_address ());
              txs =
              [{
                to_ = buyer;
                token_id = swap.token_id;
                amount = param.token_amount;
              }]
            }] in
        (* remove or update swap and tokens *)
        let (new_swaps, new_tokens) =
          if new_token_amount = 0n then
            (Big_map.update param.swap_id (None : swap_info option) store.swaps,
            Big_map.update (swap.token_id, swap.owner) (None : swap_id option) store.tokens)
          else
            (Big_map.update param.swap_id (Some { swap with token_amount = new_token_amount }) store.swaps,
            store.tokens) in
        let new_store = { store with swaps = new_swaps; tokens = new_tokens; } in
        let ops =
          if seller_value > 0n then
            [op_seller; op_buyer]
          else
            [op_buyer] in
        let ops = handout_op ops royalties param.token_symbol fa12_address (Tezos.get_sender ()) royalties_info.issuer in
        let ops = handout_fee_op ops management_fee param.token_symbol fa12_address (Tezos.get_sender ()) store.treasury in
        (ops, new_store)