import NonFungibleToken from "../0x1d7e57aa55817448/NonFungibleToken.cdc"
import MetadataViews from "../0x1d7e57aa55817448/MetadataViews.cdc"

// EnemyMetal NFT Smart contract 
//
pub contract EnemyMetal: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Burn(id: UInt64)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, metadata: String, claimsSize: Int)
    pub event Claimed(id: UInt64)

    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64

    // Named paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // Composite data structure to represents, packs and upgrades functionality
    pub struct NFTData {
        pub let editionID: UInt64
        pub let metadata: String
        pub let components: [UInt64]
        pub let claims: [NFTData]
        init(metadata: String, claims: [NFTData]) {
            self.editionID = 0
            self.metadata = metadata
            self.components = []
            self.claims = claims
        }
    }

    // NFT
    // A Enemy metal NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        // NFT's ID
        pub let id: UInt64
        // NFT's data
        pub let data: NFTData

        // initializer
        //
        init(initID: UInt64, initData: NFTData) {
            self.id = initID
            self.data = initData
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.data.metadata,
                        description: "",
                        thumbnail: MetadataViews.HTTPFile(
                            url: "https://api.enemymetal.com/api/v1/nfts/thumbnail?metadata_hash=".concat(self.data.metadata)
                        )
                    )
            }

            return nil
        }

        destroy() {
            emit Burn(id: self.id)
        }
    }

    pub resource interface EnemyMetalCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowEnemyMetalNFT(id: UInt64): &EnemyMetal.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result != nil) && (result?.id == id):
                    "Cannot borrow EnemyMetalNFT reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of EnemyMetal NFTs owned by an account
    //
    pub resource Collection: EnemyMetalCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @EnemyMetal.NFT
            let id: UInt64 = token.id
            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowEnemyMetalNFT
        // Gets a reference to an NFT in the collection as a EnemyMetalNFT,
        // exposing all of its fields.
        // This is safe as there are no functions that can be called on the EnemyMetal.
        //
        pub fun borrowEnemyMetalNFT(id: UInt64): &EnemyMetal.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &EnemyMetal.NFT
            } else {
                return nil
            }
        }

        // claim
        // resource owners when claiming, Mint new NFTs and burn the claimID resource.
        pub fun claim(claimID: UInt64) {
            pre {
                self.ownedNFTs[claimID] != nil : "missing claim NFT"
            }

            let claimTokenRef = self.borrowEnemyMetalNFT(id:claimID)!
            if claimTokenRef.data.claims.length == 0 {
                panic("Claim NFT has empty claims")
            }
            
            for claim in claimTokenRef.data.claims {
                EnemyMetal.totalSupply = EnemyMetal.totalSupply + (1 as UInt64)
                emit Minted(id: EnemyMetal.totalSupply, metadata: claim.metadata, claimsSize: claim.claims.length)
                // deposit it in the recipient's account using their reference
                self.deposit(token: <-create EnemyMetal.NFT(initID: EnemyMetal.totalSupply, initData: claim))
            }

            let claimToken <- self.ownedNFTs.remove(key: claimID) ?? panic("missing claim NFT")
            destroy claimToken
            emit Claimed(id: claimID)
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {
        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, data: NFTData) {
            EnemyMetal.totalSupply = EnemyMetal.totalSupply + (1 as UInt64)
            emit Minted(id: EnemyMetal.totalSupply, metadata: data.metadata, claimsSize: data.claims.length)
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-create EnemyMetal.NFT(initID: EnemyMetal.totalSupply, initData: data))
        }
    }

    // initializer
    //
    init() {
        self.totalSupply = 0
        
        self.CollectionStoragePath = /storage/EnemyMetalCollection
        self.CollectionPublicPath = /public/EnemyMetalCollection
        self.MinterStoragePath = /storage/EnemyMetalMinter

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
