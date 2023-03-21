
#include "../common/interface.mligo"

type storage = 
[@layout:comb]
{
    admin : address;
    proxy : address set;
    royalties : (token_id, royalties_info) big_map;
    paused : bool;
}

type return = operation list * storage

type parameter = 
| UpdateAdmin of update_admin_param
| UpdateProxy of update_proxy_param
| ConfigRoyalties of update_royalties_param
| SetPause of bool

[@inline] let error_CONTRACT_IS_PAUSED = 401n
[@inline] let error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT = 402n
[@inline] let error_ONLY_PROXY_CAN_CALL_THIS_ENTRYPOINT = 403n
[@inline] let error_ADDRESS_ALREADY_PROXY = 404n
[@inline] let error_ADDRESS_NOT_PROXY = 405n
[@inline] let error_ROYALTIES_TOO_HIGH = 406n
[@inline] let error_ONLY_ISSUER_CAN_CALL_THIS_ENTRYPOINT = 407n

let set_pause (paused : bool) (store : storage) : return =
    if Tezos.sender <> store.admin then
        (failwith(error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT) : return)
    else
        ([] : operation list), { store with paused = paused }

let update_admin (param : update_admin_param) (store : storage) : return =
    if Tezos.sender <> store.admin then
        (failwith(error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT) : return)
    else
        ([] : operation list), {store with admin = param}

let update_proxy (action : update_proxy_param) (store : storage) : return =
  if Tezos.sender <> store.admin then
    failwith error_ONLY_ADMIN_CAN_CALL_THIS_ENTRYPOINT
  else
    match action with
    | Add_proxy p -> 
    if Set.mem p store.proxy then
      (failwith(error_ADDRESS_ALREADY_PROXY) : return)
    else
      ([] : operation list), { store with proxy = Set.add p store.proxy }
    | Remove_proxy p ->
    if Set.mem p store.proxy = false then
      (failwith(error_ADDRESS_NOT_PROXY) : return)
    else
      ([] : operation list), { store with proxy = Set.remove p store.proxy }


let configure_royalties (param : update_royalties_param) (store : storage) : return =
    if store.paused then
        (failwith(error_CONTRACT_IS_PAUSED) : return)
    else if Set.mem Tezos.sender store.proxy = false then
        (failwith(error_ONLY_PROXY_CAN_CALL_THIS_ENTRYPOINT) : return)
    else if param.royalties > 2500n then
        (failwith error_ROYALTIES_TOO_HIGH : return)
    else
        match Big_map.find_opt param.token_id store.royalties with
            | None -> 
            let royalties_info = {
              issuer = Tezos.source;
              royalties = param.royalties;
            } in
            ([] : operation list), {store with royalties = Big_map.update param.token_id (Some royalties_info) store.royalties}
            | Some r -> 
            if r.issuer <> Tezos.source then
                (failwith error_ONLY_ISSUER_CAN_CALL_THIS_ENTRYPOINT : return)
            else 
                let new_royalties_info = { r with royalties = param.royalties} in
                ([] : operation list), {store with royalties = Big_map.update param.token_id (Some new_royalties_info) store.royalties}


let main (action, store : parameter * storage) : return =
match action with
| UpdateAdmin p -> update_admin p store
| UpdateProxy p -> update_proxy p store
| ConfigRoyalties p -> configure_royalties p store
| SetPause p -> set_pause p store


[@view] let get_royalties (token_id, store : token_id * storage) : royalties_info =
    match Big_map.find_opt token_id store.royalties with
    | None -> {
              issuer = Tezos.self_address;
              royalties = 0n;
            }
    | Some r -> r 