// Description: Smart Contract for BigEast
// SPDX-License-Identifier: UNLICENSED

import NonFungibleToken from "../0x1d7e57aa55817448/NonFungibleToken.cdc"
import MetadataViews from "../0x1d7e57aa55817448/MetadataViews.cdc"

pub contract BigEast: NonFungibleToken {
    pub var totalSupply: UInt64
    pub var name: String
    pub var symbol: String
    
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath   
    
    pub struct Rarity{
        pub let rarity: UFix64?
        pub let rarityName: String
        pub let parts: {String: RarityPart}

        init(rarity: UFix64?, rarityName: String, parts:{String:RarityPart}) {
            self.rarity=rarity
            self.rarityName=rarityName
            self.parts=parts
        }
    }

    pub struct RarityPart{
        pub let rarity: UFix64?
        pub let rarityName: String
        pub let name: String

        init(rarity: UFix64?, rarityName: String, name:String) {
            self.rarity=rarity
            self.rarityName=rarityName
            self.name=name
        }
    }
    
    pub resource interface NFTModifier {

        access(account) fun setURLMetadataHelper(newURL: String, newThumbnail: String)

        access(account) fun setRarityHelper(rarity: UFix64, rarityName: String, rarityValue: String)

        access(account) fun setEditionHelper(editionNumber: UInt64)

        access(account) fun setMetadataHelper(metadata_name: String, metadata_value: String)
    }
    
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver, NFTModifier {
        pub let id: UInt64
        pub var link: String
        pub var batch: UInt32
        pub var sequence: UInt16
        pub var limit: UInt16
        pub var name: String
        pub var description: String
        pub var thumbnail: String
        pub var royalties: [MetadataViews.Royalty]

        pub var rarity: UFix64?
		pub var rarityName: String
        pub var rarityValue: String
		pub var parts: {String: RarityPart}

        pub var editionNumber: UInt64
        
        pub var metadata: {String: String}

        access(account) fun setURLMetadataHelper(newURL: String, newThumbnail: String){
            self.link = newURL
            self.thumbnail = newThumbnail
            log("URL metadata is set to: ")
            log(self.link)
            log(self.thumbnail)
        }

        access(account) fun setRarityHelper(rarity: UFix64, rarityName: String, rarityValue: String)  {
            self.rarity = rarity
            self.rarityName = rarityName
            self.rarityValue = rarityValue
            
            self.parts = {rarityName:RarityPart(rarity: rarity, rarityName: rarityName, name:rarityValue)}
            
            log("Rarity metadata is updated")
        }

        access(account) fun setEditionHelper(editionNumber: UInt64)  {
            self.editionNumber = editionNumber
            
            log("Edition metadata is updated")
        }

        access(account) fun setMetadataHelper(metadata_name: String, metadata_value: String)  {
            self.metadata.insert(key: metadata_name, metadata_value)
            log("Custom Metadata store is updated")
        }
        
        init(
            initID: UInt64, 
            initlink: String, 
            initbatch: UInt32, 
            initsequence: UInt16, 
            initlimit: UInt16, 
            name: String, 
            description: String, 
            thumbnail: String,
            royalties: [MetadataViews.Royalty],
            editionNumber: UInt64, 
            metadata: {String:String}, 
        ) {
            self.id = initID
            self.link = initlink
            self.batch = initbatch
            self.sequence=initsequence
            self.limit=initlimit

            self.name = name 
            self.description = description
            self.thumbnail = thumbnail
            self.royalties = royalties
            
            self.rarity = nil
            self.rarityName = "null"
            self.rarityValue= "null"
            self.parts = {self.rarityName: RarityPart(rarity: self.rarity, rarityName: self.rarityName, name: self.rarityValue)}
            self.editionNumber = editionNumber
        
            self.metadata = metadata
        }

        pub fun getViews(): [Type] {
            return [
                Type<Rarity>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<Rarity>():
                    return Rarity(
                        rarity : self.rarity,
                        rarityName: self.rarityName,
                        parts : self.parts
                    )
                
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name : self.name,
                        description: self.description,
                        thumbnail : MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                
                case Type<MetadataViews.Editions>():
                    let editionList: [MetadataViews.Edition] = []
                    return MetadataViews.Editions(editionList)
                
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(self.royalties)

                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(url: self.link)
                    
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: BigEast.CollectionStoragePath,
                        publicPath: BigEast.CollectionPublicPath,
                        providerPath: /private/BigEastCollection,
                        publicCollection: Type<&BigEast.Collection{BigEast.BigEastCollectionPublic}>(),
                        publicLinkedType: Type<&BigEast.Collection{BigEast.BigEastCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&BigEast.Collection{BigEast.BigEastCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-BigEast.createEmptyCollection()
                        })
                    )
                
                case Type<MetadataViews.NFTCollectionDisplay>():
                    var squareImageFile: String? = ""
                    var squareImageType: String? = ""

                    let squareImage: MetadataViews.Media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile (url: squareImageFile!),
                        mediaType: squareImageType!
                    )

                    var bannerImageFile: String? = ""
                    var bannerImageType: String? = ""

                    let bannerImage: MetadataViews.Media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile (url: bannerImageFile!),
                        mediaType: bannerImageType!
                    )

                    return MetadataViews.NFTCollectionDisplay(
                        name: "Big East",
                        description: "Big East",
                        externalURL: MetadataViews.ExternalURL(
                            url: self.link
                        ),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: {}
                    )
                
                case Type<MetadataViews.Traits>():
                    var traits: [MetadataViews.Trait] = []

                    let includedNames: [String] = []

                    for name in includedNames {
                        if var _: String? = self.metadata[name] as String?? {
                            traits = traits.concat([
                                MetadataViews.Trait(
                                    name: name,
                                    value: self.metadata[name],
                                    displayType: nil,
                                    rarity: nil
                                )
                            ])
                        }
                    }

                    return MetadataViews.Traits(traits)

                case Type<MetadataViews.Medias>():
                    var mediaItems: [MetadataViews.Media] = []

                    let optionalItems: [[String]] = []

                    for optionalItem in optionalItems {
                        if var _: String? = self.metadata[optionalItem[1]] as String?? {
                            switch optionalItem[1] {
                                case "ThumbnailType":
                                    mediaItems = mediaItems.concat([
                                        MetadataViews.Media(
                                            file: MetadataViews.HTTPFile(
                                                url: self.thumbnail
                                            ),
                                            mediaType: self.metadata[optionalItem[1]]!
                                        )
                                    ])
                                default:
                                    mediaItems = mediaItems.concat([
                                        MetadataViews.Media(
                                            file: MetadataViews.HTTPFile(
                                                url: self.metadata[optionalItem[0]]!
                                            ),
                                            mediaType: self.metadata[optionalItem[1]]!
                                        )
                                    ])
                            }
                        }
                    }

                    return MetadataViews.Medias(
                        items: mediaItems
                    )
                }
            return nil
        }
    }

    pub resource interface BigEastCollectionPublic {

        pub fun deposit(token: @NonFungibleToken.NFT)

        pub fun getIDs(): [UInt64]

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT

        pub fun borrowBigEast(id: UInt64): &BigEast.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow BigEast reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: BigEastCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID)!
            
            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @BigEast.NFT    
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        destroy() {
            destroy self.ownedNFTs
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let exampleNFT = nft as! &BigEast.NFT
            return exampleNFT as &AnyResource{MetadataViews.Resolver}
        }

        pub fun borrowBigEast(id: UInt64): &BigEast.NFT? {
            if self.ownedNFTs[id] == nil {
                return nil
            }
            else {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &BigEast.NFT
            }
        }

    }

    pub fun createEmptyCollection(): @BigEast.Collection {
        return <- create Collection()
    }

    pub resource NFTMinter {
        pub var minterID: UInt64
        
        init() {
            self.minterID = 0    
        }

        pub fun mintNFT(
            glink: String,
            gbatch: UInt32,
            glimit: UInt16,
            gsequence: UInt16,
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty],
            editionNumber: UInt64,
            metadata: {String: String}
        ): @NFT {
            let tokenID = (UInt64(gbatch) << 32) | (UInt64(glimit) << 16) | UInt64(gsequence)
            
            var newNFT <- create NFT(
                initID: tokenID,
                initlink: glink,
                initbatch: gbatch,
                initsequence: gsequence,
                initlimit: glimit,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: royalties,
                editionNumber: editionNumber,
                metadata: metadata
            )

            self.minterID = tokenID
            BigEast.totalSupply = BigEast.totalSupply + 1

            return <-newNFT
        }
    }

    pub resource Modifier {

        pub var ModifierID: UInt64
        
        pub fun setURLMetadata(currentNFT: &BigEast.NFT?, newURL: String, newThumbnail: String) : String {
            let ref2 =  currentNFT!
            ref2.setURLMetadataHelper(newURL: newURL, newThumbnail: newThumbnail)
            log("URL metadata is set to: ")
            log(newURL)
            return newURL
        }
        
        pub fun setRarity(currentNFT: &BigEast.NFT?, rarity:UFix64, rarityName:String, rarityValue:String)  {
            let ref2 =  currentNFT!
            ref2.setRarityHelper(rarity: rarity, rarityName: rarityName, rarityValue: rarityValue)
            log("Rarity metadata is updated")
        }
        
        pub fun setEdition(currentNFT: &BigEast.NFT?, editionNumber:UInt64)  {
            let ref2 =  currentNFT!
            ref2.setEditionHelper(editionNumber: editionNumber)
            log("Edition metadata is updated")
        }
        
        pub fun setMetadata(currentNFT: &BigEast.NFT?, metadata_name: String, metadata_value: String)  {
            let ref2 =  currentNFT!
            ref2.setMetadataHelper(metadata_name: metadata_name, metadata_value: metadata_value)
            log("Custom Metadata store is updated")
        }

        init() {
            self.ModifierID = 0    
        }
    }

	init() {
        self.CollectionStoragePath = /storage/BigEastCollection
        self.CollectionPublicPath = /public/BigEastCollection
        self.MinterStoragePath = /storage/BigEastMinter

        self.totalSupply = 0
        self.name = "Big East"
        self.symbol = "BIGEAST"

		self.account.save(<-self.createEmptyCollection(), to: self.CollectionStoragePath)
        self.account.link<&{BigEast.BigEastCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath, 
            target: self.CollectionStoragePath
        )
        self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)
        self.account.save(<-create Modifier(), to: /storage/BigEastModifier)
        emit ContractInitialized()
	}
}
 