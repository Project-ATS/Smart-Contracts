#include "../common/const.mligo"
#include "auction_errors.mligo" 
#include "../common/interface.mligo"
#include "auction_interface.mligo" 
#include "../common/functions.mligo"


let start_auction (param : start_auction_param) (store : storage) : return =
    if store.paused then 
        (failwith(error_CONTRACT_IS_PAUSED) : return)
    else if param.start_time < Tezos.now then
        (failwith error_NO_PAST_TIME_ALLOWED_AS_AUCTION_START_TIME : return)
    else if param.period = 0n then
        (failwith error_NO_ZERO_PERIOD_ALLOWED : return)
    else if (param.adding_period > const_ADDING_PERIOD_UPPER || param.adding_period < const_ADDING_PERIOD_LOWER) && param.adding_period <> 0n then
        (failwith(error_ADDING_PERIOD_IS_OUT_OF_BOUNDS) : return)
    else
        (* transfer token to auction address *)
        let op = token_transfer param.token_origin [{ from_ = Tezos.sender; txs = [{ to_ = Tezos.self_address; token_id = param.token_id; amount = param.token_amount }]}] in
        (* set swap information *)
        let new_auction = {
            current_price = param.starting_price;
            current_highest_bidder = Tezos.self_address;
            start_time = param.start_time;
            end_time = param.start_time + int(param.period);
            permit_lower = false;
            reserved_price_hashed = param.reserved_price_hashed;
            reserved_price_xtz = 0tez;
            reveal_time = param.start_time + int(param.period) + int(param.reveal_time);
            adding_period = param.adding_period;
            extra_duration = param.extra_duration; 
            reveal_counter = 0n;
        } in
        let (ops, new_swaps) =
            if param.token_amount = 0n then
                (failwith(error_NO_ZERO_TOKEN_AMOUNT_ALLOWED) : operation list * (swap_id, swap_info) big_map)
            else
                ([op],
                Big_map.update store.next_swap_id 
                (Some { 
                    owner = Tezos.sender; 
                    token_id = param.token_id; 
                    auction = new_auction; 
                    token_amount = param.token_amount;
                    origin = param.token_origin;
                    })
                    store.swaps) in
        let new_next_swap_id = store.next_swap_id + 1n in 
        let new_store = { store with 
        next_swap_id = new_next_swap_id; 
        swaps = new_swaps } in
        ops, new_store


let bid (param : bid_param) (store : storage) : return = 
    if store.paused then 
        (failwith(error_CONTRACT_IS_PAUSED) : return)
    else
        let swap : swap_info = match Big_map.find_opt param store.swaps with 
        | None -> (failwith error_SWAP_ID_DOES_NOT_EXIST : swap_info) 
        | Some s -> s in 
        if Tezos.sender = swap.owner then
        (failwith(error_OWNER_CAN_NOT_BID) : return)
        else
        let auction = swap.auction in 
        if Tezos.amount <= auction.current_price then 
            (failwith error_AMOUNT_NOT_ENOUGH : return) 
        else if Tezos.now < auction.start_time then
            (failwith(error_AUCTION_NOT_STARTED) : return)
        else if Tezos.now > auction.end_time then
            (failwith(error_AUCTION_FINISHED) : return) 
//            (failwith error_AUCTION_NOT_ACTIVE : return) 
        else 
            let end_time = 
                if Tezos.now > auction.end_time - int (auction.adding_period) then 
                    auction.end_time + int (auction.extra_duration) 
                else 
                    auction.end_time in
        let new_auction = { auction with 
        current_price = Tezos.amount; 
        current_highest_bidder = Tezos.sender; 
        end_time = end_time} in 
        let new_swap = { swap with auction = new_auction } in 
        if auction.current_highest_bidder = Tezos.self_address then
        (* place first bid - no former bids return *)
            ([] : operation list), { store with swaps = Big_map.update param (Some new_swap) store.swaps } 
        (* place bids, former highest bidder gets his bid back *)
        else 
            let op_former = xtz_transfer auction.current_highest_bidder auction.current_price in 
            [op_former], { store with swaps = Big_map.update param (Some new_swap) store.swaps } 
            

(* reveal reserved price *)
let reveal_price (param : reveal_price_param) (store : storage) : return = 
    if store.paused then 
        (failwith(error_CONTRACT_IS_PAUSED) : return)
    else
        let swap = match Big_map.find_opt param.swap_id store.swaps with 
        | None -> (failwith error_SWAP_ID_DOES_NOT_EXIST : swap_info) 
        | Some s -> s in 
        let auction = swap.auction in 
        if Tezos.now < auction.end_time || Tezos.now > auction.reveal_time then 
            (failwith error_NOT_TIME_TO_REVEAL : return) 
        else if Tezos.sender <> swap.owner then
            (failwith(error_ONLY_OWNER_CAN_CALL_THIS_ENTRYPOINT) : return)
        else if auction.reveal_counter = const_REVEAL_LIMIT then
            (failwith error_NO_MORE_REVELATION_TRIES : return)
        else
            let reveal_counter = auction.reveal_counter + 1n in
            let hashed_price = Crypto.sha256 
                              (Bytes.pack 
                              (param.revealed_price.price, param.revealed_price.secret)) in 
            if hashed_price <> auction.reserved_price_hashed then 
                (failwith error_WRONG_RESERVED_PRICE_OR_SECRET : return) 
            else 
                let new_auction =   
                    { auction with 
                    reserved_price_xtz = param.revealed_price.price; 
                    reveal_counter = reveal_counter;
                    permit_lower = param.permit_lower } in 
                let new_swaps = Big_map.update param.swap_id (Some { swap with auction = new_auction }) store.swaps in 
                ([] : operation list), { store with swaps = new_swaps } 


let remove_from_auction (swap_id : remove_from_auction_param) (store : storage) : return = 
    if store.paused then 
        (failwith(error_CONTRACT_IS_PAUSED) : return)
    else
        let swap = match Big_map.find_opt swap_id store.swaps with 
          | None -> (failwith error_SWAP_ID_DOES_NOT_EXIST : swap_info) 
          | Some swap_info -> swap_info in
        if Tezos.sender <> swap.owner then 
          (failwith error_ONLY_OWNER_CAN_REMOVE_TOKENS : return) 
        else if swap.auction.current_highest_bidder <> Tezos.self_address then 
          (failwith error_NO_REMOVING_WHILE_AUCTION_IS_ACTIVE : return) 
        else 
            let op = token_transfer swap.origin [{ from_ = Tezos.self_address; txs = [{ to_ = Tezos.sender; token_id = swap.token_id; amount = swap.token_amount }]}] in
            let new_swaps = Big_map.update swap_id (None : swap_info option) store.swaps in 
            let new_storage = { store with swaps = new_swaps } in 
            ([op], new_storage) 


let collect (param : collect_param) (store : storage) : return = 
    if store.paused then 
        (failwith(error_CONTRACT_IS_PAUSED) : return) 
    else
        let swap = 
            match Big_map.find_opt param.swap_id store.swaps with 
            | None -> (failwith error_SWAP_ID_DOES_NOT_EXIST : swap_info) 
            | Some swap -> swap in 
        let royalties_info =
            if swap.origin <> store.nft_address then
                {
                    issuer = Tezos.self_address;
                    royalties = 0n;
                }
            else
                match (Tezos.call_view "get_royalties" swap.token_id store.royalties_address : royalties_info option) with
                | None -> (failwith("no royalties") : royalties_info)
                | Some r -> r in
        if Tezos.now < swap.auction.reveal_time then 
            (failwith error_NO_COLLECTING_UNTIL_AUCTION_IS_OVER : return) 
        else if Tezos.amount <> 0tez then 
            (failwith error_NO_AMOUNT_CAN_BE_SENT_WHEN_COLLECTING : return) 
        (* transparent auction collect *)
        else 
        let auction = swap.auction in 
        (* bids haven't reached the reserved price, 
        bid is returned to bidder, 
        token is returned to owner *)
        if auction.reserved_price_xtz > auction.current_price && auction.permit_lower = false then 
            (* set refund operations *)
            let op_buyer = xtz_transfer auction.current_highest_bidder auction.current_price in 
            let op_seller = token_transfer swap.origin [{ from_ = Tezos.self_address; txs = [{ to_ = swap.owner; token_id = swap.token_id; amount = swap.token_amount }]}] in
            let ops = 
                if auction.current_highest_bidder = Tezos.self_address then 
                    [op_seller] 
                else 
                    [op_buyer; op_seller] in 
            let new_swaps = Big_map.update param.swap_id (None : swap_info option) store.swaps in 
            let new_store = { store with swaps = new_swaps } in 
            (ops, new_store) 
        else if auction.current_highest_bidder <> Tezos.self_address then 
        (* xtz is transfered to token owner deducting fees, 
        nft is transfered to highest bidder  *) 
            (* set transfer amounts *) 
            let management_fee_rate = store.management_fee_rate in 
            let royalties = (mutez_to_natural auction.current_price) * royalties_info.royalties / const_FEE_DENOM in 
            let management_fee = (mutez_to_natural auction.current_price) * management_fee_rate / const_FEE_DENOM in 
            let seller_value = 
                match is_a_nat ((mutez_to_natural auction.current_price) - royalties - management_fee) with 
                | None -> (failwith error_FEE_GREATER_THAN_AMOUNT : nat) 
                | Some n -> n in 
            (* set operations *)
            let op_seller = xtz_transfer swap.owner (natural_to_mutez seller_value) in 
            let op_buyer = token_transfer swap.origin [{ from_ = Tezos.self_address; txs = [{ to_ = auction.current_highest_bidder; token_id = swap.token_id; amount = swap.token_amount }]}] in
            let ops = 
                if seller_value > 0n then 
                    [op_seller; op_buyer] 
                else 
                    [op_buyer] in
            (* set fee operations *)
            let ops = 
                if royalties > 0n then 
                    let op_royalties = xtz_transfer royalties_info.issuer (natural_to_mutez royalties) in 
                    op_royalties :: ops 
                else 
                    ops in 
            let ops = 
                if management_fee > 0n then 
                    let op_management_fee = xtz_transfer store.admin (natural_to_mutez management_fee) in 
                    op_management_fee :: ops 
                else 
                    ops in 
            let new_swaps = Big_map.update param.swap_id (None : swap_info option) store.swaps in 
            let new_store = { store with swaps = new_swaps } in 
            ops, new_store 
        else
            (failwith("failed collect") : return)


let main (action, store : parameter * storage) : return = 
 match action with 
 | PauseAuction p -> set_pause p store 
 | UpdateNftAddress p -> update_nft_address p store 
 | UpdateRoyaltiesAddress p -> update_royalties_address p store
 | UpdateMarketplaceAdmin p -> update_admin p store 
 | UpdateFee p -> update_fee p store 
 | StartAuction p -> start_auction p store 
 | Bid p -> bid p store 
 | RevealPrice p -> reveal_price p store 
 | RemoveFromMarketplace p -> remove_from_auction p store 
 | Collect p -> collect p store 
