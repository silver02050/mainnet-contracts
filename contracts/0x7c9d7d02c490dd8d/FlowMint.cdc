/* 
*
*  This is an example implementation of a Flow Non-Fungible Token.
*  This contract does not implement any sophisticated classification
*  system for its NFTs. It defines a simple NFT with minimal metadata.
*   
*/

//import NonFungibleToken from 0x631e88ae7f1d7c20 test
import NonFungibleToken from "../0x1d7e57aa55817448/NonFungibleToken.cdc"
import MetadataViews from "../0x1d7e57aa55817448/MetadataViews.cdc"

pub contract FlowMint: NonFungibleToken {

    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub struct FlowMintData{
        pub let id: UInt64
        pub let type: String
        pub let url: String

        init(_id: UInt64, _type: String, _url: String){
            self.id = _id
            self.type = _type
            self.url = _url
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let type: String
        pub let url: String
    
        init(
            id: UInt64,
            type: String,
            url: String,
        ) {
            self.id = id
            self.type = type
            self.url = url
        }
    
        pub fun getViews(): [Type] {
            return [ Type<FlowMintData>() ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<FlowMintData>():
                return FlowMintData(
                    _id: self.id,
                    _type: self.type,
                    _url: self.url
                )
            }
            return nil
        }
    }

    pub resource interface FlowMintCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFlowMint(id: UInt64): &FlowMint.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow FlowMint reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: FlowMintCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes an NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @FlowMint.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
 
        pub fun borrowFlowMint(id: UInt64): &FlowMint.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &FlowMint.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let FlowMintNFT = nft as! &FlowMint.NFT
            return FlowMintNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

     pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            type: String,
            url: String,
        ) {

            // create a new NFT
            var newNFT <- create NFT(
                id: FlowMint.totalSupply,
                type: type,
                url: url
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            FlowMint.totalSupply = FlowMint.totalSupply + UInt64(1)
        }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/FlowMintCollection
        self.CollectionPublicPath = /public/FlowMintCollection
        self.MinterStoragePath = /storage/FlowMintMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&FlowMint.Collection{NonFungibleToken.CollectionPublic, FlowMint.FlowMintCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}