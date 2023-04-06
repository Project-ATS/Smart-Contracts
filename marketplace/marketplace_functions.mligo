#include "../common/functions.mligo"

[@inline]
let token_mint (metadata : nft_mint_param) (store : storage) : operation =
    let token_mint_entrypoint: nft_mint_param contract =
      match (Tezos.get_entrypoint_opt "%mint" store.nft_address : nft_mint_param contract option) with
      | None -> (failwith error_TOKEN_CONTRACT_MUST_HAVE_A_MINT_ENTRYPOINT : nft_mint_param contract)
      | Some contract -> contract in
    Tezos.transaction metadata 0mutez token_mint_entrypoint

[@inline]
let config_royalties (param : config_royalties_param) (store : storage) : operation =
    let config_royalties_entrypoint : config_royalties_param contract =
      match (Tezos.get_entrypoint_opt "%configRoyalties" store.royalties_address : config_royalties_param contract option) with
      | None -> (failwith(error_ROYALTIES_CONTRACT_MUST_HAVE_A_ROYALTIES_MINT_ENTRYPOINT) : config_royalties_param contract)
      | Some contract -> contract in
    Tezos.transaction param 0mutez config_royalties_entrypoint