# ATF Marketplace 
This document is a description of the ATF marketplace compsed of an assortment of smart-contract.


* A token is minted by the asset owner.
* A single edition of the minted token is added to the marketplace.
* The buyer sends payment, if the correct amount is sent the buyer gets ownership of the token, and the former owner gets funds.
  


**Note: For all swap types, royalties and management fees are deducted from the swap owner's funds at the swap finalisation**


   
## Administration Tools:

**Administration entrypoints are identical in both `marketplace` contract and `auction` contract.**
**Entrypoints which are unique for one of the contracts will be specified with the name of the contract below the entrypoint's name, common entrypoints will be specified as `common`**

---

The contracts have one admin each, with the ability to change some key configurations with the following entrypoints:

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

### **mintNft:**


Mint a new nft with an id corresponding to the token id in the nft contract.
- The new NFT will be listed in the `nft`'s `ledger` with `key = (sender : address, token_id : nat), value = (amount : nat)`.
- The royalties related to the minted token will be listed in the `nft`'s `royalties` with `key = (token_id : nat), value = (royalties : { issuer : address; royalties : nat})`.

**Input parameters:**   

- `metadata_url: string` : A url pointing to the token's metadata specifications
- `royalties: nat` : The royalties related to the token (in 0.01%)
- `amount_ : nat` : the number of token editions.

### **updateRoyalties:**


Change the royalties rate for a specific token.
This entrypoint interacts with `nft`'s `updateRoyalties` entrypoints.
The new royalties information is stored in `nft`'s `royalties` with `key = (token_id : nat), value = (royalties : { issuer : address; royalties : nat})`.
The royalties can be updated only by the token's issuer as sender of the transaction.

**Input parameters:**
- `token_id : nat` 
- `royalties : nat` : The NFT's new royalties rate. 


## Seller Tools:
---

### ***IMPORTANT : before initialising a swap using `addToMarketplace` or `startAuction`, the calling contract has to be confirmed as an operator by the token owner. `nft.updateOperator` entrypoint has to be called first.***

---
### **addToMarketplace**  


This entry-point is used for initializing a fixed-price type swap.

**Input parameters:**  
- `token_id: nat` : The token which is being put on sale.
- `price_xtz: tez` : The token's price (in muTez).
- `start_time: timestamp` : The time at which the token will be put up for sale.
- `end_time: timestamp` : The time at which the token will not be on sale anymore.
- `is_onSale : bool` : Specifies if the token can get offers.

**note: currently one token edition is added to marketplace per initialisation.**

### **updatePrice**


Change the price of a token on the marketplace.

**Input parameters:**

- `swap_id : nat` : The updated swap.
- `value : tez` : The new price (in mutez).
- `start_time : timestamp` : The new time for the beginning of the sale.
- `end_time : timestamp` : The new time for the end of the sale.


### **removeFromMarketplace**

**Common**

This entrypoint is used to remove a swap from the marketplace. The NFT is not burned, just not up for sale.  
**Input parameter:**  
- `nat` : The cancled swap's id.

---

## Buyer Tools:

### **send_offer**

This entrypoint is used by a buyer to make an offer (in tez), available only between `start_time` and `end_time`.
By making an offer, the buyer send his offfer value to the smart contract `marketplace`.
For each swap, a buyer can at most make one offer. To update his offer, he has to cancel his current offer and start by a new offer. 
**Input parameters:**
- `swap_id : nat`
- `start_time : timestamp` : The offer time period start.
- `end_time : timestamp` : The offer time period end.

### **withdraw_offer**


This entrypoint is used by a buyer to cancel his offer for a swap. Then, the buyer recieves from the smart contract `marketplace` his offer value (intez).

**Input parameters:**

- `swap_id : nat` : the id of the swap.

### **accept_offer**

This entrypoint is used by the seller to accept an offer for his swap. If the seller calls this entrypoint within the time limit of the offer, 
then the entrypoint collect is called. Hence, the issuer of the NFT recieves his royality, the plateform the fees and the seller the rest.

**Input parameters:**

- `swap_id : nat` : the swap corresponding to the offer accepted.
- `offer : address` : The offer sender's address.

---

## Collecting tools:

### **collect:**


This entrypoint is called by the winning bidder of transparent auctions to make the `token <-> funds` exchange.  
NFT is transferred to the winning bidder, and funds are transferred to the former NFT owner, deducting a management fee payed to the contract's owner, and royalties payed to the NFT's issuer.

**Input parameter:** 
- `swap_id : nat`  
- `royalties_info : {issuer : address; royalties : nat}` : can be dummy information, as this is used for getting the real royalties info from `nft`'s `getRoyalties` callback entrypoint.
- `amount_ : tez` : For `marketplace` - the actual swap amount (price). For `auction` - can be dummy information as the `collect` entrypoint gathers this information from storage.

# {* TODO - operation description *}

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
- `addToMarketplace` (fixed price)
- `startAuction` (aution)
  
The chosen token's id and the marketplace's address are being reassigned the amount of editions transfered (currently one), and updates that entry at the `ledger`, which maps `(owner, token_id) -> amount_`.

**swap finalisation:**
The NFT's contract's `transfer` entrypoint is called by the marketplace at all swap ends.
This is being done by one of these entrypoints, depending on the swap's type:
- `collect` - winner's address is the address calling the entrypoint.

The chosen winner's address and token's id are being reassigned the amount of editions bought (currently one), and updates that entry at the `ledger`, which maps `(owner, token_id) -> amount_`.

---

## **Operation Schematics:**

**notes:**
- for all following graphs, solid lines represent cross-contract operations and dotted lines represent actions not involving cross-contract operations.
- minting and accepting-offers are operations specific to the `marketplace` contract. Swap initialization and finalization are common to all user-facing contracts (currently `marketplace`, `auction` and `blind auction`)

### **Minting proccess:**

```mermaid
flowchart LR
  A(marketplace.mintNft)
  B(Fa2.mint)
  C(configRoyalties)
  D(issuer, token_id)
  E(token_id)
  F(token_id)
  G(issuer)
  G-->A
  A--->|token_id, token_metadata, amount_|B
  A--->|token_id, royalties|C
  subgraph FA2 contract
  B-.->|amount|D
  B-.->|"(token_id, metadata)"|E
  subgraph token_metadata
  E
  end
  subgraph ledger
  D
  end
  end
  subgraph royalties contract
  subgraph royalties
  F
  end
  C-.->|"{issuer, royalties}"|F
  end
```


<!-- ![minting](/doc_assets/marketplace-mint.png) -->

### **Swap Initialisation:**

```mermaid
flowchart LR
  A(addToMarketplace)
  B(transfer)
  C(swaps)
  D["(owner, token_id)"]
  E["(marketplace, token_id)"]
  A--->|owner, token_id, token_amount|B
  subgraph marketplace
  A-.->C 
  end
  subgraph Fa2
  subgraph ledger
  D-.->|token_amount|E
  end
  B-.->ledger
  end
```

### **Swap Finalization:**

#### **With Callbacks:**

```mermaid
flowchart TD
  A(collectRequest)
  B(collectCallback)
  C(swaps)
  D(swapRoyalties)
  E(token_id)
  F(transfer)
  G(marketplace)
  H(buyer)
  I(offerRoyalties)
  J(seller)
  K(issuer)
  
  subgraph royalties contract
  subgraph royalties
  E
  end
  subgraph getRoyalties
  D
  I
  end
  end
  subgraph Fa2 contract
  F
  subgraph ledger
  G
  H
  end
  end
  subgraph marketplace contract
  subgraph collect
  A
  B
  end
  C
  end
  A-->|"token_id, swap_id, token_amount"|D
  E-.->|"royalties_info"|D
  D-->|"swap_id, token_amount, royalties_info"|B
  B-.->|clear swap_id|C
  B-->|token_id, token_amount|F
  F-.->|token_id|ledger
  B--->|token_price|J
  B--->|royalties|K
  G-.->|token_amount|H
```

```mermaid
  sequenceDiagram
    autonumber
    Alice->>marketplace: collect.collectRequest
    marketplace->>royalties: getRoyalties.swapRoyalties
    royalties->>marketplace: collect.collectCallback
    marketplace->>nft: transfer
    loop transfer
      nft-->>nft: transfer from Alice to Bob
    end
    marketplace->>Bob: transaction(seller_value)
    marketplace->>Issuer: transaction(royalties)
```

#### **With Hangzhou Views:**

```mermaid
flowchart TD
A(collect)
B(get_royalties view)
C(transfer)
D(seller)
E(buyer)
F(swaps)
H(seller)
I(issuer)
subgraph marketplace contract
A
F
end
subgraph royalties contract
B
end
subgraph Fa2 contract
C
subgraph ledger
D
E
end
end
A-.->|token_id|B-.->|royalties_info|A
A-->|token_id, token_amount|C
A--->|royalties|I
A-.->|clear swap_id|F
C-.->|token_id|ledger
D-.->|token_amount|E
A--->|seller_value|H
```

```mermaid
  sequenceDiagram
    autonumber
    Alice->>marketplace: collect
    marketplace-->royalties: getRoyalties
    marketplace->>nft: transfer
    loop transfer
      nft-->>nft: transfer from alice to bob
    end
    marketplace->>Bob: xtz transaction (seller_value)
    marketplace->>Issuer: xtz transaction (issuer_value)
```
    
### **Accepting Offers:**

#### **With Callbacks:**

```mermaid
flowchart TD
A(accept_offer_request)
B(accept_offer_callback)
C(swapRoyalties)
D(offerRoyalties)
E(offers)
F(transfer)
G(buyer)
H(owner)
I(token_id)
J(marketplace)
K(owner)
M(issuer)
subgraph marketplace contract
  subgraph acceptOffer
  A
  B
  end
E
end
subgraph royalties contract
  subgraph royalties
  I
  end
  subgraph getRoyalties
  C
  D
  end
end
subgraph Fa2 contract
    subgraph ledger
    G
    H
    J
    end
  F
end
A-->|"offer_id(token_id, buyer, owner)"|D
I-.->|"royalties_info{issuer, royalties}"|D
D-->|"offer_id, royalties_info"|B
B-->|"token_id, owner_tokens(OPTIONAL), swap_tokens"|F
F-.->|token_id|ledger
H-.->|owner_tokens|G
J-.->|swap_tokens|G
B-.->E
B--->|seller_value|K
B--->|royalties|M
```


#### **with views:**

```mermaid
flowchart TD
A(acceptOffer)
D(get_royalties)
E(offers)
F(transfer)
G(buyer)
H(owner)
I(token_id)
J(marketplace)
K(owner)
M(issuer)
subgraph marketplace contract
A
E
end
subgraph royalties contract
  subgraph royalties
  I
  end

  D

end
subgraph Fa2 contract
    subgraph ledger
    G
    H
    J
    end
  F
end
A-.->|token_id|D
I-.->|"royalties_info{issuer, royalties}"|D
D-.->|royalties_info|A
A-->|"token_id, owner_tokens(OPTIONAL), swap_tokens"|F
F-.->|token_id|ledger
H-.->|owner_tokens|G
J-.->|swap_tokens|G
A-.->E
A--->|seller_value|K
A--->|issuer_value|M
```
