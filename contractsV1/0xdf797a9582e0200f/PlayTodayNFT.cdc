/*
This tool adds a new entitlemtent called TMP_ENTITLEMENT_OWNER to some functions that it cannot be sure if it is safe to make access(all)
those functions you should check and update their entitlemtents ( or change to all access )

Please see: 
https://cadence-lang.org/docs/cadence-migration-guide/nft-guide#update-all-pub-access-modfiers

IMPORTANT SECURITY NOTICE
Please familiarize yourself with the new entitlements feature because it is extremely important for you to understand in order to build safe smart contracts.
If you change pub to access(all) without paying attention to potential downcasting from public interfaces, you might expose private functions like withdraw 
that will cause security problems for your contract.

*/

	import NonFungibleToken from "./../../standardsV1/NonFungibleToken.cdc"

import ViewResolver from "../../standardsV1/ViewResolver.cdc"

import MetadataViews from "./../../standardsV1/MetadataViews.cdc"

access(all)
contract PlayTodayNFT: NonFungibleToken{ 
	// Events
	//
	access(all)
	event ContractInitialized()
	
	access(all)
	event Withdraw(id: UInt64, from: Address?)
	
	access(all)
	event Deposit(id: UInt64, to: Address?)
	
	access(all)
	event Minted(id: UInt64, creator: Address, rarity: UInt8, uri: String, name: String, description: String)
	
	access(all)
	event Destroy(id: UInt64)
	
	// Named Paths
	//
	access(all)
	let CollectionStoragePath: StoragePath
	
	access(all)
	let CollectionPublicPath: PublicPath
	
	access(all)
	let MinterStoragePath: StoragePath
	
	// totalSupply
	// The total number of PlayTodayNFT that have been minted
	//
	access(all)
	var totalSupply: UInt64
	
	access(all)
	enum Rarity: UInt8{ 
		access(all)
		case collector
		
		access(all)
		case platinum
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun rarityToString(_ rarity: Rarity): String{ 
		switch rarity{ 
			case Rarity.collector:
				return "Collector"
			case Rarity.platinum:
				return "Platinum"
		}
		return ""
	}
	
	// A Play Today NFT as an NFT
	//  
	access(all)
	resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver{ 
		access(all)
		let id: UInt64
		
		// The token rarity (e.g. Normal or Platinum)
		access(all)
		let creator: Address
		
		access(all)
		let rarity: Rarity
		
		access(all)
		let uri: String
		
		access(all)
		let name: String
		
		access(all)
		let description: String
		
		access(self)
		let royalties: [MetadataViews.Royalty]
		
		access(self)
		let metadata:{ String: AnyStruct}
		
		init(id: UInt64, creator: Address, rarity: Rarity, uri: String, name: String, description: String, royalties: [MetadataViews.Royalty], metadata:{ String: AnyStruct}){ 
			self.id = id
			self.creator = creator
			self.rarity = rarity
			self.uri = uri
			self.name = name
			self.description = description
			self.royalties = royalties
			self.metadata = metadata
		}
		
		access(all)
		view fun getViews(): [Type]{ 
			return [Type<MetadataViews.Display>(), Type<MetadataViews.Royalties>(), Type<MetadataViews.ExternalURL>(), Type<MetadataViews.NFTCollectionData>(), Type<MetadataViews.NFTCollectionDisplay>(), Type<MetadataViews.Serial>(), Type<MetadataViews.Traits>()]
		}
		
		access(all)
		fun resolveView(_ view: Type): AnyStruct?{ 
			switch view{ 
				case Type<MetadataViews.Royalties>():
					return MetadataViews.Royalties(self.royalties)
				case Type<MetadataViews.Display>():
					return MetadataViews.Display(name: self.name, description: self.description, thumbnail: MetadataViews.HTTPFile(url: "https://ipfs.filebase.io/ipfs/".concat(self.uri)))
				case Type<MetadataViews.Serial>():
					return MetadataViews.Serial(self.id)
				case Type<MetadataViews.ExternalURL>():
					return MetadataViews.ExternalURL("https://playtodaynft.com/nft/".concat(self.id.toString()))
				case Type<MetadataViews.NFTCollectionData>():
					return MetadataViews.NFTCollectionData(storagePath: PlayTodayNFT.CollectionStoragePath, publicPath: PlayTodayNFT.CollectionPublicPath, publicCollection: Type<&PlayTodayNFT.Collection>(), publicLinkedType: Type<&PlayTodayNFT.Collection>(), createEmptyCollectionFunction: fun (): @{NonFungibleToken.Collection}{ 
							return <-PlayTodayNFT.createEmptyCollection(nftType: Type<@PlayTodayNFT.Collection>())
						})
				case Type<MetadataViews.NFTCollectionDisplay>():
					let media = MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://s3.ap-southeast-2.amazonaws.com/files.playtoday.cc/PT_NFT_B.jpg"), mediaType: "image/svg+xml")
					let squareMedia = MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://s3.ap-southeast-2.amazonaws.com/files.playtoday.cc/PT_NFT_B.jpg"), mediaType: "image/svg+xml")
					return MetadataViews.NFTCollectionDisplay(name: "Play Today Collection", description: "PlayToday.NFT is the world's first Web3 golf project developed with Players for the Players.", externalURL: MetadataViews.ExternalURL("https://playtodaynft.com"), squareImage: media, bannerImage: media, socials:{ "twitter": MetadataViews.ExternalURL("https://twitter.com/PlayTodayNFT"), "instagram": MetadataViews.ExternalURL("https://www.instagram.com/playtoday.nft/"), "discord": MetadataViews.ExternalURL("https://discord.gg/6H3J85UU"), "facebook": MetadataViews.ExternalURL("https://www.facebook.com/playtodaynft"), "linkedin": MetadataViews.ExternalURL("https://www.linkedin.com/company/playtodaygolf")})
				case Type<MetadataViews.Traits>():
					// exclude mintedTime and foo to show other uses of Traits
					let excludedTraits = ["mintedTime"]
					let traitsView = MetadataViews.dictToTraits(dict: self.metadata, excludedNames: excludedTraits)
					// mintedTime is a unix timestamp, we should mark it with a displayType so platforms know how to show it.
					let mintedTimeTrait = MetadataViews.Trait(name: "mintedTime", value: self.metadata["mintedTime"]!, displayType: "Date", rarity: nil)
					traitsView.addTrait(mintedTimeTrait)
					return traitsView
			}
			return nil
		}
		
		access(all)
		fun createEmptyCollection(): @{NonFungibleToken.Collection}{ 
			return <-create Collection()
		}
	}
	
	// This is the interface that users can cast their PlayTodayNFT Collection as
	// to allow others to deposit PlayTodayNFT into their Collection. It also allows for reading
	// the details of PlayTodayNFT in the Collection.
	access(all)
	resource interface PlayTodayNFTCollectionPublic{ 
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void
		
		access(all)
		view fun getIDs(): [UInt64]
		
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowPlayTodayNFT(id: UInt64): &PlayTodayNFT.NFT?{ 
			// If the result isn't nil, the id of the returned reference
			// should be the same as the argument to the function
			post{ 
				result == nil || result?.id == id:
					"Cannot borrow PlayTodayNFT reference: The ID of the returned reference is incorrect"
			}
		}
	}
	
	// Collection
	// A collection of PlayTodayNFT NFTs owned by an account
	//
	access(all)
	resource Collection: PlayTodayNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.Collection, NonFungibleToken.CollectionPublic, ViewResolver.ResolverCollection{ 
		// dictionary of NFT conforming tokens
		// NFT is a resource type with an `UInt64` ID field
		//
		access(all)
		var ownedNFTs: @{UInt64:{ NonFungibleToken.NFT}}
		
		// withdraw
		// Removes an NFT from the collection and moves it to the caller
		//
		access(NonFungibleToken.Withdraw)
		fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT}{ 
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
			emit Withdraw(id: token.id, from: self.owner?.address)
			return <-token
		}
		
		// deposit
		// Takes a NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		//
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void{ 
			let token <- token as! @PlayTodayNFT.NFT
			let id: UInt64 = token.id
			// add the new token to the dictionary which removes the old one
			let oldToken <- self.ownedNFTs[id] <- token
			emit Deposit(id: id, to: self.owner?.address)
			destroy oldToken
		}
		
		// getIDs
		// Returns an array of the IDs that are in the collection
		//
		access(all)
		view fun getIDs(): [UInt64]{ 
			return self.ownedNFTs.keys
		}
		
		// borrowNFT
		// Gets a reference to an NFT in the collection
		// so that the caller can read its metadata and call its methods
		//
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?{ 
			return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
		}
		
		// borrowPlayTodayNFT
		// Gets a reference to an NFT in the collection as a PlayTodayNFT,
		// exposing all of its fields (including the typeID & rarityID).
		// This is safe as there are no functions that can be called on the PlayTodayNFT.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowPlayTodayNFT(id: UInt64): &PlayTodayNFT.NFT?{ 
			if self.ownedNFTs[id] != nil{ 
				let ref = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
				return ref as! &PlayTodayNFT.NFT
			} else{ 
				return nil
			}
		}
		
		access(all)
		view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}?{ 
			let nft = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
			let playTodayNFT = nft as! &PlayTodayNFT.NFT
			return playTodayNFT as &{ViewResolver.Resolver}
		}
		
		access(all)
		view fun getSupportedNFTTypes():{ Type: Bool}{ 
			panic("implement me")
		}
		
		access(all)
		view fun isSupportedNFTType(type: Type): Bool{ 
			panic("implement me")
		}
		
		access(all)
		fun createEmptyCollection(): @{NonFungibleToken.Collection}{ 
			return <-create Collection()
		}
		
		// destructor
		// initializer
		//
		init(){ 
			self.ownedNFTs <-{} 
		}
	}
	
	// createEmptyCollection
	// public function that anyone can call to create a new empty collection
	//
	access(all)
	fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection}{ 
		return <-create Collection()
	}
	
	// NFTMinter
	// Resource that an admin or something similar would own to be
	// able to mint new NFTs
	//
	access(all)
	resource NFTMinter{ 
		// mintNFT
		// Mints a new NFT with a new ID
		// and deposit it in the recipients collection using their collection reference
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, creator: Address, rarity: Rarity, uri: String, name: String, description: String, royalties: [MetadataViews.Royalty]){ 
			let metadata:{ String: AnyStruct} ={} 
			let currentBlock = getCurrentBlock()
			metadata["mintedBlock"] = currentBlock.height
			metadata["mintedTime"] = currentBlock.timestamp
			metadata["minter"] = (recipient.owner!).address
			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create PlayTodayNFT.NFT(id: PlayTodayNFT.totalSupply, creator: creator, rarity: rarity, uri: uri, name: name, description: description, royalties: royalties, metadata: metadata))
			emit Minted(id: PlayTodayNFT.totalSupply, creator: creator, rarity: rarity.rawValue, uri: uri, name: name, description: description)
			PlayTodayNFT.totalSupply = PlayTodayNFT.totalSupply + 1 as UInt64
		}
	}
	
	// fetch
	// Get a reference to a PlayTodayNFT from an account's Collection, if available.
	// If an account does not have a PlayTodayNFT.Collection, panic.
	// If it has a collection but does not contain the itemID, return nil.
	// If it has a collection and that collection contains the itemID, return a reference to that.
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun fetch(_ from: Address, itemID: UInt64): &PlayTodayNFT.NFT?{ 
		let collection = (getAccount(from).capabilities.get<&PlayTodayNFT.Collection>(PlayTodayNFT.CollectionPublicPath)!).borrow() ?? panic("Couldn't get collection")
		// We trust PlayTodayNFT.Collection.borowPlayTodayNFT to get the correct itemID
		// (it checks it before returning it).
		return collection.borrowPlayTodayNFT(id: itemID)
	}
	
	// initializer
	//
	init(){ 
		// Set our named paths
		self.CollectionStoragePath = /storage/playTodayNFTCollection
		self.CollectionPublicPath = /public/playTodayNFTCollection
		self.MinterStoragePath = /storage/playTodayNFTMinter
		// Initialize the total supply
		self.totalSupply = 0
		// Create a Collection resource and save it to storage
		let collection <- create Collection()
		self.account.storage.save(<-collection, to: self.CollectionStoragePath)
		// Create a Minter resource and save it to storage
		let minter <- create NFTMinter()
		self.account.storage.save(<-minter, to: self.MinterStoragePath)
		// self.account.link<&NFTMinter>(self.MinterPublicPath, target: self.MinterStoragePath)
		// create a public capability for the collection
		var capability_1 = self.account.capabilities.storage.issue<&PlayTodayNFT.Collection>(self.CollectionStoragePath)
		self.account.capabilities.publish(capability_1, at: self.CollectionPublicPath)
		var capability_2 = self.account.capabilities.storage.issue<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver}>(self.CollectionStoragePath)
		self.account.capabilities.publish(capability_2, at: self.CollectionPublicPath)
		emit ContractInitialized()
	}
}
