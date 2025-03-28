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

	// SPDX-License-Identifier: MIT
/*
	Description: Central Smart Contract for Everbloom
	Authors: Shehryar Shoukat shehryar@everbloom.app

	This contract contains the core functionality of Everbloom DApp

	The contract manages the data associated with all the galleries,
	artworks, and editions that are used as templates for the Print NFTs.

	First, the user will create a "User" resource instance and will store
	it in user storage. User resource needs minter resource capability to
	mint an NFT. Users can request minting capability from admin.

	User resource can create multiple gallery resources and store in user
	resource object. Gallery resources can be enabled and disabled.

	Gallery resource allows users to create multiple Artwork resources; It
	can be enabled and disabled. A disabled gallery cannot add new artwork.

	Artwork resource contains the ArtworkData struct and editions struct
	array. Artwork resource object and a copy of its ArtworkData struct are
	stored gallery resource objects. Artwork resources can create multiple
	editions. Artwork can be locked, which will prevent the addition of new
	editions. Users can mark the edition as completed, which will prevent
	further minting of NFTs under the edition.

	Admin resource can create a new admin and minter resource. The minter
	resource will be saved in admin storage to share private capability.
	Only minter resources can mint an NFT.

	The user resource can mint an NFT if it has a minting capability.
	Minting a "print" requires gallery, artwork, and edition.

	Note: All state changing functions will panic if an invalid argument is
	provided or one of its pre-conditions or post conditions aren't met.
*/

import NonFungibleToken from "./../../standardsV1/NonFungibleToken.cdc"

import ArtworkMetadata from "./ArtworkMetadata.cdc"

access(all)
contract Everbloom: NonFungibleToken{ 
	// -----------------------------------------------------------------------
	// Everbloom contract Events
	// -----------------------------------------------------------------------
	// Emitted when the Everbloom contract is created
	access(all)
	event ContractInitialized()
	
	// --- NFT Standard Events ---
	// Emitted on Everbloom NFT Withdrawal
	access(all)
	event Withdraw(id: UInt64, from: Address?)
	
	// Emitted on Everbloom NFT transfer
	access(all)
	event Transfer(id: UInt64, from: Address?, to: Address?)
	
	// Emitted on Everbloom NFT deposit
	access(all)
	event Deposit(id: UInt64, to: Address?)
	
	// --- Everbloom Event ---
	// Emitted when an NFT (print) is minted
	access(all)
	event PrintNFTMinted(nftID: UInt64, editionID: UInt32, artworkID: UInt32, galleryID: UInt32, serialNumber: UInt32, signature: String)
	
	// Emitted when an NFT (print) is detroyed
	access(all)
	event PrintNFTDestroyed(nftID: UInt64)
	
	// Emitted when an Artwork is created
	access(all)
	event ArtworkCreated(artworkID: UInt32, galleryID: UInt32, externalPostID: String, creator: ArtworkMetadata.Creator, content: ArtworkMetadata.Content, attributes: [ArtworkMetadata.Attribute])
	
	// Emitted when a Gallery is created
	access(all)
	event GalleryCreated(galleryID: UInt32, name: String)
	
	// Emitted when an Edition is created
	access(all)
	event EditionCreated(editionID: UInt32, name: String)
	
	// Emitted when an Edition is added to Artwork
	access(all)
	event EditionAddedToArtwork(editionID: UInt32, artworkID: UInt32)
	
	// Emitted when an Edition is marked as completed
	access(all)
	event ArtworkEditionCompleted(editionID: UInt32, artworkID: UInt32, numOfArtworks: UInt32)
	
	// Emitted when a Gallery is disabled
	access(all)
	event GalleryDisabled(galleryID: UInt32)
	
	// Emitted when a Gallery is enabled
	access(all)
	event GalleryEnabled(galleryID: UInt32)
	
	// Emitted when an Artwork is locked
	access(all)
	event ArtworkLocked(artworkID: UInt32)
	
	// Emitted when a user is created
	access(all)
	event UserCreated(userID: UInt64)
	
	// -----------------------------------------------------------------------
	// Everbloom contract-level fields
	// -----------------------------------------------------------------------
	// Storage Paths
	access(all)
	let CollectionStoragePath: StoragePath
	
	access(all)
	let CollectionPublicPath: PublicPath
	
	access(all)
	let AdminStoragePath: StoragePath
	
	access(all)
	let MinterStoragePath: StoragePath
	
	access(all)
	let MinterPrivatePath: PrivatePath
	
	access(all)
	let UserStoragePath: StoragePath
	
	access(all)
	let UserPublicPath: PublicPath
	
	// Maximum Limit Constants
	// Maximum number of Arts that can be added in a Gallery
	access(all)
	let maxArtLimit: UInt16
	
	// Maximum number of Editions that can be created in an Art
	access(all)
	let maxEditionLimit: UInt16
	
	// Maximum number of NFTs that can be mint in a batch
	access(all)
	let maxBatchMintSize: UInt16
	
	// Maximum number of NFTs that can be deposited in a batch
	access(all)
	let maxBatchDepositSize: UInt16
	
	// Maximum number of NFTs that can be withdrawn in a batch
	access(all)
	let maxBatchWithdrawalSize: UInt16
	
	// Every time an Edition is created, editionID is assigned
	// to the new Edition's editionID and then is incremented by 1.
	access(all)
	var nextEditionID: UInt32
	
	// Every time an Artwork is created, artworkID is assigned
	// to the new Artwork's artworkID and then is incremented by 1.
	access(all)
	var nextArtworkID: UInt32
	
	// Every time a Gallery is created, galleryID is assigned
	// to the new Gallery's galleryID and then is incremented by 1.
	access(all)
	var nextGalleryID: UInt32
	
	// Every time a User is created, userID is assigned
	// to the new User's userID and then is incremented by 1.
	access(all)
	var nextUserID: UInt64
	
	/* The total number of Print NFTs that have been created
		Because NFTs can be destroyed, it doesn't necessarily mean that this
		reflects the total number of NFTs in existence, just the number that
		have been minted to date. Also used as global Print IDs for minting. */
	
	access(all)
	var totalSupply: UInt64
	
	// -----------------------------------------------------------------------
	// Everbloom contract-level Composite Type definitions
	// -----------------------------------------------------------------------
	// PrintData is a Struct that holds metadata associated with Print NFT
	access(all)
	struct PrintData{ 
		access(all)
		let editionID: UInt32
		
		access(all)
		let artworkID: UInt32
		
		access(all)
		let galleryID: UInt32
		
		access(all)
		let serialNumber: UInt32
		
		access(all)
		let signature: String
		
		init(galleryID: UInt32, artworkID: UInt32, editionID: UInt32, serialNumber: UInt32, signature: String){ 
			self.galleryID = galleryID
			self.artworkID = artworkID
			self.editionID = editionID
			self.serialNumber = serialNumber
			self.signature = signature
		}
	}
	
	// The resource that represents the Print NFTs
	access(all)
	resource NFT: NonFungibleToken.NFT{ 
		// Global unique Artwork ID
		access(all)
		let id: UInt64
		
		// Struct of ArtworkData metadata
		access(all)
		let data: PrintData
		
		access(all)
		fun createEmptyCollection(): @{NonFungibleToken.Collection}{ 
			return <-create Collection()
		}
		
		init(galleryID: UInt32, artworkID: UInt32, editionID: UInt32, serialNumber: UInt32, signature: String){ 
			Everbloom.totalSupply = Everbloom.totalSupply + UInt64(1)
			self.id = Everbloom.totalSupply
			self.data = PrintData(galleryID: galleryID, artworkID: artworkID, editionID: editionID, serialNumber: serialNumber, signature: signature)
			emit PrintNFTMinted(nftID: self.id, editionID: self.data.editionID, artworkID: self.data.artworkID, galleryID: self.data.galleryID, serialNumber: self.data.serialNumber, signature: signature)
		}
	}
	
	// Edition is struct that groups multiple Prints in a Artwork resource
	access(all)
	struct Edition{ 
		access(all)
		let editionID: UInt32
		
		access(all)
		let artworkID: UInt32
		
		access(all)
		let name: String
		
		init(artworkID: UInt32, name: String){ 
			pre{ 
				name.length > 0:
					"New Edition name cannot be empty"
			}
			self.editionID = Everbloom.nextEditionID
			self.artworkID = artworkID
			self.name = name
			// Increment the nextEditionID so that it isn't used again
			Everbloom.nextEditionID = Everbloom.nextEditionID + UInt32(1)
		}
	}
	
	// ArtworkData holds the Metadata associated with an artwork
	// Any user can borrow the artwork to read its metadata
	access(all)
	struct ArtworkData{ 
		access(all)
		let galleryID: UInt32
		
		access(all)
		let artworkID: UInt32
		
		// externalPostID is the ID of a post in Everbloom Platform
		access(all)
		let externalPostID: String
		
		// creator metadata
		access(contract)
		let creator: ArtworkMetadata.Creator
		
		// content metadata
		access(contract)
		let content: ArtworkMetadata.Content
		
		// traits provided by the artwork creator and Everbloom
		access(contract)
		let attributes: [ArtworkMetadata.Attribute]
		
		// Additional Metadata
		access(contract)
		let additionalMetadata:{ String: AnyStruct}
		
		init(galleryID: UInt32, externalPostID: String, metadata:{ String: AnyStruct}){ 
			pre{ 
				metadata.length != 0:
					"Artwork metadata cannot be empty"
			}
			let creator = metadata.remove(key: "creator") ?? panic("Artwork creator metadata cannot be empty")
			let content = metadata.remove(key: "content") ?? panic("Artwork content metadata cannot be empty")
			let attributes = metadata.remove(key: "attributes") ?? []
			self.galleryID = galleryID
			self.artworkID = Everbloom.nextArtworkID
			self.creator = creator as! ArtworkMetadata.Creator
			self.content = content as! ArtworkMetadata.Content
			self.attributes = attributes as! [ArtworkMetadata.Attribute]
			self.additionalMetadata = metadata
			self.externalPostID = externalPostID
			// Increment the ID so that it isn't used again
			Everbloom.nextArtworkID = Everbloom.nextArtworkID + UInt32(1)
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getContent(): ArtworkMetadata.Content{ 
			return self.content
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getCreator(): ArtworkMetadata.Creator{ 
			return self.creator
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getAttributes(): [ArtworkMetadata.Attribute]{ 
			return self.attributes
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getAdditionalMetadata():{ String: AnyStruct}{ 
			return self.additionalMetadata
		}
	}
	
	// ArtworkPublic Interface is the public interface of Artwork
	// Any user can borrow the public reference of Artwork resource
	access(all)
	resource interface ArtworkPublic{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun getAllEditions(): [UInt32]
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getEditionData(editionID: UInt32): Edition?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getEditionNftCount(editionID: UInt32): UInt32
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getArtworkData(): ArtworkData
		
		access(TMP_ENTITLEMENT_OWNER)
		fun isLocked(): Bool
	}
	
	/* Representation of Artwork resource. Artwork resource groups prints by
		   editions. It contains metadata of artwork and number of NFTs minted in a edition.
	
			Artwork resource contains methods for addition of new editions, locking artwork,
			and marking edition as completed
	
		   A Post on Everbloom platform represent an Artwork
		*/
	
	access(all)
	resource Artwork: ArtworkPublic{ 
		access(all)
		let galleryID: UInt32
		
		access(all)
		let artworkID: UInt32
		
		// When artwork is locked no new edition can be added
		access(all)
		var locked: Bool
		
		access(all)
		let data: ArtworkData
		
		// editions is a dictionary that stores editions data against their editionID
		access(contract)
		let editions:{ UInt32: Edition}
		
		// editions is a dictionary that stores edition completion data
		access(contract)
		let editionCompleted:{ UInt32: Bool}
		
		// numberMintedPerEdition holds number of prints minted against editionID
		access(contract)
		let numberMintedPerEdition:{ UInt32: UInt32}
		
		init(galleryID: UInt32, externalPostID: String, metadata:{ String: AnyStruct}){ 
			self.artworkID = Everbloom.nextArtworkID
			self.galleryID = galleryID
			self.editions ={} 
			self.editionCompleted ={} 
			self.locked = false
			self.numberMintedPerEdition ={} 
			self.data = ArtworkData(galleryID: galleryID, externalPostID: externalPostID, metadata: metadata)
			emit ArtworkCreated(artworkID: self.artworkID, galleryID: self.galleryID, externalPostID: externalPostID, creator: self.data.creator, content: self.data.content, attributes: self.data.attributes)
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getArtworkData(): ArtworkData{ 
			return self.data
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getAllEditions(): [UInt32]{ 
			return self.editions.keys
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getEditionData(editionID: UInt32): Edition?{ 
			return self.editions[editionID]
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getEditionNftCount(editionID: UInt32): UInt32{ 
			pre{ 
				self.editions[editionID] != nil:
					"Edition does not exist"
			}
			return self.numberMintedPerEdition[editionID]!
		}
		
		access(contract)
		fun incrementEditionNftCount(editionID: UInt32): UInt32{ 
			pre{ 
				self.editions[editionID] != nil:
					"Edition does not exist"
			}
			self.numberMintedPerEdition[editionID] = self.numberMintedPerEdition[editionID]! + UInt32(1)
			return self.numberMintedPerEdition[editionID]!
		}
		
		/* This method creates new edition
		
					parameter: name: name of the edition
		
					return editionID
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun createEdition(name: String): UInt32{ 
			pre{ 
				self.editions.length < Int(Everbloom.maxEditionLimit):
					"Cannot add create edition. Maximum number of editions in arts is ".concat(Everbloom.maxEditionLimit.toString())
			}
			let newEdition: Edition = Edition(artworkID: self.artworkID, name: name)
			emit EditionCreated(editionID: newEdition.editionID, name: name)
			self.addEdition(edition: newEdition)
			return newEdition.editionID
		}
		
		/* This method adds new edition in artwork
		
					parameter:  edition: Edition struct
		
					Pre-Conditions:
					edition should have editionID
					artwork should not be locked
					edition should not exist in artwork
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun addEdition(edition: Edition){ 
			pre{ 
				edition.editionID != nil:
					"Edition should have editionID"
				!self.locked:
					"Cannot add the edition to the Artwork after the artwork has been locked."
				self.numberMintedPerEdition[edition.editionID] == nil:
					"The edition has already beed added to the artwork."
			}
			self.editions[edition.editionID] = edition
			// Set Edition to not completed
			self.editionCompleted[edition.editionID] = false
			// Initialize the mint count to zero
			self.numberMintedPerEdition[edition.editionID] = 0
			emit EditionAddedToArtwork(editionID: edition.editionID, artworkID: self.artworkID)
		}
		
		/* This method mark edition as completed
		
					parameter:  editionID: id of the edition
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun setEditionComplete(editionID: UInt32){ 
			pre{ 
				self.editionCompleted[editionID] != nil:
					"Cannot set Edition to Complete: Edition doesn't exist in this Artwork!"
			}
			if !self.editionCompleted[editionID]!{ 
				self.editionCompleted[editionID] = true
				emit ArtworkEditionCompleted(editionID: editionID, artworkID: self.artworkID, numOfArtworks: self.numberMintedPerEdition[editionID]!)
			}
		}
		
		// This method mark all edition of the artwork as completed
		access(TMP_ENTITLEMENT_OWNER)
		fun setAllEditionsComplete(){ 
			for edition in self.editions.values{ 
				self.setEditionComplete(editionID: edition.editionID)
			}
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun isEditionCompleted(editionID: UInt32): Bool{ 
			pre{ 
				self.editionCompleted[editionID] != nil:
					"Edition doesn't exist."
			}
			return self.editionCompleted[editionID]!
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun isLocked(): Bool{ 
			return self.locked
		}
		
		// This method locks the artwork
		access(TMP_ENTITLEMENT_OWNER)
		fun lock(){ 
			if !self.locked{ 
				self.locked = true
				emit ArtworkLocked(artworkID: self.artworkID)
			}
		}
	}
	
	// GalleryPublic Interface is the public interface of Gallery
	// Any user can borrow the public reference of gallery resource
	access(all)
	resource interface GalleryPublic{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun getAllArtworks(): [UInt32]
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowArtwork(artworkID: UInt32): &Artwork?
	}
	
	/* Representation of Gallery resource. Gallery resource contains Artworks information.
	
			gallery resource contains methods for addition of new artworks, borrowing of artworks,
			enabling, and disabling of Gallery
	
		   A gallery on Everbloom platform represent an Gallery resource
		*/
	
	access(all)
	resource Gallery: GalleryPublic{ 
		access(all)
		let galleryID: UInt32
		
		// artworks stores artwork resources against artworkID
		access(contract)
		let artworks: @{UInt32: Artwork}
		
		// artworkDatas stores artwork metadata against artworkID
		access(contract)
		let artworkDatas:{ UInt32: ArtworkData}
		
		// When gallery is disabled no new artwork can be added
		access(all)
		var disabled: Bool
		
		// name of the gallery
		access(all)
		var name: String
		
		init(name: String){ 
			self.galleryID = Everbloom.nextGalleryID
			self.artworks <-{} 
			self.artworkDatas ={} 
			self.disabled = false
			self.name = name
			Everbloom.nextGalleryID = Everbloom.nextGalleryID + UInt32(1)
			emit GalleryCreated(galleryID: self.galleryID, name: self.name)
		}
		
		/* This method creates and add new artwork
		
					parameter:
					  externalPostID: Everbloom post id
					  metadata: metadata of the artwork
		
					Pre-Conditions:
					gallery should be enabled
		
					return artworkID: id of the artwork
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun createArtwork(externalPostID: String, metadata:{ String: AnyStruct}): UInt32{ 
			pre{ 
				!self.disabled:
					"Cannot add create artwork to the Gallery after the gallery has been disabled."
				self.artworks.length < Int(Everbloom.maxArtLimit):
					"Cannot add create artwork. Maximum number of Artworks in gallery is ".concat(Everbloom.maxArtLimit.toString())
			}
			// Create the new Artwork
			var newArtwork: @Artwork <- create Artwork(galleryID: self.galleryID, externalPostID: externalPostID, metadata: metadata)
			let newID = newArtwork.artworkID
			// Store it in the contract storage
			self.artworkDatas[newID] = newArtwork.data
			self.artworks[newID] <-! newArtwork
			return newID
		}
		
		// This method disables the gallery
		access(TMP_ENTITLEMENT_OWNER)
		fun disableGallery(){ 
			if !self.disabled{ 
				self.disabled = true
				emit GalleryDisabled(galleryID: self.galleryID)
			}
		}
		
		// This method enables the gallery
		access(TMP_ENTITLEMENT_OWNER)
		fun enableGallery(){ 
			if self.disabled{ 
				self.disabled = false
				emit GalleryEnabled(galleryID: self.galleryID)
			}
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getAllArtworks(): [UInt32]{ 
			return self.artworks.keys
		}
		
		/* This method returns a reference to an Artwork resource
		
					parameters: artworkID: id of the artwork
		
					return reference to the artwork resource or nil if no artwork is found
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowArtwork(artworkID: UInt32): &Artwork?{ 
			if self.artworks[artworkID] != nil{ 
				let ref = &self.artworks[artworkID] as &Artwork?
				return ref
			} else{ 
				return nil
			}
		}
		
		/* This method returns a reference to an Artwork resource
		
					parameters: externalPostID: id of the post in Everbloom platform
		
					return reference to the artwork resource or nil if no artwork is found
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowArtworkByPostID(externalPostID: String): &Artwork?{ 
			// Iterate through all the artworkDatas and search for the externalPostID
			for artworkData in self.artworkDatas.values{ 
				if externalPostID == artworkData.externalPostID{ 
					// If the externalPostID is found, return the artwork
					return &self.artworks[artworkData.artworkID] as &Artwork?
				}
			}
			return nil
		}
	}
	
	// UserPublic Interface is the public interface of User
	// Any user can borrow the public reference of other user resource
	access(all)
	resource interface UserPublic{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun getAllGalleries(): [UInt32]
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowGallery(galleryID: UInt32): &Gallery?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun setMinterCapability(minterCapability: Capability<&Minter>)
	}
	
	/*  Representation of User resource. User resource contains Galleries information and
			User minting capability.
	
			User resource contains methods for addition of new galleries, borrowing of galleries,
			and minting of prints.
	
		   A profile on Everbloom platform represent a User resource
		*/
	
	access(all)
	resource User: UserPublic{ 
		access(all)
		let userID: UInt64
		
		// galleries dictionary stores gallery resource against galleryID
		access(self)
		let galleries: @{UInt32: Gallery}
		
		// Minting resource capability. it can be request from admin
		access(self)
		var minterCapability: Capability<&Minter>?
		
		init(){ 
			self.userID = Everbloom.nextUserID
			self.galleries <-{} 
			self.minterCapability = nil
			Everbloom.nextUserID = Everbloom.nextUserID + UInt64(1)
			emit UserCreated(userID: self.userID)
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getAllGalleries(): [UInt32]{ 
			return self.galleries.keys
		}
		
		/* This method update minting capability of the user
		
					parameters: minterCapability: capability of minting resource
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun setMinterCapability(minterCapability: Capability<&Minter>){ 
			self.minterCapability = minterCapability
		}
		
		/* This method returns a reference to a gallery resource
		
					parameters: galleryID: id of the gallery
		
					return reference to the gallery resource or nil if no gallery is found
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowGallery(galleryID: UInt32): &Gallery?{ 
			pre{ 
				self.galleries[galleryID] != nil:
					"Cannot borrow Gallery: The Gallery doesn't exist"
			}
			// Get a reference to the Gallery and return it
			// use `&` to indicate the reference to the object and type
			return &self.galleries[galleryID] as &Gallery?
		}
		
		/* This method creates a gallery resource and will store it in galleries dictionary
		
					parameters: name: name of the gallery
		
					return galleryID
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun createGallery(name: String): UInt32{ 
			// Create the new Gallery
			var newGallery <- create Everbloom.Gallery(name: name)
			let newGalleryID = newGallery.galleryID
			// Store it in the galleries mapping field
			self.galleries[newGalleryID] <-! newGallery
			return newGalleryID
		}
		
		/* This method mints an Print NFT under a edition
		
					parameters:
					 galleryID: id of the gallery
					 artworkID: id of the artwork
					 editionID: id of the edition
					 signature: url of the signature for the NFT
		
					return @NFT: minted NFT resource
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun mintPrint(galleryID: UInt32, artworkID: UInt32, editionID: UInt32, signature: String): @NFT{ 
			let galleryRef: &Gallery = self.borrowGallery(galleryID: galleryID) ?? panic("Cannot mint the print: unable to borrow gallery")
			let artwork: &Artwork = galleryRef.borrowArtwork(artworkID: artworkID) ?? panic("Cannot mint the print: unable to borrow artwork")
			if artwork.isEditionCompleted(editionID: editionID){ 
				panic("Cannot mint the print from this edition: This edition has been completed.")
			}
			let numOfArtworks = artwork.numberMintedPerEdition[editionID]!
			var minterCapability: Capability<&Minter> = self.minterCapability ?? panic("Minting capability not found")
			let minterRef: &Everbloom.Minter = minterCapability.borrow() ?? panic("Cannot borrow minting resource")
			let newPrint: @NFT <- minterRef.mintNFT(galleryID: galleryID, artworkID: artwork.artworkID, editionID: editionID, serialNumber: numOfArtworks + UInt32(1), signature: signature)
			artwork.incrementEditionNftCount(editionID: editionID)
			return <-newPrint
		}
		
		/* This method mints NFTs in batch
		
					return  @NonFungibleToken.Collection: collection of minted NFTs
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun batchMintPrint(galleryID: UInt32, artworkID: UInt32, editionID: UInt32, signatures: [String]): @Collection{ 
			pre{ 
				signatures.length < Int(Everbloom.maxBatchMintSize):
					"Maximum number of NFT that can be minted in a batch is ".concat(Everbloom.maxBatchMintSize.toString())
			}
			let newCollection <- create Collection()
			for signature in signatures{ 
				newCollection.deposit(token: <-self.mintPrint(galleryID: galleryID, artworkID: artworkID, editionID: editionID, signature: signature))
			}
			return <-newCollection
		}
		
		// This method disables the gallery
		access(TMP_ENTITLEMENT_OWNER)
		fun disableGallery(galleryID: UInt32){ 
			pre{ 
				self.galleries[galleryID] != nil:
					"Cannot borrow Gallery: The Gallery doesn't exist"
			}
			let gallery = &self.galleries[galleryID] as &Everbloom.Gallery?
			(gallery!).disableGallery()
		}
		
		// This method enables the gallery
		access(TMP_ENTITLEMENT_OWNER)
		fun unlockGallery(galleryID: UInt32){ 
			pre{ 
				self.galleries[galleryID] != nil:
					"Cannot borrow Gallery: The Gallery doesn't exist"
			}
			let gallery = &self.galleries[galleryID] as &Everbloom.Gallery?
			(gallery!).enableGallery()
		}
	}
	
	/*  Representation of Minter resource. It is can created by Admin resource. User needs
			minter resource capability to mint an NFT.
			Only minter resource can mint an NFT Print
		*/
	
	access(all)
	resource Minter{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun mintNFT(galleryID: UInt32, artworkID: UInt32, editionID: UInt32, serialNumber: UInt32, signature: String): @Everbloom.NFT{ 
			let newPrint: @NFT <- create NFT(galleryID: galleryID, artworkID: artworkID, editionID: editionID, serialNumber: serialNumber, signature: signature)
			return <-newPrint
		}
	}
	
	/*  Representation of Admin resource. It can create new Admin and Minter resource.
		*/
	
	access(all)
	resource Admin{ 
		/* This method creates new Admin resource
		
					return @Admin: admin resource
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun createNewAdmin(): @Admin{ 
			return <-create Admin()
		}
		
		/* This method creates new Minter resource
		
					return @Minter: minter reource
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun createNewMinter(): @Minter{ 
			return <-create Minter()
		}
	}
	
	// -----------------------------------------------------------------------
	// Everbloom Collection Logic
	// -----------------------------------------------------------------------
	// PrintCollectionPublic Interface is the public interface of Collection
	// Any user can borrow the public reference of collection resource
	access(all)
	resource interface PrintCollectionPublic{ 
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void
		
		access(TMP_ENTITLEMENT_OWNER)
		fun batchDeposit(tokens: @{NonFungibleToken.Collection}): Void
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getIDs(): [UInt64]
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowNFT(id: UInt64): &{NonFungibleToken.NFT}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowPrint(id: UInt64): &Everbloom.NFT?{ 
			// If the result isn't nil, the id of the returned reference
			// should be the same as the argument to the function
			post{ 
				result == nil || result?.id == id:
					"Cannot borrow Print reference: The ID of the returned reference is incorrect"
			}
		}
	}
	
	access(all)
	resource Collection: PrintCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.Collection, NonFungibleToken.CollectionPublic{ 
		// NFT is a resource type with a UInt64 ID field
		access(all)
		var ownedNFTs: @{UInt64:{ NonFungibleToken.NFT}}
		
		init(){ 
			self.ownedNFTs <-{} 
		}
		
		/*  withdraw removes an Print from the Collection and moves it to the caller
		
					Parameters: withdrawID: The ID of the NFT
					that is to be removed from the Collection
		
					returns: @NonFungibleToken.NFT the token that was withdrawn
				*/
		
		access(NonFungibleToken.Withdraw)
		fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT}{ 
			// Remove the nft from the Collection
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Cannot withdraw: Artwork Piece does not exist in the collection")
			emit Withdraw(id: token.id, from: self.owner?.address)
			// Return the withdrawn token
			return <-token
		}
		
		/*  batchWithdraw withdraws multiple tokens and returns them as a Collection
		
					Parameters: ids: An array of IDs to withdraw
		
					Returns: @NonFungibleToken.Collection: A collection that contains the withdrawn print
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun batchWithdraw(ids: [UInt64]): @{NonFungibleToken.Collection}{ 
			pre{ 
				ids.length < Int(Everbloom.maxBatchWithdrawalSize):
					"Maximum number of NFT that can be withdraw in a batch is ".concat(Everbloom.maxBatchWithdrawalSize.toString())
			}
			// Create a new empty Collection
			var batchCollection <- create Collection()
			// Iterate through the ids and withdraw them from the Collection
			for id in ids{ 
				batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
			}
			// Return the withdrawn tokens
			return <-batchCollection
		}
		
		/*  deposit takes a Print and adds it to the Collections dictionary
		
					Parameters: token: the NFT to be deposited in the collection
				*/
		
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void{ 
			// Cast the deposited token as a Everbloom NFT to make sure
			// it is the correct type
			let token <- token as! @Everbloom.NFT
			// Get the token's ID
			let id = token.id
			// Add the new token to the dictionary
			let oldToken <- self.ownedNFTs[id] <- token
			// Only emit a deposit event if the Collection
			// is in an account's storage
			if self.owner?.address != nil{ 
				emit Deposit(id: id, to: self.owner?.address)
			}
			// Destroy the empty old token that was "removed"
			destroy oldToken
		}
		
		// batchDeposit takes a Collection object as an argument
		// and deposits each contained NFT into this Collection
		access(TMP_ENTITLEMENT_OWNER)
		fun batchDeposit(tokens: @{NonFungibleToken.Collection}){ 
			pre{ 
				tokens.getIDs().length < Int(Everbloom.maxBatchDepositSize):
					"Maximum number of NFT that can be deposited in a batch is ".concat(Everbloom.maxBatchDepositSize.toString())
			}
			// Get an array of the IDs to be deposited
			let keys = tokens.getIDs()
			// Iterate through the keys in the collection and deposit each one
			for key in keys{ 
				self.deposit(token: <-tokens.withdraw(withdrawID: key))
			}
			// Destroy the empty Collection
			destroy tokens
		}
		
		/*  Transfer the NFT
		
					Parameters:
					 withdrawID: id of the NFT to be transferred
					 target: NFT receiver capability of the receiver
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun transfer(withdrawID: UInt64, target: Capability<&{NonFungibleToken.Receiver}>){ 
			let token <- self.withdraw(withdrawID: withdrawID)
			emit Transfer(id: token.uuid, from: self.owner?.address, to: target.address)
			(target.borrow()!).deposit(token: <-token)
		}
		
		// getIDs returns an array of the IDs that are in the Collection
		access(all)
		view fun getIDs(): [UInt64]{ 
			return self.ownedNFTs.keys
		}
		
		/*  borrowNFT Returns a borrowed reference to a Print in the Collection
					so that the caller can read its ID
		
					Parameters: id: The ID of the NFT to get the reference for
		
					Returns: A reference to the NFT
				*/
		
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?{ 
			return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
		}
		
		/*  borrowPrint returns a borrowed reference to a Print
					so that the caller can read data and call methods from it.
					They can use this to read its Printdata associated with it.
		
					Parameters: id: The ID of the NFT to get the reference for
		
					Returns: A reference to the NFT
				*/
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowPrint(id: UInt64): &Everbloom.NFT?{ 
			if self.ownedNFTs[id] != nil{ 
				let ref = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
				return ref as! &Everbloom.NFT
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
	}
	
	// -----------------------------------------------------------------------
	// Everbloom contract-level function definitions
	// -----------------------------------------------------------------------
	/* This method creates new User resource
	
			return @User: user resource
		*/
	
	access(TMP_ENTITLEMENT_OWNER)
	fun createUser(): @User{ 
		return <-create User()
	}
	
	/* This method creates new Collection resource
	
			return @NonFungibleToken.Collection: collection resource
		*/
	
	access(all)
	fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection}{ 
		return <-create Everbloom.Collection()
	}
	
	// -----------------------------------------------------------------------
	// Everbloom initialization function
	// -----------------------------------------------------------------------
	//
	init(){ 
		// Initialize contract fields
		self.totalSupply = 0
		self.nextArtworkID = 1
		self.nextEditionID = 1
		self.nextGalleryID = 1
		self.nextUserID = 1
		self.maxArtLimit = 10_000
		self.maxEditionLimit = 10
		self.maxBatchMintSize = 10_000
		self.maxBatchDepositSize = 10_000
		self.maxBatchWithdrawalSize = 10_000
		// set contract paths
		self.CollectionStoragePath = /storage/EverbloomCollection
		self.CollectionPublicPath = /public/EverbloomCollection
		self.AdminStoragePath = /storage/EverbloomAdmin
		self.UserStoragePath = /storage/EverbloomUser
		self.UserPublicPath = /public/EverbloomUser
		self.MinterStoragePath = /storage/EverbloomMinter
		self.MinterPrivatePath = /private/EverbloomMinter
		// store admin resource in admin account
		self.account.storage.save<@Admin>(<-create Admin(), to: self.AdminStoragePath)
		emit ContractInitialized()
	}
}
