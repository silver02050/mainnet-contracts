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

	// SPDX-License-Identifier: Unlicense
import NonFungibleToken from "./../../standardsV1/NonFungibleToken.cdc"

import ViewResolver from "../../standardsV1/ViewResolver.cdc"

import ARTIFACT, ARTIFACTViews, Interfaces from 0x24de869c5e40b2eb

access(all)
contract ARTIFACTPack: NonFungibleToken{ 
	// -----------------------------------------------------------------------
	// ARTIFACTPack contract-level fields.
	// These contain actual values that are stored in the smart contract.
	// -----------------------------------------------------------------------
	// The total supply that is used to create NFT. 
	// Every time a NFT is created,  
	// totalSupply is incremented by 1 and then is assigned to NFT's ID.
	access(all)
	var totalSupply: UInt64
	
	// The next pack template ID that is used to create PackTemplate. 
	// Every time a PackTemplate is created, nextTemplateId is assigned 
	// to the new PackTemplate's ID and then is incremented by 1.
	access(all)
	var nextTemplateId: UInt64
	
	// The next PACK ID that is used to create pack. 
	// Every time a Pack is created, nextPackId is assigned 
	// to the new Pack's ID and then is incremented by 1.
	access(all)
	var nextPackId: UInt64
	
	// Variable size dictionary of PackTemplate structs
	access(account)
	var templateDatas:{ UInt64: PackTemplate}
	
	// Variable size dictionary of minted packs
	access(account)
	var numberMintedByPack:{ UInt64: UInt64}
	
	/// Path where the public capability for the `Collection` is available
	access(all)
	let collectionPublicPath: PublicPath
	
	/// Path where the `Collection` is stored
	access(all)
	let collectionStoragePath: StoragePath
	
	/// Event used on destroy Pack NFT from collection
	access(all)
	event NFTDestroyed(nftId: UInt64)
	
	/// Event used on withdraw Pack NFT from collection
	access(all)
	event Withdraw(id: UInt64, from: Address?)
	
	/// Event used on deposit Pack NFT to collection
	access(all)
	event Deposit(id: UInt64, to: Address?)
	
	/// Event used on contract initiation
	access(all)
	event ContractInitialized()
	
	/// Event used on mint Pack
	access(all)
	event PackMinted(packId: UInt64, owner: Address, listingID: UInt64, edition: UInt64)
	
	/// Event used on create template
	access(all)
	event PackTemplateCreated(templateId: UInt64, totalSupply: UInt64)
	
	/// Event used on open Pack
	access(all)
	event OpenPack(packId: UInt64)
	
	// -----------------------------------------------------------------------
	// ARTIFACTPack contract-level Composite Type definitions
	// -----------------------------------------------------------------------
	// These are just *definitions* for Types that this contract
	// and other accounts can use. These definitions do not contain
	// actual stored values, but an instance (or object) of one of these Types
	// can be created by this contract that contains stored values.
	// ----------------------------------------------------------------------- 
	/// Tarnishment used on Pack
	access(all)
	enum Tarnishment: UInt8{ 
		access(all)
		case good
		
		access(all)
		case great
		
		access(all)
		case bad
	}
	
	// PackTemplate is a Struct that holds metadata associated with a specific 
	// pack nft
	//
	// Pack NFT resource will all reference a single template as the owner of
	// its metadata. The templates are publicly accessible, so anyone can
	// read the metadata associated with a specific Pack NFT ID
	//
	access(all)
	struct PackTemplate: Interfaces.IPackTemplate{ 
		access(all)
		let templateId: UInt64
		
		access(all)
		let metadata:{ String: String}
		
		access(all)
		let totalSupply: UInt64
		
		access(all)
		let maxQuantityPerTransaction: UInt64
		
		access(all)
		var lockStatus: Bool
		
		access(all)
		var packsAvailable: [[UInt64]]
		
		init(metadata:{ String: String}, totalSupply: UInt64, maxQuantityPerTransaction: UInt64, packsAvailable: [[UInt64]]){ 
			self.templateId = ARTIFACTPack.nextTemplateId
			self.metadata = metadata
			self.totalSupply = totalSupply
			self.maxQuantityPerTransaction = maxQuantityPerTransaction
			self.lockStatus = true
			self.packsAvailable = packsAvailable
			emit PackTemplateCreated(templateId: self.templateId, totalSupply: self.totalSupply)
			ARTIFACTPack.nextTemplateId = ARTIFACTPack.nextTemplateId + UInt64(1)
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun updateLockStatus(lockStatus: Bool){ 
			self.lockStatus = lockStatus
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun removeIndex(indexPackAvailable: UInt64){ 
			self.packsAvailable.remove(at: indexPackAvailable)
		}
	}
	
	// The resource that represents the Pack
	//
	access(all)
	resource NFT: Interfaces.IPack, NonFungibleToken.NFT, ViewResolver.Resolver{ 
		access(all)
		let id: UInt64
		
		access(all)
		let edition: UInt64
		
		access(all)
		var isOpen: Bool
		
		access(all)
		let templateId: UInt64
		
		access(all)
		var tarnishment: Tarnishment?
		
		access(all)
		let adminRef: Capability<&{Interfaces.ARTIFACTAdminOpener}>
		
		access(all)
		let metadata:{ String: String}
		
		init(packTemplate:{ Interfaces.IPackTemplate}, adminRef: Capability<&{Interfaces.ARTIFACTAdminOpener}>, owner: Address, listingID: UInt64, edition: UInt64){ 
			self.id = ARTIFACTPack.nextPackId
			self.edition = edition
			self.adminRef = adminRef
			self.tarnishment = nil
			self.isOpen = false
			self.metadata = packTemplate.metadata
			self.templateId = packTemplate.templateId
			emit PackMinted(packId: self.id, owner: owner, listingID: listingID, edition: edition)
			ARTIFACTPack.nextPackId = ARTIFACTPack.nextPackId + UInt64(1)
			ARTIFACTPack.totalSupply = ARTIFACTPack.totalSupply + 1
		}
		
		access(all)
		view fun getViews(): [Type]{ 
			return [Type<MetadataViews.Display>(), Type<ARTIFACTViews.ArtifactsDisplay>()]
		}
		
		access(all)
		fun resolveView(_ view: Type): AnyStruct?{ 
			var mediaUri = ""
			var description = ""
			if self.isOpen{ 
				description = self.metadata["descriptionOpened"]!
				mediaUri = self.metadata["fileUriOpened"]!
			} else{ 
				description = self.metadata["descriptionUnopened"]!
				mediaUri = self.metadata["fileUriUnopened"]!
			}
			let fileUri = mediaUri.slice(from: 7, upTo: mediaUri.length - 1)
			var title = self.metadata["name"]!
			switch view{ 
				case Type<MetadataViews.Display>():
					return MetadataViews.Display(name: self.metadata["name"]!, description: description, thumbnail: MetadataViews.IPFSFile(cid: fileUri, path: nil))
				case Type<ARTIFACTViews.ArtifactsDisplay>():
					return ARTIFACTViews.ArtifactsDisplay(name: self.metadata["name"]!, description: description, thumbnail: MetadataViews.IPFSFile(cid: fileUri, path: nil), metadata: self.metadata)
			}
			return nil
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun open(owner: Address): @[{NonFungibleToken.NFT}]{ 
			pre{ 
				!self.isOpen:
					"User Pack must be closed"
			}
			let userPackRef: &{Interfaces.IPack} = &self as &{Interfaces.IPack}
			var nfts: @[{NonFungibleToken.NFT}] <- (self.adminRef.borrow()!).openPack(userPack: userPackRef, packID: self.id, owner: owner, royalties: [], packOption: nil)
			self.isOpen = true
			self.tarnishment = Tarnishment.good
			emit OpenPack(packId: self.id)
			return <-nfts
		}
		
		access(all)
		fun createEmptyCollection(): @{NonFungibleToken.Collection}{ 
			return <-create Collection()
		}
	}
	
	access(all)
	resource interface CollectionPublic{ 
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void
		
		access(all)
		view fun getIDs(): [UInt64]
		
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrow(id: UInt64): &ARTIFACTPack.NFT?
	}
	
	// Collection is a resource that every user who owns Pack NFTs 
	// will store in their account to manage their Pack NFTS
	//
	access(all)
	resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.Collection, NonFungibleToken.CollectionPublic, CollectionPublic, ViewResolver.ResolverCollection{ 
		// Dictionary of Pack NFT conforming tokens
		// Pack NFT is a resource type with a UInt64 ID field
		access(all)
		var ownedNFTs: @{UInt64:{ NonFungibleToken.NFT}}
		
		init(){ 
			self.ownedNFTs <-{} 
		}
		
		// openPack mint new NFTs from a Pack ID 
		//
		// Paramters: packID: The NFT id to open
		// Paramters: owner: The Pack NFT owner
		// Paramters: collection: The NFTs collection
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun openPack(packID: UInt64, owner: Address, collection: &{ARTIFACT.CollectionPublic}){ 
			let packRef = (&self.ownedNFTs[packID] as &{NonFungibleToken.NFT}?)!
			let pack = packRef as! &NFT
			var nfts: @[{NonFungibleToken.NFT}] <- pack.open(owner: owner)
			var quantity: Int = nfts.length
			var i: Int = 0
			while i < quantity{ 
				collection.deposit(token: <-nfts.removeFirst())
				i = i + 1
			}
			destroy nfts
		}
		
		// withdraw removes an ARTIFACTPack from the Collection and moves it to the caller
		//
		// Parameters: withdrawID: The ID of the NFT 
		// that is to be removed from the Collection
		//
		// returns: @NonFungibleToken.NFT the token that was withdrawn
		access(NonFungibleToken.Withdraw)
		fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT}{ 
			// Remove the nft from the Collection
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Cannot withdraw: ARTIFACTPack does not exist in the collection")
			emit Withdraw(id: token.id, from: self.owner?.address)
			// Return the withdrawn token
			return <-token
		}
		
		// deposit takes a ARTIFACTPack and adds it to the Collections dictionary
		//
		// Paramters: token: The NFT to be deposited in the collection
		//
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void{ 
			let token <- token as! @NFT
			let id = token.id
			let oldToken <- self.ownedNFTs[id] <- token
			if self.owner?.address != nil{ 
				emit Deposit(id: id, to: self.owner?.address)
			}
			destroy oldToken
		}
		
		// getIDs returns an array of the IDs that are in the Collection
		access(all)
		view fun getIDs(): [UInt64]{ 
			return self.ownedNFTs.keys
		}
		
		// borrow Returns a borrowed reference to a ARTIFACTPack in the Collection
		// so that the caller can read its ID
		//
		// Parameters: id: The ID of the NFT to get the reference for
		//
		// Returns: A reference to the NFT
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun borrow(id: UInt64): &ARTIFACTPack.NFT?{ 
			if self.ownedNFTs[id] != nil{ 
				let ref = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
				return ref as! &ARTIFACTPack.NFT
			} else{ 
				return nil
			}
		}
		
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?{ 
			return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
		}
		
		access(all)
		view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}?{ 
			let nft = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
			let artifactsPack = nft as! &NFT
			return artifactsPack as &{ViewResolver.Resolver}?
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
	// If a transaction destroys the Collection object,
	// All the NFTs contained within are also destroyed!
	// Much like when Damian Lillard destroys the hopes and
	// dreams of the entire city of Houston.
	//
	}
	
	// -----------------------------------------------------------------------
	// ARTIFACTPack contract-level function definitions
	// -----------------------------------------------------------------------
	// createEmptyCollection creates a new Collection a user can store 
	// it in their account storage.
	//
	access(all)
	fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection}{ 
		return <-create ARTIFACTPack.Collection()
	}
	
	// createPack creates a new Pack NFT used by ARTIFACTAdmin
	//
	access(account)
	fun createPack(packTemplate:{ Interfaces.IPackTemplate}, adminRef: Capability<&{Interfaces.ARTIFACTAdminOpener}>, owner: Address, listingID: UInt64): @NFT{ 
		if ARTIFACTPack.numberMintedByPack[packTemplate.templateId] == nil{ 
			ARTIFACTPack.numberMintedByPack[packTemplate.templateId] = 0
		}
		let edition = ARTIFACTPack.numberMintedByPack[packTemplate.templateId]!
		ARTIFACTPack.numberMintedByPack[packTemplate.templateId] = ARTIFACTPack.numberMintedByPack[packTemplate.templateId]! + 1
		let userPack <- create NFT(packTemplate: packTemplate, adminRef: adminRef, owner: owner, listingID: listingID, edition: edition)
		return <-userPack
	}
	
	// createPackTemplate creates a new Pack NFT template used by ARTIFACTAdmin
	//
	access(account)
	fun createPackTemplate(metadata:{ String: String}, totalSupply: UInt64, maxQuantityPerTransaction: UInt64, packsAvailable: [[UInt64]]): PackTemplate{ 
		var newPackTemplate = PackTemplate(metadata: metadata, totalSupply: totalSupply, maxQuantityPerTransaction: maxQuantityPerTransaction, packsAvailable: packsAvailable)
		ARTIFACTPack.templateDatas[newPackTemplate.templateId] = newPackTemplate
		return newPackTemplate
	}
	
	access(account)
	fun checkPackTemplateLockStatus(packTemplateId: UInt64): Bool{ 
		let packTemplate = ARTIFACTPack.templateDatas[packTemplateId]!
		return packTemplate.lockStatus
	}
	
	access(account)
	fun updateLockStatus(packTemplateId: UInt64, lockStatus: Bool){ 
		let packTemplate = ARTIFACTPack.templateDatas[packTemplateId]!
		packTemplate.updateLockStatus(lockStatus: lockStatus)
		ARTIFACTPack.templateDatas[packTemplateId] = packTemplate
	}
	
	// getPackTemplate get a specific templates stored in the contract by id
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun getPackTemplate(templateId: UInt64): PackTemplate?{ 
		return ARTIFACTPack.templateDatas[templateId]
	}
	
	// updatePackTemplate update a specific templates stored in the contract by id
	//
	access(account)
	fun updatePackTemplate(packTemplate: PackTemplate){ 
		ARTIFACTPack.templateDatas[packTemplate.templateId] = packTemplate
	}
	
	init(){ 
		// Paths
		self.collectionPublicPath = /public/ARTIFACTPackCollection
		self.collectionStoragePath = /storage/ARTIFACTPackCollection
		self.nextTemplateId = 1
		self.nextPackId = 1
		self.totalSupply = 0
		self.templateDatas ={} 
		self.numberMintedByPack ={} 
		emit ContractInitialized()
	}
}
