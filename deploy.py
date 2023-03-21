from pytezos import pytezos
from tests import ALICE_KEY, BOB_KEY, BlindAuctionStorage, Env, FA2Storage, MarketplaceStorage, AuctionStorage, RoyaltiesStorage


ALICE_KEY = "edsk3EQB2zJvvGrMKzkUxhgERsy6qdDDw19TQyFWkYNUmGSxXiYm7Q"
ALICE_PK = "tz1Yigc57GHQixFwDEVzj5N1znSCU3aq15td"
BOB_PK = "tz1RTrkJszz7MgNdeEvRLaek8CCrcvhTZTsg"
BOB_KEY = "edsk4YDWx5QixxHtEfp5gKuYDd1AZLFqQhmquFgz64mDXghYYzW6T9"
SHELL = "https://rpc.hangzhou.tzstats.com"

using_params = dict(shell=SHELL, key=ALICE_KEY)
pytezos = pytezos.using(**using_params)
bob_using_params = dict(shell=SHELL, key=BOB_KEY)
bob_pytezos = pytezos.using(**bob_using_params)
send_conf = dict(min_confirmations=1)

nft_init_storage = FA2Storage(ALICE_PK)
royalties_init_storage = RoyaltiesStorage(ALICE_PK)
auction_init_storage = AuctionStorage(ALICE_PK)
marketplace_init_storage = MarketplaceStorage(ALICE_PK)
blind_auction_init_storage = BlindAuctionStorage(ALICE_PK)
nft, _, royalties, auction, marketplace, blind_auction = Env(using_params).deploy_full_app(
    nft_init_storage, royalties_init_storage, auction_init_storage, marketplace_init_storage, blind_auction_init_storage)

print(f"FA2 address: {nft.address}")
print(f"royalties address: {royalties.address}")
print(f"auction address: {auction.address}")
print(f"blind auction address: {blind_auction.address}")
print(f"marketplace address: {marketplace.address}")


# FA2 address: KT1Jk4qK5T3uKogvZqgqbKvGLpc1yjdaWagN
# royalties address: KT1P45RLFHprWLQZ3pp8dtEgSnrDe7NUHmYo
# auction address: KT1H2BkbVDXwRVVUV42kiQzbeYKKG5HU8yxR
# blind auction address: KT1TNhJCQpqzaQuc9JLtVquS9rcan9BN5Djz
# marketplace address: KT1PrAGQ1wdjUUKZ8WVp97RmpQvehVTcj6YQ
