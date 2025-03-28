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
contract PlayTodayItems: NonFungibleToken{ 
	// Events
	//
	access(all)
	event ContractInitialized()
	
	access(all)
	event Withdraw(id: UInt64, from: Address?)
	
	access(all)
	event Deposit(id: UInt64, to: Address?)
	
	access(all)
	event Minted(id: UInt64, kind: UInt8, rarity: UInt8)
	
	access(all)
	event ImagesAddedForNewKind(kind: UInt8)
	
	// Named Paths
	//
	access(all)
	let CollectionStoragePath: StoragePath
	
	access(all)
	let CollectionPublicPath: PublicPath
	
	access(all)
	let MinterStoragePath: StoragePath
	
	// totalSupply
	// The total number of items that have been minted
	//
	access(all)
	var totalSupply: UInt64
	
	access(all)
	enum Rarity: UInt8{ 
		access(all)
		case normal
		
		access(all)
		case platinum
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun rarityToString(_ rarity: Rarity): String{ 
		switch rarity{ 
			case Rarity.normal:
				return "Normal"
			case Rarity.platinum:
				return "Platinum"
		}
		return ""
	}
	
	access(all)
	enum Kind: UInt8{ 
		access(all)
		case g1
		
		access(all)
		case g2
		
		access(all)
		case g3
		
		access(all)
		case g4
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun kindToString(_ kind: Kind): String{ 
		switch kind{ 
			case Kind.g1:
				return "Fishbowl"
			case Kind.g2:
				return "Fish Hat"
			case Kind.g3:
				return "Milkshake"
			case Kind.g4:
				return "Tuk-Tuk"
		}
		return ""
	}
	
	access(self)
	var images:{ Kind:{ Rarity: String}}
	
	// Mapping from rarity -> price
	//
	access(self)
	var itemRarityPriceMap:{ Rarity: UFix64}
	
	// Return the initial sale price for an item of this rarity.
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun getItemPrice(rarity: Rarity): UFix64{ 
		return self.itemRarityPriceMap[rarity]!
	}
	
	// createEmptyCollection
	// public function that anyone can call to create a new empty collection
	//
	access(all)
	resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver{ 
		access(all)
		let id: UInt64
		
		access(all)
		let kind: Kind
		
		// The token rarity (e.g. Gold)
		access(all)
		let rarity: Rarity
		
		init(id: UInt64, kind: Kind, rarity: Rarity){ 
			self.id = id
			self.kind = kind
			self.rarity = rarity
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun name(): String{ 
			return PlayTodayItems.rarityToString(self.rarity).concat(" ").concat(PlayTodayItems.kindToString(self.kind))
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun description(): String{ 
			return "A ".concat(PlayTodayItems.rarityToString(self.rarity).toLower()).concat(" ").concat(PlayTodayItems.kindToString(self.kind).toLower()).concat(" with serial number ").concat(self.id.toString())
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun imageCID(): String{ 
			return (PlayTodayItems.images[self.kind]!)[self.rarity]!
		}
		
		access(all)
		view fun getViews(): [Type]{ 
			return [Type<MetadataViews.Display>()]
		}
		
		access(all)
		fun resolveView(_ view: Type): AnyStruct?{ 
			switch view{ 
				case Type<MetadataViews.Display>():
					return MetadataViews.Display(name: self.name(), description: self.description(), thumbnail: MetadataViews.IPFSFile(cid: self.imageCID(), path: "sm.png"))
			}
			return nil
		}
		
		access(all)
		fun createEmptyCollection(): @{NonFungibleToken.Collection}{ 
			return <-create Collection()
		}
	}
	
	// This is the interface that users can cast their PlayTodayItems Collection as
	// to allow others to deposit PlayTodayItems into their Collection. It also allows for reading
	// the details of PlayTodayItems in the Collection.
	access(all)
	resource interface PlayTodayItemsCollectionPublic{ 
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void
		
		access(all)
		view fun getIDs(): [UInt64]
		
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowPlayTodayItem(id: UInt64): &PlayTodayItems.NFT?{ 
			// If the result isn't nil, the id of the returned reference
			// should be the same as the argument to the function
			post{ 
				result == nil || result?.id == id:
					"Cannot borrow PlayTodayItem reference: The ID of the returned reference is incorrect"
			}
		}
	}
	
	// Collection
	// A collection of PlayTodayItem NFTs owned by an account
	//
	access(all)
	resource Collection: PlayTodayItemsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.Collection, NonFungibleToken.CollectionPublic, ViewResolver.ResolverCollection{ 
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
			let token <- token as! @PlayTodayItems.NFT
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
		
		// borrowPlayTodayItem
		// Gets a reference to an NFT in the collection as a PlayTodayItem,
		// exposing all of its fields (including the typeID & rarityID).
		// This is safe as there are no functions that can be called on the PlayTodayItem.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowPlayTodayItem(id: UInt64): &PlayTodayItems.NFT?{ 
			if self.ownedNFTs[id] != nil{ 
				let ref = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
				return ref as! &PlayTodayItems.NFT
			} else{ 
				return nil
			}
		}
		
		access(all)
		view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}?{ 
			let nft = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
			let PlayTodayItem = nft as! &PlayTodayItems.NFT
			return PlayTodayItem as &{ViewResolver.Resolver}
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
	
	access(all)
	fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection}{ 
		return <-create Collection()
	}
	
	access(all)
	resource NFTMinter{ 
		// mintNFT
		// Mints a new NFT with a new ID
		// and deposit it in the recipients collection using their collection reference
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, kind: Kind, rarity: Rarity){ 
			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create PlayTodayItems.NFT(id: PlayTodayItems.totalSupply, kind: kind, rarity: rarity))
			emit Minted(id: PlayTodayItems.totalSupply, kind: kind.rawValue, rarity: rarity.rawValue)
			PlayTodayItems.totalSupply = PlayTodayItems.totalSupply + 1 as UInt64
		}
		
		// Update NFT images for new type
		access(TMP_ENTITLEMENT_OWNER)
		fun addNewImagesForKind(from: AuthAccount, newImages:{ Kind:{ Rarity: String}}){ 
			let kindValue = PlayTodayItems.images.containsKey(newImages.keys[0])
			if !kindValue{ 
				PlayTodayItems.images.insert(key: newImages.keys[0], newImages.values[0])
				emit ImagesAddedForNewKind(kind: newImages.keys[0].rawValue)
			} else{ 
				panic("No Rugs... Can't update existing NFT images.")
			}
		}
	}
	
	// fetch
	// Get a reference to a PlayTodayItem from an account's Collection, if available.
	// If an account does not have a PlayTodayItems.Collection, panic.
	// If it has a collection but does not contain the itemID, return nil.
	// If it has a collection and that collection contains the itemID, return a reference to that.
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun fetch(_ from: Address, itemID: UInt64): &PlayTodayItems.NFT?{ 
		let collection = (getAccount(from).capabilities.get<&PlayTodayItems.Collection>(PlayTodayItems.CollectionPublicPath)!).borrow() ?? panic("Couldn't get collection")
		// We trust PlayTodayItems.Collection.borowPlayTodayItem to get the correct itemID
		// (it checks it before returning it).
		return collection.borrowPlayTodayItem(id: itemID)
	}
	
	init(){ 
		self.itemRarityPriceMap ={ Rarity.normal: 50.0, Rarity.platinum: 100.0}
		self.images ={ Kind.g1:{ Rarity.normal: "QmNv9AYcP3q1mk3W9Qdj5o3VX3Z7MYEmifF1gc64UspzXi", Rarity.platinum: "QmNv9AYcP3q1mk3W9Qdj5o3VX3Z7MYEmifF1gc64UspzXi"}, Kind.g2:{ Rarity.normal: "QmNv9AYcP3q1mk3W9Qdj5o3VX3Z7MYEmifF1gc64UspzXi", Rarity.platinum: "QmNv9AYcP3q1mk3W9Qdj5o3VX3Z7MYEmifF1gc64UspzXi"}, Kind.g3:{ Rarity.normal: "QmNv9AYcP3q1mk3W9Qdj5o3VX3Z7MYEmifF1gc64UspzXi", Rarity.platinum: "QmNv9AYcP3q1mk3W9Qdj5o3VX3Z7MYEmifF1gc64UspzXi"}, Kind.g4:{ Rarity.normal: "QmNv9AYcP3q1mk3W9Qdj5o3VX3Z7MYEmifF1gc64UspzXi", Rarity.platinum: "QmNv9AYcP3q1mk3W9Qdj5o3VX3Z7MYEmifF1gc64UspzXi"}}
		self.CollectionStoragePath = /storage/playTodayItemsCollectionV10
		self.CollectionPublicPath = /public/playTodayItemsCollectionV10
		self.MinterStoragePath = /storage/playTodayItemsMinterV10
		// Initialize the total supply
		self.totalSupply = 0
		// Create a Minter resource and save it to storage
		let minter <- create NFTMinter()
		self.account.storage.save(<-minter, to: self.MinterStoragePath)
		emit ContractInitialized()
	}
}
