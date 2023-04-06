let mint (param : marketplace_mint_param) (store : storage) : return =
  if store.paused then
    (failwith (error_MARKETPLACE_IS_PAUSED) : return)
  else
    let {
          metadata_url = metadata_url;
          royalties = royalties;
          amount_ = amount_;
          owner;
        } = param in
    if royalties > const_ROYALTIES_LIMIT then
      (failwith error_ROYALTIES_TOO_HIGH : return)
    else
      let token_metadata = Map.literal [("", Bytes.pack metadata_url)] in
      let token_id = store.next_token_id in
      let nft_op = token_mint {
        amount_ = amount_;
        token_id = token_id;
        token_metadata = token_metadata;
        owner = owner;
        } store in
      let royalties_op = config_royalties {
        token_id = token_id;
        royalties = royalties;
        token_origin = store.nft_address;
      } store in
      let new_store =
      { store with
        next_token_id = store.next_token_id + 1n;
      } in
      (([nft_op; royalties_op] : operation list), new_store)