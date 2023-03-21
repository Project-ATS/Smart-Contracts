# ATF Marketplace 
This contract is a marketplace with different types of swap methods:
- fixed price
- auction with two methods:
  - *transparent auction:* everyone can see who placed what bid. when a new highest bid is placed, the bidder who placed the former highest bidder gets automatic refund.
  - *blind auction:* all bids are consealed. refunding and winnings are handed out by the swap owner when the auction ends.

## Operations:

---

**For fixed-price swaps:**

* A token is minted by the asset owner.
* A single edition of the minted token is added to the marketplace.
* The buyer sends payment, if the corect amount is sent the buyer gets ownership of the token, and the former owner gets funds.
  
**For auction swaps:**

* A token is minted by the asset owner.
* An auction is being initialised with its different settings chosen.
* Bidders place bids at the pre-determined auction period.
* At the end of the bidding period, if a set of conditions is met, the highest bidder gets ownership of the token, and the former owner gets funds.

**Note: For all swap types, royalties and management fees are deducted from the swap owner's funds at the swap finalisation**
   

## Administration Tools:

---

The marketplace has one admin, with the ability to change some key configurations with the following entrypoints:

### **updateAdmin:**
Change the admin address. The former admin forfeits admin priveleges, as there is only one admin.  
**Input Parameter:**  
-  `address`: The new admin's address.

### **updateNftAddress:** 
Change the NFT contract address.  
**Input parameter:**  
-  `address`: The new NFT contract address.

### **updateFee:**  
Change the management fee. The fee applies to all swaps under the contract.  
**Input parameter:**  
- `nat`: The new management fee.  

**note: the management fee applied to swaps is specified by `management_fee_rate / 10,000`, or more simply `management_fee_rate * 0.01%`, to allow two decimals.**

## NFT Issuer Tools:
---

### **updateRoyalties:**
Change the royalties rate for a specific token.

**Input parameters:**
- `token_id : nat` 
- `royalties : nat` : The NFT's new royalties rate. 


## Seller Tools:
---

### **mintNft:**
Mint a new nft with an id corresponding to the token id in the nft contract.

**Input parameters:**   

- `metadata_url: string` : A url pointing to the token's metadata specifications
- `royalties: nat` : The royalties related to the token (in 0.01%)
- `amount_ : int` : the number of token editions.

---

### ***IMPORTANT : before initialising a swap using `addToMarketplace` and `startAuction`, the calling contract (`auction`) has to be confirmed as an operator by the token owner. `nft.updateOperator` entrypoint has to be called first.***

---
### **addToMarketplace**  
This entry-point is used for initializing a fixed-price type swap.

**Input parameters:**  
- `token_id: nat` : The token which is being put on sale.
- `price_xtz: tez` : The token's price (in muTez)

**note: currently one token edition is added to marketplace per initialisation.**

### **startAuction**
This entry-point is used for initializing an auction type swap.  
**Input arameters:**  
- `token_id : nat` : The token which is being put on auction.
- `start_time : timestamp` : The time at which the auction will start (can be the present time or some future time).
- `period : nat` : The auction's period (in seconds).
- `starting_price : tez` : The initial price of the token (in muTez).
- `is_blind : bool` : Determines if the auction will be transperant or blind.
- `reserved_price_hashed : bytes` : Sets a hidden 'reserved price': a price under which the seller can choose to accept or not accept the highest offer the hash is composed of the price and a `secret`, and is revealed at a later time with the same values.
- `reveal_time : int` : A period (in seconds) after the auction's end time at which the seller can reveal the reserved price and accept lower offers.
- `adding_period : int` : A period (30 - 300 seconds) before the auction's end time, at which if a bidder places a bid the auction period is prolonged.
- `extra_duration : int` : The duration (in seconds) that is being added to the auction period if a bid is placed at the `adding_period`.

**note: currently one token edition is added to marketplace per initialisation.**

### **revealPrice:**
This entrypoint is used by the seller in auction swaps that a reserved-price was set for. 
The seller can reveal the price in a period after the auction ends. When the price is revealed the seller can choose if a highest bid which is lower than the reserved price will be permitted to win the auction.
**Input parameters:**
- `swap_id : nat` : The id of the swap owned by the seller.
- `revealed_price` a record of type `{ price : tez; secret : string}` : the reserved price and the secret that were set in the `start_auction` entrypoint, for comparison.
- `permit_lower : bool` : sets permission for a highest bid that's lower than the reserved price to win the auction.

### **removeFromMarketplace**
This entrypoint is used to remove a swap from the marketplace. The NFT is not burned, just not up for sale.  
**Input parameter:**  
- `swap_id : nat` : The cancled swap's id.

---

## Buyer Tools:

### **bid:**  
This entrypoint is used by bidders for 'transparent' auctions. When a new highest bid is placed, the former highest bidder is refunded automatically.
**Input parameter:**
- `swap_id : nat`  

**this entrepoint has to be called with an amount transfered**  

### **blindBid:**
This entrypoint handles bids for a blind auction.
The bidder sends an amount, along with the swap's id and a hash which is an incripted `(value, fake, secret)` tuple.  
Here `value` is some value in tez, either the correct `amount` that was sent, or some fake value.   
If `value` is fake, then `fake` is set to `true`, or else the bid will be invalid at the revealation proccess and the corresponding `amount` will be kept by the contract.  
`secret` is some secret of type `string`, which is used for the revealation proccess.  
**Input parameters:**
- `(swap_id, hash) : nat * bytes`  

**this entrepoint has to be called with an amount transfered** 

### **revealBids:**
This entrypoint is used by the bidder after the auction's `end_time` to reveal the blind bids placed by them.  
The values sent are compared by the contract to the hash sent at the bidding period, and are determined as valid or invalid.   
Invalid values sent will be penalized by the marketplace keeping the amount that was attached to those values, valid values will either (the highest not fake amount) be listed as `pending_returns` : bids that are later compared to other bidders `pending_returns` and determine the auction's winner, or returned (fake amounts or lower bids).
**Input parameters:**
- `swap_id : nat`
- `revealed_bids : reveald_bids list` at which:
-  - `amount_ : tez` : The amount that was transferred at the `blindBid` entrypoint call corresponding with the values.
-  - `value : tez` : The same value that was sent as part of the hash sent at the `blindBid` entrypoint call.
-  - `fake : bool` : The same fake `true/false` that was sent as part of the hash sent at the `blindBid` entrypoint call.
-  - `secret : string` : The same `secret` that was sent as part of the hash sent at the `blindBid` entrypoint call.

The contract then hashes a tuple `(value, fake, secret)`, and compares the resault with the bis's hash.

**comparison outcome:**

- If the list of hashed parameters doesn't fit the list of hashes from the bidding stage, the contract fails and amounts are kept by the contract.
- If a bid's `fake` is `false`, and the `amount_` is not equal to the `value`, the bid is determined as invalid and `amount_` is kept by the contract as a penalty.
- If a bid's `fake` is `true` and the `amount_` is greater than `value`, the bid is valid and fake, and is refunded.
- If a bid's `fake` is `false` and the `amount_` is the highest of all `amount_`s sent by the bidder, the bid is listed in `pending_returns` and competes for winning the auction.
- All other combinations are refunded.  

---

## Collecting tools:

### **collect:**
This entrypoint is called by the winning bidder of transparent auctions to make the `token <-> funds` exchange.  
NFT is transferred to the winning bidder, and funds are transferred to the former NFT owner, deducting a management fee payed to the contract's owner, and royalties payed to the NFT's issuer.

**Input parameter:** 
- `swap_id`  

This entrypoint is called by the seller of the NFT to finalise a blind auction.  
The list of `pending_returns` are being compared, and a winner is determined.  
NFT is transferred to the winning bidder, and funds are transferred to the former NFT owner, deducting a management fee payed to the contract's owner, and royalties payed to the NFT's issuer.

---
## Cross-Contract Interactions:

The marketplace contract interacts with a single `FA2` NFT contract.
Interactions are made at a few different stages of operation:

**minting:**
The NFT contract's `mint` entrypoint is called by the marketplace at the token minting proccess, using the `mintNft` entrypoint.
The parameters sent to the NFT contract are:
- `token_id` : the minted NFT's id, assigned iteratively by the marketplace.
- `metadata_url` : a url pointing to the token's metadata.
The NFT contract assigns the marketplace `mintNft` entrypoint's caller's address to the `token_id`, and adds that assignment to the `ledger`.
The NFT contract assigns the same `token_id` the `metadata_url`, and adds that assignment to the `token_metadata` map.
- `amount_` : the number of editions the token will have.

**swap initialisation:**
The NFT's contract's `transfer` entrypoint is called by the marketplace at all swap starts.
This is being done by one of these entrypoints, depending on the swap's type:
- `addToMarketplace`
- `startAuction`
  
The chosen token's id and the marketplace's address are being reassigned the amount of editions transfered (currently one), and updates that entry at the `ledger`, which maps `(owner, token_id) -> amount_`.

**swap finalisation:**
The NFT's contract's `transfer` entrypoint is called by the marketplace at all swap ends.
This is being done by one of these entrypoints, depending on the swap's type:
- `collect` - winner's address is the address calling the entrypoint.
- `collectBlind` - winner's address is determined by comparison of the auction's `pending_returns`.

The chosen winner's address and token's id are being reassigned the amount of editions bought (currently one), and updates that entry at the `ledger`, which maps `(owner, token_id) -> amount_`.

---

## **Operation Schematics:**

### **Minting proccess:**

![minting](doc_assets/marketplace-mint.png)

## **Swap Initialisation:**

![adding](doc_assets/marketplace-add.png)

## **Swap Finalisation:**

![collecting](doc_assets/marketplace-collect.png)
