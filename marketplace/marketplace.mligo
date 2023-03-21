#include "../common/const.mligo"
#include "../common/interface.mligo"
#include "marketplace_errors.mligo" 
#include "marketplace_interface.mligo" 
#include "../common/functions.mligo"


[@inline] 
let token_mint (metadata : nft_mint_param) (store : storage) : operation = 
    let token_mint_entrypoint: nft_mint_param contract = 
      match (Tezos.get_entrypoint_opt "%mint" store.nft_address : nft_mint_param contract option) with 
      | None -> (failwith error_TOKEN_CONTRACT_MUST_HAVE_A_MINT_ENTRYPOINT : nft_mint_param contract) 
      | Some contract -> contract in 
    Tezos.transaction metadata 0mutez token_mint_entrypoint 

[@inline]
let config_royalties (param : royalties_mint_param) (store : storage) : operation =
    let royalties_mint_entrypoint : royalties_mint_param contract = 
      match (Tezos.get_entrypoint_opt "%configRoyalties" store.royalties_address : royalties_mint_param contract option) with
      | None -> (failwith(error_ROYALTIES_CONTRACT_MUST_HAVE_A_ROYALTIES_MINT_ENTRYPOINT) : royalties_mint_param contract)
      | Some contract -> contract in
    Tezos.transaction param 0mutez royalties_mint_entrypoint
    

let mint (param : marketplace_mint_param) (store : storage) : return = 
  if store.paused then 
    (failwith error_MARKETPLACE_IS_PAUSED : return) 
  else 
    let { 
          metadata_url = metadata_url; 
          royalties = royalties; 
          amount_ = amount_; 
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
        } store in
      let royalties_op = config_royalties {
        token_id = token_id;
        royalties = royalties;
      } store in
      let new_store = 
      { store with 
        next_token_id = store.next_token_id + 1n; 
      } in 
      (([nft_op; royalties_op] : operation list), new_store) 


let add_to_marketplace (param : add_to_marketplace_param) (store : storage) : return = 
  if store.paused then 
    (failwith error_MARKETPLACE_IS_PAUSED : return) 
  else 
    let swap_id = 
      match Big_map.find_opt (param.token_id, Tezos.sender) store.tokens with 
      | Some _swap_id -> (failwith(error_TOKEN_IS_ALREADY_ON_SALE) : swap_id)
      | None -> store.next_swap_id in
  if param.start_time >= param.end_time then
    (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return)
  else
    let (starting_price, duration, is_dutch) = 
      match param.swap_type with
      | Regular -> (param.token_price, 0, false)
      | Dutch p -> 
        if int p.duration > param.end_time - param.start_time then
          (failwith(error_DURATION_IS_LONGER_THAN_SWAP_DURATION) : (tez * int * bool))
        else 
          (p.starting_price, int p.duration, true)
      in
    let (recipient, is_reserved) = 
      match param.recipient with
      | Reserved p -> (p, true)
      | General -> (Tezos.self_address, false) 
      in
    if param.token_amount = 0n then
      (failwith(error_NO_ZERO_TOKEN_AMOUNT_ALLOWED) : return)
    else
      let op = 
      (
        token_transfer 
          param.token_origin 
          [
            { 
              from_ = Tezos.sender; 
              txs = 
                [
                  { 
                    to_ = Tezos.self_address; 
                    token_id = param.token_id; 
                    amount = param.token_amount; 
                  }
                ]
            }
          ] 
      ) in
      let ops = [op] in
      let new_swaps = 
          Big_map.update swap_id (Some { 
          owner = Tezos.sender; 
          token_id = param.token_id; 
          is_dutch = is_dutch;
          is_reserved = is_reserved;
          starting_price = starting_price;
          token_price = param.token_price; 
          start_time = param.start_time; 
          duration = duration;
          end_time = param.end_time; 
          token_amount = param.token_amount; 
          origin = param.token_origin;
          recipient = recipient;
          }) store.swaps in
      let new_tokens = 
        Big_map.update (param.token_id, Tezos.sender) (Some swap_id) store.tokens in 
      let new_store = 
        { 
          store with 
          next_swap_id = store.next_swap_id + 1n; 
          swaps = new_swaps; 
          tokens = new_tokens; 
        } in
      ops, new_store



let update_swap (param : update_swap_param) (store : storage) : return = 
  if store.paused then 
    (failwith error_MARKETPLACE_IS_PAUSED : return) 
  else
    let swap = 
      match Big_map.find_opt param.swap_id store.swaps with
      | None -> (failwith(error_SWAP_ID_DOES_NOT_EXIST) : swap_info)
      | Some swap -> swap in
    if Tezos.sender <> swap.owner then
      (failwith(error_ONLY_OWNER_CAN_CALL_THIS_ENTRYPOINT) : return)
    
    else match param.action with
    | Add_amount token_amount ->
    if token_amount = 0n then 
      (failwith(error_NO_ZERO_TOKEN_AMOUNT_ALLOWED) : return)
    else if swap.is_dutch && Tezos.now >= swap.start_time then
      (failwith(error_DUTCH_AUCTION_ACTIVE) : return)
    else
      let op = token_transfer swap.origin [{ from_ = Tezos.sender; txs = [{ to_ = Tezos.self_address; token_id = swap.token_id; amount = token_amount }]}] in
      let new_swaps = Big_map.update param.swap_id (Some {swap with token_amount = swap.token_amount + token_amount}) store.swaps in
      [op], {store with swaps = new_swaps}
    | Reduce_amount token_amount -> 
    if token_amount = 0n then 
      (failwith(error_NO_ZERO_TOKEN_AMOUNT_ALLOWED) : return)
    else if swap.is_dutch && Tezos.now >= swap.start_time then
      (failwith(error_DUTCH_AUCTION_ACTIVE) : return)
    else
      let new_token_amount = 
        match is_a_nat (swap.token_amount - token_amount) with
        | None -> (failwith(error_INSUFFICIENT_TOKEN_BALANCE) : nat)
        | Some n -> n in
      let op = token_transfer swap.origin [{ from_ = Tezos.self_address; txs = [{ to_ = Tezos.sender; token_id = swap.token_id; amount = token_amount }]}] in
      let (new_swaps, new_tokens) = 
        if new_token_amount <> 0n then
          (Big_map.update param.swap_id (Some {swap with token_amount = new_token_amount}) store.swaps,
          store.tokens)
        else 
          (Big_map.update param.swap_id (None : swap_info option) store.swaps,
          Big_map.update (swap.token_id, Tezos.sender) (None : swap_id option) store.tokens) in
      [op], {store with swaps = new_swaps; tokens = new_tokens}
    | Update_price price -> 
    if swap.is_dutch && Tezos.now >= swap.start_time then
      (failwith(error_DUTCH_AUCTION_ACTIVE) : return)
    else
      let new_swaps = Big_map.update param.swap_id (Some {swap with token_price = price}) store.swaps in
      ([] : operation list), { store with swaps = new_swaps }
    | Update_times p -> 
    if p.start_time >= p.end_time then
      (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return)
    else if swap.is_dutch && Tezos.now >= swap.start_time then
      (failwith(error_DUTCH_AUCTION_ACTIVE) : return)
    else
      let new_swaps = Big_map.update param.swap_id (Some { swap with start_time = p.start_time; end_time = p.end_time }) store.swaps in
      ([] : operation list), { store with swaps = new_swaps } 
    | Update_reserved_address p ->
    let new_swaps = Big_map.update param.swap_id (Some {swap with recipient = p; is_reserved = true}) store.swaps in
    ([] : operation list), { store with swaps = new_swaps }
    | Update_duration p ->
    if swap.is_dutch = false || (swap.is_dutch && Tezos.now >= swap.start_time) then
      (failwith(error_CAN_NOT_UPDATE_DURATION_FOR_THIS_SWAP) : return)
    else
      let new_swaps = Big_map.update param.swap_id (Some { swap with duration = int p }) store.swaps in
      ([] : operation list), {store with swaps = new_swaps}
    | Update_starting_price p ->
    if swap.is_dutch = false || (swap.is_dutch && Tezos.now >= swap.start_time) then
      (failwith(error_CAN_NOT_UPDATE_STARTING_PRICE_FOR_THIS_SWAP) : return)
    else
      let new_swaps = Big_map.update param.swap_id (Some { swap with starting_price = p }) store.swaps in
      ([] : operation list), {store with swaps = new_swaps}
    



let remove_from_marketplace (swap_id : remove_from_marketplace_param) (store : storage) : return = 
  if store.paused then 
    (failwith error_MARKETPLACE_IS_PAUSED : return) 
  else 
    let swap = 
      match Big_map.find_opt swap_id store.swaps with 
      | None -> (failwith error_SWAP_ID_DOES_NOT_EXIST : swap_info) 
      | Some swap_info -> swap_info in 
    if Tezos.sender <> swap.owner then 
      (failwith error_ONLY_OWNER_CAN_REMOVE_FROM_MARKETPLACE : return) 
    else 
      let token_id = swap.token_id in 
      let token_amount = swap.token_amount in 
      let op = token_transfer swap.origin [{ from_ = Tezos.self_address; txs = [{ to_ = Tezos.sender; token_id = token_id; amount = token_amount }]}] in
      let (new_swaps, new_tokens) = 
          (Big_map.update swap_id (None : swap_info option) store.swaps,
          Big_map.update (token_id, Tezos.sender) (None : swap_id option) store.tokens) in
      let new_store = { store with swaps = new_swaps; tokens = new_tokens } in 
      [op], new_store 


let collect (param : collect_param) (store : storage) : return = 
  if store.paused then 
    (failwith error_MARKETPLACE_IS_PAUSED : return) 
  else 
    let swap = 
      match Big_map.find_opt param.swap_id store.swaps with 
      | None -> (failwith error_SWAP_ID_DOES_NOT_EXIST : swap_info) 
      | Some swap_info -> swap_info in 
    let buyer = 
      if swap.is_reserved && Tezos.sender <> swap.recipient then
        (failwith(error_ONLY_RECIPIENT_CAN_COLLECT) : address)
      else
        Tezos.sender in
    if Tezos.now < swap.start_time then 
        (failwith error_SALE_IS_NOT_STARTED_YET : return) 
      else if Tezos.now > swap.end_time then 
        (failwith error_SALE_IS_FINISHED : return) 
      else 
    (* token price set to zero by the seller.
    only token is transferred *)
    if swap.token_price = 0tez then 
      let op = token_transfer swap.origin [{ from_ = Tezos.self_address; txs = [{ to_ = buyer; token_id = swap.token_id; amount = param.token_amount }]}] in
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
      
        let xtz_amount = 
          let price = 
            if swap.is_dutch then 
              calculate_price (swap.start_time, swap.duration, swap.starting_price, swap.token_price) 
            else 
              swap.token_price in 
          if Tezos.amount <> price * param.token_amount then 
            (failwith(error_AMOUNT_IS_NOT_EQUAL_TO_PRICE) : tez) 
          else 
            Tezos.amount in 
        (* calculate the new swap.token_amount *) 
        let new_token_amount = 
          match is_a_nat (swap.token_amount - param.token_amount) with 
          | None -> (failwith(error_INSUFFICIENT_TOKEN_BALANCE) : nat) 
          | Some token_amount -> token_amount in 
        let management_fee = (mutez_to_natural xtz_amount) * store.management_fee_rate / const_FEE_DENOM in 
        let royalties = royalties_info.royalties * (mutez_to_natural xtz_amount) / const_FEE_DENOM in 
        let seller_value = 
          match is_a_nat ((mutez_to_natural xtz_amount) - (management_fee + royalties)) with 
          | None -> (failwith error_FEE_GREATER_THAN_AMOUNT : nat) 
          | Some n -> n in 
        let op_seller = xtz_transfer swap.owner (natural_to_mutez seller_value) in 
        let op_buyer = 
          token_transfer 
          swap.origin 
          [{ 
              from_ = Tezos.self_address; 
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
        let new_store = { store with swaps = new_swaps; tokens = new_tokens} in 
        let ops = 
          if seller_value > 0n then 
            [op_seller; op_buyer] 
          else
            [op_buyer] in 
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
        (ops, new_store) 


let send_offer (param : offer_param) (store : storage) : return = 
  if store.paused then 
    (failwith(error_MARKETPLACE_IS_PAUSED) : return) 
  else if param.start_time >= param.end_time then
    (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return)
  else 
    match Big_map.find_opt (param.token_id, Tezos.sender, param.owner) store.offers with 
    | Some _ -> (failwith(error_OFFER_ALREADY_PLACED) : return) 
    | None -> 
      let new_offer = { 
        token_amount = param.token_amount; 
        value = Tezos.amount; 
        start_time = param.start_time; 
        end_time = param.end_time; 
        origin = param.token_origin;
        } in 
      let new_offers = Big_map.update (param.token_id, Tezos.sender, param.owner) (Some new_offer) store.offers in 
      ([] : operation list), {store with offers = new_offers} 


let update_offer (param : offer_param) (store : storage) : return = 
  if store.paused then 
    (failwith(error_MARKETPLACE_IS_PAUSED) : return) 
  else if param.start_time >= param.end_time then
    (failwith(error_START_TIME_IS_LATER_THAN_END_TIME) : return) 
  else 
    match Big_map.find_opt (param.token_id, Tezos.sender, param.owner) store.offers with 
    | None -> (failwith(error_NO_OFFER_PLACED) : return) 
    | Some offer -> 
      let new_offer = { 
            token_amount = param.token_amount; 
            value = Tezos.amount; 
            start_time = param.start_time; 
            end_time = param.end_time; 
            origin = param.token_origin;
            } in 
      let op = xtz_transfer Tezos.sender offer.value in 
      let new_offers = Big_map.update (param.token_id, Tezos.sender, param.owner) (Some new_offer) store.offers in 
      [op], {store with offers = new_offers} 


let withdraw_offer (param : withdraw_offer_param) (store : storage) : return = 
  if store.paused then 
    (failwith(error_MARKETPLACE_IS_PAUSED) : return) 
  else 
    match Big_map.find_opt (param.token_id, Tezos.sender, param.owner) store.offers with 
    | None -> (failwith(error_NO_OFFER_PLACED) : return) 
    | Some offer -> 
      let op = xtz_transfer Tezos.sender offer.value in 
      let new_offers = Big_map.update (param.token_id, Tezos.sender, param.owner) (None : offer_info option) store.offers in 
      let new_store = { store with offers = new_offers } in 
      [op], new_store 

let accept_offer (param : accept_offer_param) (store : storage) : return = 
  if store.paused then 
    (failwith(error_MARKETPLACE_IS_PAUSED) : return) 
  else
    let (owner, buyer, token_id) = (Tezos.sender, param.buyer, param.token_id) in
    let offer_id = (token_id, buyer, owner) in
    let offer = 
      match Big_map.find_opt offer_id store.offers with 
      | None -> (failwith(error_OFFER_DOES_NOT_EXIST) : offer_info) 
      | Some offer -> offer in 
    if Tezos.now < offer.start_time then 
      (failwith error_ACCEPTING_OFFER_IS_TOO_EARLY : return) 
    else 
    if Tezos.now > offer.end_time then 
      (failwith error_ACCEPTING_OFFER_IS_TOO_LATE : return) 
    else 
      let royalties_info =
        if offer.origin <> store.nft_address then
          {
            issuer = Tezos.self_address;
            royalties = 0n;
          }
        else
          match (Tezos.call_view "get_royalties" token_id store.royalties_address : royalties_info option) with
          | None -> (failwith("no royalties") : royalties_info)
          | Some r -> r in
      let token_amount = offer.token_amount in 
      let management_fee = (mutez_to_natural offer.value) * store.management_fee_rate / const_FEE_DENOM in 
      let royalties = royalties_info.royalties * (mutez_to_natural offer.value) / const_FEE_DENOM in 
      let seller_value = 
        match is_a_nat ((mutez_to_natural offer.value) - (management_fee + royalties)) with 
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
              owner = Tezos.self_address; 
              token_id = 0n; 
              is_dutch = false;
              is_reserved = false;
              starting_price = 0tez;
              token_price = 0tez; 
              start_time = Tezos.now;
              duration = 0; 
              end_time = Tezos.now; 
              token_amount = 0n; 
              origin = offer.origin;
              recipient = Tezos.self_address;
            } 
            (* real swap *) 
            | Some swap -> swap in 
      (* token assignment *) 
      if Tezos.source <> swap.owner && Tezos.source <> owner then
        (failwith(error_CALLER_NOT_PERMITTED_TO_ACCEPT_OFFER) : return)
      else
      let (marketplace_tokens, owner_tokens, new_swaps, new_tokens) = 
        match is_a_nat (swap.token_amount - token_amount) with 
        (* transfer only from marketplace *) 
        | Some n -> 
          if n = 0n then 
            (token_amount, 
            0n, 
            Big_map.update swap_id (None : swap_info option) store.swaps, 
            Big_map.update (token_id, owner) (None : swap_id option) store.tokens) 
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
          {from_ = Tezos.self_address; txs = [{ to_ = buyer; token_id = token_id; amount = marketplace_tokens }]} :: txs
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
      (* xtz transfers *)
      let ops = 
        if seller_value > 0n then 
          let op_seller = xtz_transfer owner (natural_to_mutez seller_value) in 
          op_seller :: ops 
        else 
          ops in 
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
      (ops, new_store) 


let main (action, store : parameter * storage) : return = 
 match action with 
 | SetPause p -> set_pause p store 
 | UpdateMarketplaceAdmin p -> update_admin p store 
 | UpdateNftAddress p -> update_nft_address p store 
 | UpdateRoyaltiesAddress p -> update_royalties_address p store
 | UpdateFee p -> update_fee p store 
 | UpdateRoyalties p -> [config_royalties p store], store 
 | MintNft p -> mint p store 
 | AddToMarketplace p -> add_to_marketplace p store 
 | RemoveFromMarketplace p -> remove_from_marketplace p store 
 | Collect p ->  collect p store 
 | SendOffer p -> send_offer p store 
 | UpdateOffer p -> update_offer p store
 | WithdrawOffer p -> withdraw_offer p store 
 | AcceptOffer p -> accept_offer p store 
 | UpdateSwap p -> update_swap p store
