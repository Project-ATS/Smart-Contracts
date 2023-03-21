alias ligo="docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:0.31.0"
ligo compile contract nft/nft.mligo --protocol hangzhou > michelson/nft.tz
ligo compile contract marketplace/marketplace.mligo --protocol hangzhou  > michelson/marketplace.tz
ligo compile contract auction/auction.mligo --protocol hangzhou > michelson/auction.tz
ligo compile contract blind_auction/blind_auction.mligo --protocol hangzhou > michelson/blind_auction.tz
ligo compile contract royalties/royalties.mligo --protocol hangzhou > michelson/royalties.tz
