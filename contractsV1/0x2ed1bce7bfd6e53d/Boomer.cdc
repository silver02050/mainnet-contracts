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

access(all)
contract Boomer: NonFungibleToken{ 
	// -----------------------------------------------------------------------
	// Boomer contract-level fields.
	// These contain actual values that are stored in the smart contract.
	// -----------------------------------------------------------------------
	// The next template ID that is used to create Template. 
	// Every time a Template is created, nextTemplateId is assigned 
	// to the new Template's ID and then is incremented by 1.
	access(all)
	var nextTemplateId: UInt32
	
	// The total supply that is used to create FNT. 
	// Every time a NFT is created,  
	// totalSupply is incremented by 1 and then is assigned to NFT's ID.
	access(all)
	var totalSupply: UInt64
	
	// Variable size dictionary of minted templates structs
	access(contract)
	var numberMintedByTemplate:{ UInt32: UInt32}
	
	// Variable size dictionary of Template structs
	access(self)
	var templateDatas:{ UInt32: Template}
	
	/// Path where the public capability for the `Collection` is available
	access(all)
	let collectionPublicPath: PublicPath
	
	/// Path where the `Collection` is stored
	access(all)
	let collectionStoragePath: StoragePath
	
	/// Path where the `Admin` is stored
	access(all)
	let adminStoragePath: StoragePath
	
	/// Event used on withdraw NFT from collection
	access(all)
	event Withdraw(id: UInt64, from: Address?)
	
	/// Event used on deposit NFT to collection
	access(all)
	event Deposit(id: UInt64, to: Address?)
	
	/// Event used on mint NFT
	access(all)
	event NFTMinted(nftId: UInt64, templateId: UInt32, serialNumber: UInt32)
	
	/// Event used on contract initiation
	access(all)
	event ContractInitialized()
	
	// -----------------------------------------------------------------------
	// Boomer contract-level Composite Type definitions
	// -----------------------------------------------------------------------
	// These are just *definitions* for Types that this contract
	// and other accounts can use. These definitions do not contain
	// actual stored values, but an instance (or object) of one of these Types
	// can be created by this contract that contains stored values.
	// ----------------------------------------------------------------------- 
	// Template is a Struct that holds metadata associated with a specific 
	// nft
	//
	// NFT resource will all reference a single template as the owner of
	// its metadata. The templates are publicly accessible, so anyone can
	// read the metadata associated with a specific NFT ID
	//
	access(all)
	struct Template{ 
		access(all)
		let templateId: UInt32
		
		access(all)
		let metadata:{ String: String}
		
		init(metadata:{ String: String}){ 
			pre{ 
				metadata.length != 0:
					"Metadata cannot be empty"
			}
			self.templateId = Boomer.nextTemplateId
			self.metadata = metadata
			Boomer.nextTemplateId = Boomer.nextTemplateId + UInt32(1)
		}
	}
	
	// NFTData is a Struct that holds template's ID and a serial number
	//
	access(all)
	struct NFTData{ 
		access(all)
		let templateId: UInt32
		
		access(all)
		let serialNumber: UInt32
		
		init(serialNumber: UInt32, templateId: UInt32){ 
			self.templateId = templateId
			self.serialNumber = serialNumber
		}
	}
	
	// The resource that represents the NFT
	//
	access(all)
	resource NFT: NonFungibleToken.NFT{ 
		access(all)
		let id: UInt64
		
		access(all)
		let data: NFTData
		
		access(all)
		fun createEmptyCollection(): @{NonFungibleToken.Collection}{ 
			return <-create Collection()
		}
		
		init(serialNumber: UInt32, templateId: UInt32){ 
			Boomer.totalSupply = Boomer.totalSupply + UInt64(1)
			self.id = Boomer.totalSupply
			self.data = NFTData(serialNumber: serialNumber, templateId: templateId)
			emit NFTMinted(nftId: self.id, templateId: templateId, serialNumber: serialNumber)
		}
	}
	
	// Admin is a resource that deployer user has
	// to mint NFT and create templates
	//
	access(all)
	resource Admin{ 
		// mintTemplate create a new NFT using a template ID
		//
		// Parameters: templateId: The ID of the Template
		//
		// returns: @NonFungibleToken.NFT the token that was created
		access(TMP_ENTITLEMENT_OWNER)
		fun mintTemplate(templateId: UInt32): @NFT{ 
			let numMinted = Boomer.numberMintedByTemplate[templateId]!
			let newTemplate: @NFT <- create NFT(serialNumber: numMinted, templateId: templateId)
			Boomer.numberMintedByTemplate[templateId] = numMinted + UInt32(1)
			return <-newTemplate
		}
		
		// batchMintTemplate create a bunch of NFT using a template ID
		//
		// Parameters: templateId: The ID of the Template
		// Parameters: amount: Amount of NFT to be create
		//
		// returns: @Collection the collection with new NFTs 
		access(TMP_ENTITLEMENT_OWNER)
		fun batchMintTemplate(templateId: UInt32, amount: UInt64): @Collection{ 
			let newCollection <- create Collection()
			var i: UInt64 = 0
			while i < amount{ 
				newCollection.deposit(token: <-self.mintTemplate(templateId: templateId))
				i = i + UInt64(1)
			}
			return <-newCollection
		}
		
		// createTemplate create a template using a metadata 
		//
		// Parameters: metadata: The metadata to save inside Template 
		//
		// returns: UInt32 the new template ID 
		access(TMP_ENTITLEMENT_OWNER)
		fun createTemplate(metadata:{ String: String}): UInt32{ 
			var newTemplate = Template(metadata: metadata)
			Boomer.numberMintedByTemplate[newTemplate.templateId] = 0
			Boomer.templateDatas[newTemplate.templateId] = newTemplate
			return newTemplate.templateId
		}
	}
	
	// This is the interface that users can cast their NFT Collection as
	// to allow others to deposit NFT into their Collection, allows for reading
	// the NFT IDs and borrow NFT in the Collection. 
	access(all)
	resource interface BoomerCollectionPublic{ 
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void
		
		access(TMP_ENTITLEMENT_OWNER)
		fun batchDeposit(tokens: @{NonFungibleToken.Collection}): Void
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getIDs(): [UInt64]
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowNFT(id: UInt64): &{NonFungibleToken.NFT}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowBoomerNFT(id: UInt64): &Boomer.NFT?
	}
	
	// Collection is a resource that every user who owns NFTs 
	// will store in their account to manage their NFTS
	//
	access(all)
	resource Collection: BoomerCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.Collection, NonFungibleToken.CollectionPublic{ 
		// Dictionary of Moment conforming tokens
		// NFT is a resource type with a UInt64 ID field
		access(all)
		var ownedNFTs: @{UInt64:{ NonFungibleToken.NFT}}
		
		init(){ 
			self.ownedNFTs <-{} 
		}
		
		// withdraw removes an Moment from the Collection and moves it to the caller
		//
		// Parameters: withdrawID: The ID of the NFT 
		// that is to be removed from the Collection
		//
		// returns: @NonFungibleToken.NFT the token that was withdrawn
		access(NonFungibleToken.Withdraw)
		fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT}{ 
			// Remove the nft from the Collection
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Cannot withdraw: Moment does not exist in the collection")
			emit Withdraw(id: token.id, from: self.owner?.address)
			// Return the withdrawn token
			return <-token
		}
		
		// batchWithdraw withdraws multiple tokens and returns them as a Collection
		//
		// Parameters: ids: An array of IDs to withdraw
		//
		// Returns: @NonFungibleToken.Collection: A collection that contains
		//										the withdrawn moments
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun batchWithdraw(ids: [UInt64]): @{NonFungibleToken.Collection}{ 
			// Create a new empty Collection
			var batchCollection <- create Collection()
			// Iterate through the ids and withdraw them from the Collection
			for id in ids{ 
				batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
			}
			// Return the withdrawn tokens
			return <-batchCollection
		}
		
		// deposit takes a Moment and adds it to the Collections dictionary
		//
		// Paramters: token: the NFT to be deposited in the collection
		//
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void{ 
			let token <- token as! @Boomer.NFT
			let id = token.id
			let oldToken <- self.ownedNFTs[id] <- token
			if self.owner?.address != nil{ 
				emit Deposit(id: id, to: self.owner?.address)
			}
			destroy oldToken
		}
		
		// batchDeposit takes a Collection object as an argument
		// and deposits each contained NFT into this Collection
		access(TMP_ENTITLEMENT_OWNER)
		fun batchDeposit(tokens: @{NonFungibleToken.Collection}){ 
			let keys = tokens.getIDs()
			for key in keys{ 
				self.deposit(token: <-tokens.withdraw(withdrawID: key))
			}
			destroy tokens
		}
		
		// getIDs returns an array of the IDs that are in the Collection
		access(all)
		view fun getIDs(): [UInt64]{ 
			return self.ownedNFTs.keys
		}
		
		// borrowNFT Returns a borrowed reference to a Moment in the Collection
		// so that the caller can read its ID
		//
		// Parameters: id: The ID of the NFT to get the reference for
		//
		// Returns: A reference to the NFT
		//
		// Note: This only allows the caller to read the ID of the NFT,
		// not any topshot specific data. Please use borrowMoment to 
		// read Moment data.
		//
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?{ 
			return &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowBoomerNFT(id: UInt64): &Boomer.NFT?{ 
			if self.ownedNFTs[id] != nil{ 
				let ref = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
				return ref as! &Boomer.NFT
			} else{ 
				return nil
			}
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
	// Boomer contract-level function definitions
	// -----------------------------------------------------------------------
	// createEmptyCollection creates a new Collection a user can store 
	// it in their account storage.
	//
	access(all)
	fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection}{ 
		return <-create Boomer.Collection()
	}
	
	// getAllTemplates get all templates stored in the contract
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun getAllTemplates(): [Boomer.Template]{ 
		return Boomer.templateDatas.values
	}
	
	// getTemplate get specific template stored in the contract
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun getTemplate(templateId: UInt32): Boomer.Template?{ 
		return Boomer.templateDatas[templateId]
	}
	
	init(){ 
		// Paths
		self.collectionPublicPath = /public/BoomerCollection
		self.collectionStoragePath = /storage/BoomerCollection
		self.adminStoragePath = /storage/BoomerAdmin
		self.nextTemplateId = 1
		self.totalSupply = 0
		self.templateDatas ={} 
		self.numberMintedByTemplate ={} 
		self.account.storage.save<@Collection>(<-create Collection(), to: self.collectionStoragePath)
		var capability_1 = self.account.capabilities.storage.issue<&{BoomerCollectionPublic}>(self.collectionStoragePath)
		self.account.capabilities.publish(capability_1, at: self.collectionPublicPath)
		self.account.storage.save<@Admin>(<-create Admin(), to: self.adminStoragePath)
		emit ContractInitialized()
	}
}
