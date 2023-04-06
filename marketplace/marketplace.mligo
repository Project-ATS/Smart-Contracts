#include "../common/const.mligo"
#include "../common/interface.mligo"
#include "../common/functions.mligo"
#include "marketplace_errors.mligo"
#include "marketplace_interface.mligo"
#include "marketplace_functions.mligo"
#include "entrypoints/mint.mligo"
#include "entrypoints/add_to_marketplace.mligo"
#include "entrypoints/update_swap.mligo"
#include "entrypoints/remove_from_marketplace.mligo"
#include "entrypoints/collect.mligo"
#include "entrypoints/send_offer.mligo"
#include "entrypoints/update_offer.mligo"
#include "entrypoints/make_counter_offer.mligo"
#include "entrypoints/accept_counter_offer.mligo"
#include "entrypoints/withdraw_offer.mligo"
#include "entrypoints/withdraw_counter_offer.mligo"
#include "entrypoints/accept_offer.mligo"
#include "entrypoints/add_single_token.mligo"
#include "entrypoints/remove_single_token.mligo"



let main (action, store : parameter * storage) : return =
 match action with
 | SetPause p -> set_pause p store
 | UpdateNftAddress p -> update_nft_address p store
 | UpdateRoyaltiesAddress p -> update_royalties_address p store
 | UpdateFee p -> update_fee p store
 | UpdateRoyalties p -> [config_royalties p store], store
 | UpdateOracleAddress p -> update_oracle_address p store
 | UpdateAllowedTokens p -> update_allowed_tokens p store
 | MintNft p -> mint p store
 | AddToMarketplace p -> add_to_marketplace p store
 | RemoveFromMarketplace p -> remove_from_marketplace p store
 | Collect p ->  collect p store
 | SendOffer p -> send_offer p store
 | UpdateOffer p -> update_offer p store
 | WithdrawOffer p -> withdraw_offer p store
 | MakeCounterOffer p -> make_counter_offer p store
 | WithdrawCounterOffer p -> withdraw_counter_offer p store
 | AcceptCounterOffer p -> accept_counter_offer p store
 | AcceptOffer p -> accept_offer p store
 | UpdateSwap p -> update_swap p store
 | AddSingleToken p -> add_single_token p store
 | RemoveSingleToken p -> remove_single_token p store
 | UpdateMultisigAddress p -> update_multisig_address p store

