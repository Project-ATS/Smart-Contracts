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

        price = 10 ** 6

        self.assertEqual(
            royalties_contr.storage["royalties"][token_id]["royalties"](
            ), royalties
        )

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
        marketplace.addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now() + 5,
                "end_time": pytezos.now() + 10,
                "token_amount": 1,
                "token_origin": nft.address,
                "recipient": {"general": None}
            }
        ).send(**send_conf)

        self.assertEqual(marketplace.storage["swaps"][0]["owner"](), ALICE_PK)
        self.assertEqual(
            marketplace.storage["swaps"][0]["token_id"](), token_id)
        self.assertEqual(
            marketplace.storage["swaps"][0]["token_price"](), price)
        self.assertEqual(nft.storage["ledger"]
                         [(marketplace.address, token_id)](), 1)
        self.assertEqual(marketplace.storage["next_swap_id"](), 1)

        with self.assertRaises(MichelsonError) as err:
            avail_token_amount = nft.storage["ledger"][(ALICE_PK, token_id)]()
            marketplace.addToMarketplace(
                {
                    "token_id": token_id,
                    "swap_type": {"regular": None},
                    "token_price": price,
                    "start_time": pytezos.now() + 5,
                    "end_time": pytezos.now() + 15,
                    "token_amount": avail_token_amount + 1,
                    "token_origin": nft.address,
                    "recipient": {"general": None}
                }
            ).send(**send_conf)
            self.assertEqual(
                err.exception.args[0]["with"], {
                    "string": "FA2_INSUFFICIENT_BALANCE"}
            )

        token_id = 1000

        foreign_nft.mint({"token_id": token_id, "token_metadata": {},
                         "amount_": 1}).send(**send_conf)

        foreign_nft.update_operators(
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

        marketplace.addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now() + 5,
                "end_time": pytezos.now() + 15,
                "token_amount": 1,
                "token_origin": foreign_nft.address,
                "recipient": {"general": None},
            }
        ).send(**send_conf)

        self.assertEqual(
            foreign_nft.storage["ledger"][(ALICE_PK, token_id)](), 0)
        self.assertEqual(foreign_nft.storage["ledger"][(
            marketplace.address, token_id)](), 1)

    def test_remove_from_marketplace(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, _, _, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 1
        price, token_id = 10 ** 6, marketplace.storage["next_token_id"]()
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

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
        marketplace.addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now() + 5,
                "end_time": pytezos.now() + 15,
                "token_amount": 1,
                "token_origin": nft.address,
                "recipient": {"general": None}
            }
        ).send(**send_conf)

        swap_id = 0
        marketplace.removeFromMarketplace(swap_id).send(**send_conf)

        self.assertEqual(nft.storage["ledger"]
                         [(ALICE_PK, token_id)](), amount_)
        with self.assertRaises(KeyError):
            marketplace.storage["swaps"][swap_id]()

    def test_mint(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, _, royalties_contr, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )
        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 1
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

        self.assertEqual(nft.storage["ledger"]
                         [(ALICE_PK, token_id)](), amount_)
        self.assertEqual(
            nft.storage["token_metadata"][0](),
            {
                "token_id": 0,
                "metadata": {"": b"\x05\x01\x00\x00\x00\x12http://my_metadata"},
            },
        )

        self.assertEqual(
            royalties_contr.storage["royalties"][0](),
            {"issuer": ALICE_PK, "royalties": royalties},
        )
        self.assertEqual(marketplace.storage["next_token_id"](), 1)

    def test_update_royalties(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        _, _, royalties_contr, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )
        token_id = marketplace.storage["next_token_id"]()
        metadata_url, royalties, amount_ = "http://my_metadata", 100, 1
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

        self.assertEqual(
            royalties_contr.storage["royalties"][token_id]["royalties"](
            ), royalties
        )

        new_royalties = 300

        with self.assertRaises(MichelsonError) as err:
            bob_pytezos.contract(marketplace.address).updateRoyalties(
                {"token_id": token_id, "royalties": new_royalties}
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int": "33"})

        marketplace.updateRoyalties(
            {"token_id": token_id, "royalties": new_royalties}
        ).send(**send_conf)

        self.assertEqual(
            royalties_contr.storage["royalties"][token_id]["royalties"](
            ), new_royalties
        )

    def test_collect(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, foreign_nft, royalties_contr, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )
        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 1
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

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
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now() + 5,
                "end_time": pytezos.now() + 15,
                "token_amount": 1,
                "token_origin": nft.address,
                "recipient": {"general": None},
            }
        ).send(**send_conf)
        sleep(5)

        resp = (
            bob_pytezos.contract(marketplace.address)
            .collect({"swap_id": swap_id, "token_amount": 1})
            .with_amount(10 ** 6)
            .send(**send_conf)
        )

        with self.assertRaises(KeyError):
            marketplace.storage["swaps"][swap_id]()

        self.assertEqual(nft.storage["ledger"][(BOB_PK, token_id)](), 1)

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
            marketplace.collect({"swap_id": swap_id, "token_amount": 1}).with_amount(
                price
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int": "103"})

        swap_id = marketplace.storage["next_swap_id"]()

        bob_pytezos.contract(nft.address).update_operators(
            [
                {
                    "add_operator": {
                        "owner": BOB_PK,
                        "operator": marketplace.address,
                        "token_id": token_id,
                    }
                }
            ]
        ).send(**send_conf)

        bob_pytezos.contract(marketplace.address).addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now(),
                "end_time": pytezos.now() + 10,
                "token_amount": 1,
                "token_origin": nft.address,
                "recipient": {"general": None}
            }
        ).send(**send_conf)
        sleep(5)

        with self.assertRaises(MichelsonError) as err:
            marketplace.collect({"swap_id": swap_id, "token_amount": 1}).with_amount(
                price - 1
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int", "123"})

        token_id = 1000
        price = 10 ** 6

        foreign_nft.mint({"token_id": token_id, "token_metadata": {},
                         "amount_": 1}).send(**send_conf)

        foreign_nft.update_operators(
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
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now(),
                "end_time": pytezos.now() + 10,
                "token_amount": 1,
                "token_origin": foreign_nft.address,
                "recipient": {"general": None}
            }
        ).send(**send_conf)
        sleep(5)

        resp = (
            bob_pytezos.contract(marketplace.address)
            .collect({"swap_id": swap_id, "token_amount": 1})
            .with_amount(price)
            .send(**send_conf)
        )

        self.assertEqual(
            foreign_nft.storage["ledger"][(BOB_PK, token_id)](), 1)
        self.assertEqual(
            foreign_nft.storage["ledger"][(ALICE_PK, token_id)](), 0)
        self.assertEqual(foreign_nft.storage["ledger"][(
            marketplace.address, token_id)](), 0)

        internal_operations = resp.opg_result["contents"][0]["metadata"][
            "internal_operation_results"
        ]

        management_fee_rate = marketplace.storage["management_fee_rate"]()
        management_fee = management_fee_rate * price // 10000
        issuer_value = price - management_fee

        # management fee
        self.assertEqual(
            internal_operations[0]["destination"], marketplace.storage["admin"](
            )
        )
        self.assertEqual(int(internal_operations[0]["amount"]), management_fee)

        # issuer
        self.assertEqual(internal_operations[1]["destination"], ALICE_PK)
        self.assertEqual(int(internal_operations[1]["amount"]), issuer_value)

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 100
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

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
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now() + 5,
                "end_time": pytezos.now() + 100,
                "token_amount": 2,
                "token_origin": nft.address,
                "recipient": {"reserved": BOB_PK}
            }
        ).send(**send_conf)
        sleep(10)

        resp = (
            bob_pytezos.contract(marketplace.address)
            .collect({"swap_id": swap_id, "token_amount": 1})
            .with_amount(price)
            .send(**send_conf)
        )

        self.assertEqual(
            nft.storage["ledger"][(BOB_PK, token_id)](), 1)
        self.assertEqual(
            nft.storage["ledger"][(ALICE_PK, token_id)](), 98)
        self.assertEqual(nft.storage["ledger"][(
            marketplace.address, token_id)](), 1)

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
            charlie_pytezos.contract(marketplace.address).collect(
                {"swap_id": swap_id, "token_amount": 1}).with_amount(price).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int", "128"})

    def test_update_admin(self):
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        marketplace = Env().deploy_marketplace(marketplace_init_storage)

        with self.assertRaises(MichelsonError) as err:
            bob_pytezos.contract(marketplace.address).updateMarketplaceAdmin(
                BOB_PK
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int": "110"})

        marketplace.updateMarketplaceAdmin(BOB_PK).send(**send_conf)

        self.assertEqual(marketplace.storage["admin"](), BOB_PK)

    def test_update_swap(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, _, _, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 100
        price = 10 ** 6
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

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
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now(),
                "end_time": pytezos.now() + 4,
                "token_amount": 1,
                "token_origin": nft.address,
                "recipient": {"general": None}}
        ).send(**send_conf)

        new_price = price + 10 ** 6

        marketplace.updateSwap({"swap_id": swap_id, "action": {"add_amount": 7}}).send(
            **send_conf
        )

        self.assertEqual(
            marketplace.storage["swaps"][swap_id]["token_amount"](), 8)
        self.assertEqual(nft.storage["ledger"][(ALICE_PK, token_id)](), 92)
        self.assertEqual(nft.storage["ledger"]
                         [(marketplace.address, token_id)](), 8)

        marketplace.updateSwap(
            {"swap_id": swap_id, "action": {"reduce_amount": 8}}
        ).send(**send_conf)

        with self.assertRaises(KeyError):
            marketplace.storage["swaps"][swap_id]()

        swap_id = marketplace.storage["next_swap_id"]()

        marketplace.addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now(),
                "end_time": pytezos.now() + 4,
                "token_amount": 10,
                "token_origin": nft.address,
                "recipient": {"general": None}
            }
        ).send(**send_conf)

        with self.assertRaises(MichelsonError) as err:
            marketplace.updateSwap(
                {"swap_id": swap_id, "action": {"reduce_amount": 15}}
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int": "130"})

        with self.assertRaises(MichelsonError) as err:
            bob_pytezos.contract(marketplace.address).updateSwap(
                {"swap_id": swap_id, "action": {"reduce_amount": 10}}
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int": "223"})

        marketplace.updateSwap(
            {"swap_id": swap_id, "action": {"update_price": new_price}}
        ).send(**send_conf)
        self.assertEqual(
            marketplace.storage["swaps"][swap_id]["token_price"](), new_price
        )

        with self.assertRaises(MichelsonError) as err:
            marketplace.updateSwap(
                {
                    "swap_id": swap_id,
                    "action": {
                        "update_times": {
                            "start_time": pytezos.now() + 10,
                            "end_time": pytezos.now(),
                        }
                    },
                }
            ).send(**send_conf)
            self.assertEqual(err.exception.args[0]["with"], {"int": "131"})

        start_time, end_time = pytezos.now(), pytezos.now() + 50
        marketplace.updateSwap(
            {
                "swap_id": swap_id,
                "action": {
                    "update_times": {"start_time": start_time, "end_time": end_time}
                },
            }
        ).send(**send_conf)
        self.assertEqual(
            marketplace.storage["swaps"][swap_id]["start_time"](), start_time
        )
        self.assertEqual(
            marketplace.storage["swaps"][swap_id]["end_time"](), end_time)

    def test_send_offer(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, _, _, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 10
        price = 10 ** 6
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

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

        start_time, end_time = pytezos.now(), pytezos.now() + 4
        offer = price + 10 ** 4

        bob_pytezos.contract(marketplace.address).sendOffer(
            {
                "owner": ALICE_PK,
                "token_amount": 5,
                "token_id": token_id,
                "start_time": start_time,
                "end_time": end_time,
                "token_origin": nft.address
            }
        ).with_amount(offer).send(**send_conf)

        self.assertEqual(
            marketplace.storage["offers"][(token_id, BOB_PK, ALICE_PK)](),
            {
                "value": offer,
                "start_time": start_time,
                "end_time": end_time,
                "token_amount": 5,
                "origin": nft.address
            },
        )

    def test_update_offer(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, _, _, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 10
        price = 10 ** 6
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

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

        start_time, end_time = pytezos.now(), pytezos.now() + 4
        offer = price + 10 ** 4

        bob_pytezos.contract(marketplace.address).sendOffer(
            {
                "owner": ALICE_PK,
                "token_amount": 5,
                "token_id": token_id,
                "start_time": start_time,
                "end_time": end_time,
                "token_origin": nft.address
            }
        ).with_amount(offer).send(**send_conf)

        start_time, end_time = pytezos.now(), pytezos.now() + 4
        offer = offer + 10 ** 4

        bob_pytezos.contract(marketplace.address).updateOffer(
            {
                "owner": ALICE_PK,
                "token_amount": 5,
                "token_id": token_id,
                "start_time": start_time,
                "end_time": end_time,
                "token_origin": nft.address
            }
        ).with_amount(offer).send(**send_conf)

        self.assertEqual(
            marketplace.storage["offers"][(token_id, BOB_PK, ALICE_PK)](),
            {
                "token_amount": 5,
                "value": offer,
                "start_time": start_time,
                "end_time": end_time,
                "origin": nft.address
            },
        )

    def test_withdraw_offer(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, _, _, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 10
        price = 10 ** 6
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

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

        start_time, end_time = pytezos.now(), pytezos.now() + 4
        offer = price + 10 ** 4

        bob_pytezos.contract(marketplace.address).sendOffer(
            {
                "owner": ALICE_PK,
                "token_amount": 5,
                "token_id": token_id,
                "start_time": start_time,
                "end_time": end_time,
                "token_origin": nft.address,
            }
        ).with_amount(offer).send(**send_conf)

        self.assertEqual(
            marketplace.storage["offers"][(token_id, BOB_PK, ALICE_PK)](),
            {
                "token_amount": 5,
                "value": offer,
                "start_time": start_time,
                "end_time": end_time,
                "origin": nft.address
            },
        )

        resp = (
            bob_pytezos.contract(marketplace.address)
            .withdrawOffer({"owner": ALICE_PK, "token_id": token_id})
            .send(**send_conf)
        )
        with self.assertRaises(KeyError):
            marketplace.storage["offers"][(token_id, BOB_PK, ALICE_PK)]()

        internal_operations = resp.opg_result["contents"][0]["metadata"][
            "internal_operation_results"
        ]

        self.assertEqual(internal_operations[0]["destination"], BOB_PK)
        self.assertEqual(int(internal_operations[0]["amount"]), offer)
        with self.assertRaises(KeyError):
            marketplace.storage["tokens_on_sale"][token_id]()

    def test_accept_offer(self):
        nft_init_storage = FA2Storage(ALICE_PK)
        royalties_init_storage = RoyaltiesStorage(ALICE_PK)
        marketplace_init_storage = MarketplaceStorage(ALICE_PK)
        nft, _, royalties_contr, marketplace = Env().deploy_marketplace_app(
            nft_init_storage, royalties_init_storage, marketplace_init_storage
        )

        token_id = marketplace.storage["next_token_id"]()

        metadata_url, royalties, amount_ = "http://my_metadata", 100, 100
        price = 10 ** 6
        marketplace.mintNft(
            {"metadata_url": metadata_url, "royalties": royalties, "amount_": amount_}
        ).send(**send_conf)

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

        start_time, end_time = pytezos.now(), pytezos.now() + 10
        offer = price + 10 ** 4

        bob_pytezos.contract(marketplace.address).sendOffer(
            {
                "owner": ALICE_PK,
                "token_id": token_id,
                "token_amount": 10,
                "start_time": start_time,
                "end_time": end_time,
                "token_origin": nft.address
            }
        ).with_amount(offer).send(**send_conf)
        resp = marketplace.acceptOffer(
            {
                "token_id": token_id,
                "buyer": BOB_PK,
            }
        ).send(**send_conf)

        internal_operations = resp.opg_result["contents"][0]["metadata"][
            "internal_operation_results"
        ]

        management_fee_rate = marketplace.storage["management_fee_rate"]()
        royalties_rate = royalties_contr.storage["royalties"][token_id]["royalties"](
        )

        management_fee = offer * management_fee_rate // 10000
        royalties = royalties_rate * offer // 10000
        issuer_value = offer - (management_fee + royalties)

        # management fee
        self.assertEqual(
            internal_operations[0]["destination"], marketplace.storage["admin"](
            )
        )
        self.assertEqual(int(internal_operations[0]["amount"]), management_fee)

        # royalties
        self.assertEqual(internal_operations[1]["destination"], ALICE_PK)
        self.assertEqual(int(internal_operations[1]["amount"]), royalties)

        # issuer
        self.assertEqual(internal_operations[2]["destination"], ALICE_PK)
        self.assertEqual(int(internal_operations[2]["amount"]), issuer_value)

        marketplace.addToMarketplace(
            {
                "token_id": token_id,
                "swap_type": {"regular": None},
                "token_price": price,
                "start_time": pytezos.now(),
                "end_time": pytezos.now() + 10,
                "token_amount": 10,
                "token_origin": nft.address,
                "recipient": {"general": None}
            }
        ).send(**send_conf)

        bob_pytezos.contract(marketplace.address).sendOffer(
            {
                "owner": ALICE_PK,
                "token_id": token_id,
                "token_amount": 50,
                "start_time": pytezos.now(),
                "end_time": pytezos.now() + 50,
                "token_origin": nft.address
            }
        ).with_amount(10 ** 6).send(**send_conf)
        sleep(5)
        marketplace.acceptOffer(
            {
                "token_id": token_id,
                "buyer": BOB_PK,
            }
        ).send(**send_conf)
