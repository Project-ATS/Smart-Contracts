#include "../../common/functions.mligo"


[@inline]
let add_single_token (param : string) (store : storage) : return =
   let sender_address = (Tezos.get_self_address ()) in
    if (Tezos.get_sender ()) <> store.multisig then
        let func () =
          match (Tezos.get_entrypoint_opt "%addSingleToken" sender_address : string contract option) with
          | None -> (failwith("no addSingleToken entrypoint") : operation list)
          | Some add_single_token_entrypoint -> [Tezos.transaction param 0mutez add_single_token_entrypoint] in
      (prepare_multisig "addSingleToken" param func store), store
    else
    ([] : operation list), {store with single_tokens = Set.add param store.single_tokens}
