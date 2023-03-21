from time import sleep
import unittest
from dataclasses import dataclass
from pytezos import ContractInterface, pytezos
from pytezos.contract.result import OperationResult
from pytezos.rpc.errors import MichelsonError


# sandbox
ALICE_KEY = "edsk3EQB2zJvvGrMKzkUxhgERsy6qdDDw19TQyFWkYNUmGSxXiYm7Q"
ALICE_PK = "tz1Yigc57GHQixFwDEVzj5N1znSCU3aq15td"
BOB_PK = "tz1RTrkJszz7MgNdeEvRLaek8CCrcvhTZTsg"
BOB_KEY = "edsk4YDWx5QixxHtEfp5gKuYDd1AZLFqQhmquFgz64mDXghYYzW6T9"
CHARLIE_PK = "tz1iYCR11SMJcpAH3egtDjZRQgLgKX6agU7s"
CHARLIE_KEY = "edsk3G87qnDZhR74qYDFAC6nE17XxWkvPJtWpLw4vfeZ3otEWwwskV"

SHELL = "http://localhost:20000"

_using_params = dict(shell=SHELL, key=ALICE_KEY)
pytezos = pytezos.using(**_using_params)

bob_using_params = dict(shell=SHELL, key=BOB_KEY)
bob_pytezos = pytezos.using(**bob_using_params)

charlie_using_params = dict(shell=SHELL, key=CHARLIE_KEY)
charlie_pytezos = pytezos.using(**charlie_using_params)

send_conf = dict(min_confirmations=1)


@dataclass
class FA2Storage:
    admin: str
    proxy: str = ALICE_PK


@dataclass
class RoyaltiesStorage:
    admin: str
    proxy: str = ALICE_PK


@dataclass
class MarketplaceStorage:
    admin: str
    nft_address: str = ALICE_PK
    royalties_address: str = ALICE_PK


class Env:
    def __init__(self, using_params=None):
        self.using_params = using_params or _using_params

    def deploy_nft(self, init_storage: FA2Storage):
        with open("../michelson/nft.tz", encoding="UTF-8") as mich_file:
            michelson = mich_file.read()

        fa2 = ContractInterface.from_michelson(
            michelson).using(**self.using_params)
        storage = {
            "admin": init_storage.admin,
            "ledger": {},
            "operators": {},
            "metadata": {"metadata": {}, "token_defs": []},
            "token_metadata": {},
            "proxy": init_storage.proxy,
            "paused": False,
        }
        opg = fa2.originate(initial_storage=storage).send(**send_conf)
        fa2_addr = OperationResult.from_operation_group(opg.opg_result)[
            0
        ].originated_contracts[0]
        fa2 = pytezos.using(**self.using_params).contract(fa2_addr)

        return fa2

    def deploy_royalties(self, init_storage: RoyaltiesStorage):
        with open("../michelson/royalties.tz", encoding="UTF-8") as mich_file:
            michelson = mich_file.read()

        royalties = ContractInterface.from_michelson(michelson).using(
            **self.using_params
        )
        storage = {
            "admin": init_storage.admin,
            "proxy": init_storage.proxy,
            "royalties": {},
            "paused": False,
        }
        opg = royalties.originate(initial_storage=storage).send(**send_conf)
        royalties_addr = OperationResult.from_operation_group(opg.opg_result)[
            0
        ].originated_contracts[0]
        royalties = pytezos.using(**self.using_params).contract(royalties_addr)

        return royalties

    def deploy_marketplace(self, init_storage: MarketplaceStorage):
        with open("../michelson/marketplace.tz", encoding="UTF-8") as mich_file:
            michelson = mich_file.read()
        marketplace = ContractInterface.from_michelson(michelson).using(
            **self.using_params
        )
        storage = {
            "admin": init_storage.admin,
            "nft_address": init_storage.nft_address,
            "royalties_address": init_storage.royalties_address,
            "next_token_id": 0,
            "next_swap_id": 0,
            "tokens": {},
            "swaps": {},
            "offers": {},
            "management_fee_rate": 250,
            "paused": False,
        }
        opg = marketplace.originate(initial_storage=storage).send(**send_conf)
        marketplace_address = OperationResult.from_operation_group(opg.opg_result)[
            0
        ].originated_contracts[0]
        marketplace = pytezos.using(
            **self.using_params).contract(marketplace_address)
        return marketplace

    def deploy_marketplace_app(
        self,
        nft_init_storage: FA2Storage,
        royalties_init_storage: RoyaltiesStorage,
        marketplace_init_storage: MarketplaceStorage,
    ):
        marketplace = self.deploy_marketplace(marketplace_init_storage)
        nft_init_storage.proxy = [marketplace.address, ALICE_PK]
        royalties_init_storage.proxy = [marketplace.address]
        nft = self.deploy_nft(nft_init_storage)
        foreign_nft = self.deploy_nft(nft_init_storage)
        royalties_contr = self.deploy_royalties(royalties_init_storage)
        marketplace.updateNftAddress(nft.address).send(**send_conf)
        marketplace.updateRoyaltiesAddress(
            royalties_contr.address).send(**send_conf)

        return nft, foreign_nft, royalties_contr, marketplace


class TestMarketplace(unittest.TestCase):
    def test_add_to_marketplace(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, foreign_nft, royalties_contr, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 100
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

        starting_price = 2 * 10 ** 6
        duration = 300
        price = 10 ** 6

        nft.update_operators(
            [
                {
                    "add_operator": {
                        "owner": ALICE_PK,
                        "operator": marketplace.address,
                        "token_id": token_id,
                    }
                }
            ]
        ).send(**send_conf)

        with self.assertRaises(MichelsonError) as err:
            marketplace.addToMarketplace(
                {
                    "token_id": token_id,
                    "swap_type": {"dutch": {"starting_price": starting_price, "duration": duration, }},
                    "token_price": price,
                    "start_time": pytezos.now() + 5,
                    "end_time": pytezos.now() + 10,
                    "token_amount": 1,
                    "token_origin": nft.address,
                    "recipient": {"general": None}
                }
            ).send(**send_conf)

            self.assertEqual(err.exception.args[0]["with"], {"int": "127"})

        swap_id = marketplace.storage["next_swap_id"]()
        marketplace.addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"dutch": {"starting_price": starting_price, "duration": duration, }},
                "token_price": price,
                "start_time": pytezos.now() + 5,
                "end_time": pytezos.now() + duration * 2,
                "token_amount": 1,
                "token_origin": nft.address,
                "recipient": {"general": None}
            }
        ).send(**send_conf)
        self.assertEqual(
            marketplace.storage["swaps"][swap_id]["is_dutch"](), True)
        self.assertEqual(
            marketplace.storage["swaps"][swap_id]["starting_price"](), starting_price)
        self.assertEqual(
            marketplace.storage["swaps"][swap_id]["duration"](), duration)
        sleep(10)

        with self.assertRaises(MichelsonError) as err:
            marketplace.updateSwap({"swap_id": swap_id, "action": {"add_amount": 1}}).send(
                **send_conf
            )
            self.assertEqual(err.exception.args[0]["with"], {"int", "126"})
        with self.assertRaises(MichelsonError) as err:
            marketplace.updateSwap(
                {"swap_id": swap_id, "action": {"reduce_amount": 1}}
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int", "126"})
        with self.assertRaises(MichelsonError) as err:
            marketplace.updateSwap(
                {"swap_id": swap_id, "action": {"update_price": 2 * price}}
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int", "126"})
        with self.assertRaises(MichelsonError) as err:
            marketplace.updateSwap(
                {
                    "swap_id": swap_id,
                    "action": {
                        "update_times": {"start_time": pytezos.now(), "end_time": pytezos.now() + 100}
                    },
                }
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int", "126"})

    def test_collect(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, foreign_nft, royalties_contr, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 100
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

        starting_price = 2 * 10 ** 6
        duration = 300
        price = 10 ** 6

        nft.update_operators(
            [
                {
                    "add_operator": {
                        "owner": ALICE_PK,
                        "operator": marketplace.address,
                        "token_id": token_id,
                    }
                }
            ]
        ).send(**send_conf)
        swap_id = marketplace.storage["next_swap_id"]()
        marketplace.addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"dutch": {"starting_price": starting_price, "duration": duration}},
                "token_price": price,
                "start_time": pytezos.now() + 5,
                "end_time": pytezos.now() + duration * 2,
                "token_amount": 1,
                "token_origin": nft.address,
                "recipient": {"general": None}
            }
        ).send(**send_conf)

        sleep(10)
        current_price = ((marketplace.storage["swaps"][swap_id]["start_time"](
        ) + duration - pytezos.now()) // duration) * (starting_price - price) + price

        resp = (
            bob_pytezos.contract(marketplace.address)
            .collect({"swap_id": swap_id, "token_amount": 1})
            .with_amount(current_price)
            .send(**send_conf))

        internal_operations = resp.opg_result["contents"][0]["metadata"][
            "internal_operation_results"
        ]

        royalties = (
            royalties_contr.storage["royalties"][token_id]["royalties"]()
            * price
            // 10000
        )
        management_fee_rate = marketplace.storage["management_fee_rate"]()
        management_fee = management_fee_rate * price // 10000
        issuer_value = price - (royalties + management_fee)

        # royalties
        self.assertEqual(internal_operations[1]["destination"], ALICE_PK)
        self.assertEqual(int(internal_operations[1]["amount"]), royalties)

        # management fee
        self.assertEqual(
            internal_operations[0]["destination"], marketplace.storage["admin"](
            )
        )
        self.assertEqual(int(internal_operations[0]["amount"]), management_fee)

        # issuer
        self.assertEqual(internal_operations[2]["destination"], ALICE_PK)
        self.assertEqual(int(internal_operations[2]["amount"]), issuer_value)

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 100
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

        starting_price = 2 * 10 ** 6
        duration = 300
        price = 10 ** 6

        nft.update_operators(
            [
                {
                    "add_operator": {
                        "owner": ALICE_PK,
                        "operator": marketplace.address,
                        "token_id": token_id,
                    }
                }
            ]
        ).send(**send_conf)
        swap_id = marketplace.storage["next_swap_id"]()
        marketplace.addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"dutch": {"starting_price": starting_price, "duration": duration}},
                "token_price": price,
                "start_time": pytezos.now() + 5,
                "end_time": pytezos.now() + duration * 2,
                "token_amount": 5,
                "token_origin": nft.address,
                "recipient": {"reserved": BOB_PK}
            }
        ).send(**send_conf)

        sleep(10)
        current_price = ((marketplace.storage["swaps"][swap_id]["start_time"](
        ) + duration - pytezos.now()) // duration) * (starting_price - price) + price

        resp = (
            bob_pytezos.contract(marketplace.address)
            .collect({"swap_id": swap_id, "token_amount": 1})
            .with_amount(current_price)
            .send(**send_conf))

        internal_operations = resp.opg_result["contents"][0]["metadata"][
            "internal_operation_results"
        ]

        royalties = (
            royalties_contr.storage["royalties"][token_id]["royalties"]()
            * price
            // 10000
        )
        management_fee_rate = marketplace.storage["management_fee_rate"]()
        management_fee = management_fee_rate * price // 10000
        issuer_value = price - (royalties + management_fee)

        # royalties
        self.assertEqual(internal_operations[1]["destination"], ALICE_PK)
        self.assertEqual(int(internal_operations[1]["amount"]), royalties)

        # management fee
        self.assertEqual(
            internal_operations[0]["destination"], marketplace.storage["admin"](
            )
        )
        self.assertEqual(int(internal_operations[0]["amount"]), management_fee)

        # issuer
        self.assertEqual(internal_operations[2]["destination"], ALICE_PK)
        self.assertEqual(int(internal_operations[2]["amount"]), issuer_value)

        with self.assertRaises(MichelsonError) as err:
            current_price = ((marketplace.storage["swaps"][swap_id]["start_time"](
            ) + duration - pytezos.now()) // duration) * (starting_price - price) + price

            resp = (
                charlie_pytezos.contract(marketplace.address)
                .collect({"swap_id": swap_id, "token_amount": 1})
                .with_amount(current_price)
                .send(**send_conf))
