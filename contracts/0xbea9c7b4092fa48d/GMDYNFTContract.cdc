import NonFungibleToken from "../0x1d7e57aa55817448/NonFungibleToken.cdc"
import MetadataViews from "../0x1d7e57aa55817448/MetadataViews.cdc"

pub contract GMDYNFTContract: NonFungibleToken {

    // Initialize the total supply
    pub var totalSupply: UInt64

    //variable that stores the account address that created the contract
    pub let privateKey: Address

    //link public of the collection
    pub let CollectionPublicPath : PublicPath

    //storagre of the collection
    pub let CollectionStoragePath : StoragePath

    //total collection created
    pub var totalCollection: UInt64

    pub event ContractInitialized()
    /* withdraw event */
    pub event Withdraw(id: UInt64, from: Address?)
    /* Event that is issued when an NFT is deposited */
    pub event Deposit(id: UInt64, to: Address?)
    /* event that is emitted when a new collection is created */
    pub event NewCollection(collectionName: String, collectionID:UInt64)
    /* Event that is emitted when new NFTs are cradled*/
    pub event NewNFTsminted(amount: UInt64)
    /* Event that is emitted when an NFT collection is created */
    pub event CreateNFTCollection(amount: UInt64, maxNFTs: UInt64)
    /* Event that returns how many IDs a collection has */ 
    pub event TotalsIDs(ids:[UInt64])


    /* ## ~~This is the contract where we manage the flow of our collections and NFTs~~  ## */

    /* 
    Through the contract you can find variables such as Metadata,
    which are no longer a name to refer to the attributes of our NFTs. 
    which could be the url where our images live
    */

    //In this section you will find our variables and fields for our NFTs and Collections
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver  {
    // The unique ID that each NFT has
        pub let id: UInt64

        pub var metadata : {String: AnyStruct}
        pub let nftType : String
        pub let name: String
        pub let description: String
        pub let thumbnail: String

        init(id : UInt64, name: String, metadata: {String:AnyStruct}, nftType : String, thumbnail: String, description: String) {
            self.id = id
            self.metadata = metadata
            self.nftType = nftType
            self.name = name
            self.thumbnail = thumbnail
            self.description = description
        }

         pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }
        
         pub fun getnftType(): String {
            return self.nftType
        }

        pub fun getMetadata():AnyStruct? {
        return self.metadata
        }

         pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
            }
            return nil
        }
    }

    // We define this interface purely as a way to allow users
    // They would use this to only expose getIDs
    // borrowGMDYNFT
    // and idExists fields in their Collection
    pub resource interface CollectionPublic {

        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun idExists(id: UInt64): Bool
        pub fun getRefNFT(id: UInt64): &NonFungibleToken.NFT?
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowGMDYNFT(id: UInt64): &GMDYNFTContract.NFT? {
            post {
                (result == nil) || (result?.id == id):
                "Cannot borrow NFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    // We define this interface simply as a way to allow users to
    // to create a banner of the collections with their Name and Metadata
    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
        pub var metadata: {String: AnyStruct}?

        pub var name: String?

        init (name: String, metadata: {String: AnyStruct}) {
            self.ownedNFTs <- {}
            self.name = name
            self.metadata = metadata
        }

         /* Function to remove the NFt from the Collection */
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            // If the NFT isn't found, the transaction panics and reverts
            let exist = self.idExists(id: withdrawID)
            if exist == false {
                    panic("id NFT Not exist")
            }
           let token <- self.ownedNFTs.remove(key: withdrawID)!

             /* Emit event when a common user withdraws an NFT*/
            emit Withdraw(id:withdrawID, from: self.owner?.address)

           return <-token
        }

        /*Function to deposit a  NFT in the collection*/
        pub fun deposit(token: @NonFungibleToken.NFT) {

            let token <- token as! @GMDYNFTContract.NFT

            let id: UInt64 = token.id
            
            self.ownedNFTs[token.id] <-! token

            emit Deposit(id: id, to: self.owner?.address )
        }

        //fun get IDs nft
        pub fun getIDs(): [UInt64] {            
            return self.ownedNFTs.keys
        }

        /*Function get Ref NFT*/
        pub fun getRefNFT(id: UInt64): &NonFungibleToken.NFT? {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        /*Function borrow NFT*/
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!  
        }

         /*Function borrow GMDY NFT*/
        pub fun borrowGMDYNFT(id: UInt64): &GMDYNFTContract.NFT? {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &GMDYNFTContract.NFT?
        }

        // fun to check if the NFT exists
        pub fun idExists(id: UInt64): Bool {
            return self.ownedNFTs[id] != nil
        }
        
         pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            let gmdyNFT = nft as! &GMDYNFTContract.NFT
            return gmdyNFT 
        }

        destroy () {
            destroy self.ownedNFTs
        }
    }


    // We define this interface simply as a way to allow users to
    // to add the first NFTs to an empty collection.
    pub resource interface NFTCollectionReceiver {
      pub fun generateNFT(amount: UInt64, collection: Capability<&GMDYNFTContract.Collection{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>)
      pub fun getQuantityAvailablesForCreate(): Int
    }

    pub resource NFTTemplate: NFTCollectionReceiver {

        pub var metadata : {String: AnyStruct}
        pub let nftType : String
        // array NFT
        pub var collectionNFT : [UInt64]
        pub var counteriDs: [UInt64]
        pub let name : String
        pub let thumbnail:  String
        pub let description: String
        pub let maximum : UInt64
 
        init(name: String, nftType: String, metadata: {String: AnyStruct}, thumbnail: String, description: String, amountToCreate: UInt64, maximum: UInt64, collection: Capability<&GMDYNFTContract.Collection{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>) { 
            self.metadata = metadata
            self.name = name
            self.nftType = nftType
            self.maximum = maximum
            self.thumbnail = thumbnail
            self.description = description
            self.collectionNFT = []
            self.counteriDs = []
            self.generateNFT(amount: amountToCreate, collection: collection)
        }
        
        pub fun generateNFT(amount: UInt64, collection: Capability<&GMDYNFTContract.Collection{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>) {
            if Int(amount) < 0 {
                panic("Error amount should be greather than 0")
            }
            if amount > self.maximum {
                panic("Error amount is greater than maximun")
            }
            let newTotal = Int(amount) + self.collectionNFT.length
            if newTotal > Int(self.maximum) {
                panic("The collection is already complete or The amount of nft sent exceeds the maximum amount")
            }
            
            var i = 0  
            let collectionBorrow = collection.borrow() ?? panic("cannot borrow collection")
              emit NewNFTsminted(amount: amount)
            while i < Int(amount) {
             GMDYNFTContract.totalSupply = GMDYNFTContract.totalSupply + 1 
                let newNFT <- create NFT(id: GMDYNFTContract.totalSupply, name: self.name, metadata: self.metadata, nftType: self.nftType, thumbnail: self.thumbnail, description: self.description)
                collectionBorrow.deposit(token: <- newNFT)
                self.collectionNFT.append(GMDYNFTContract.totalSupply)
                self.counteriDs.append(GMDYNFTContract.totalSupply)
                i = i + 1
            }
            emit TotalsIDs(ids: self.counteriDs)
            self.counteriDs = []
        }
    
        pub fun getQuantityAvailablesForCreate(): Int {
            return Int(self.maximum) - self.collectionNFT.length
        }
    }

     pub fun createNFTTemplate( key: AuthAccount, name: String,  nftType: String,
                                metadata: {String: AnyStruct}, thumbnail: String, 
                                description: String, amountToCreate: UInt64, 
                                maximum: UInt64, collection: Capability<&GMDYNFTContract.Collection{NonFungibleToken.Provider, 
                                NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>
                                ): @NFTTemplate {
       if key.address != self.privateKey {
        panic("Address Incorrect")
       }
      emit  CreateNFTCollection(amount: amountToCreate, maxNFTs: maximum)
        return <- create NFTTemplate(
            name: name, 
            nftType: nftType, 
            metadata: metadata, 
            thumbnail: thumbnail,
            description:  description,
            amountToCreate: amountToCreate, 
            maximum: maximum,
            collection: collection,
        )
    }
    
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        var newID = GMDYNFTContract.totalCollection + 1
        GMDYNFTContract.totalCollection = newID
        return <- create Collection(name: "", metadata: {})
    }

    pub fun createEmptyCollectionNFT(name: String, metadata: {String:AnyStruct}): @NonFungibleToken.Collection {
        var newID = GMDYNFTContract.totalCollection + 1
        GMDYNFTContract.totalCollection = newID
        emit NewCollection(collectionName: name, collectionID: GMDYNFTContract.totalCollection)
        return <-  create Collection(name: name, metadata: metadata)
    }

    init() {
       //Initialize the keys Address
        self.privateKey = self.account.address
        // Initialize the total supply
        self.totalSupply = 0
        // Initialize the total collection
        self.totalCollection = 0

        self.CollectionPublicPath = /public/GMDYNFTCollectionPublic
        self.CollectionStoragePath = /storage/GMDYNFTCollection

        emit ContractInitialized()
    }
}