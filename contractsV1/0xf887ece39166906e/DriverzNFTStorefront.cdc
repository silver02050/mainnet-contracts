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

	import FungibleToken from "./../../standardsV1/FungibleToken.cdc"

import NonFungibleToken from "./../../standardsV1/NonFungibleToken.cdc"

access(all)
contract DriverzNFTStorefront{ 
	access(all)
	event DriverzNFTStorefrontInitialized()
	
	access(all)
	event StorefrontInitialized(storefrontResourceID: UInt64)
	
	access(all)
	event StorefrontDestroyed(storefrontResourceID: UInt64)
	
	access(all)
	event ListingAvailable(
		storefrontAddress: Address,
		listingResourceID: UInt64,
		nftType: Type,
		nftID: UInt64,
		ftVaultType: Type,
		price: UFix64
	)
	
	access(all)
	event ListingCompleted(
		listingResourceID: UInt64,
		storefrontResourceID: UInt64,
		purchased: Bool,
		nftType: Type,
		nftID: UInt64
	)
	
	access(all)
	let StorefrontStoragePath: StoragePath
	
	access(all)
	let StorefrontPublicPath: PublicPath
	
	access(contract)
	let ListedDriverz:{ Address: [UInt64]}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun getAddresses(): [Address]{ 
		return DriverzNFTStorefront.ListedDriverz.keys
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun getList():{ Address: [UInt64]}{ 
		return DriverzNFTStorefront.ListedDriverz
	}
	
	//A function that it's called only inside contract that add a listing to the contract ListedDriverz dictionary
	access(contract)
	fun addListing(address: Address, storefrontID: UInt64){ 
		if DriverzNFTStorefront.ListedDriverz[address] == nil{ 
			DriverzNFTStorefront.ListedDriverz[address] = [storefrontID]
		} else{ 
			(DriverzNFTStorefront.ListedDriverz[address]!).append(storefrontID)
		}
	}
	
	//A function that it's called only inside contract that remove a listing from the contract ListedDriverz dictionary
	access(contract)
	fun removeListing(address: Address, storefrontID: UInt64){ 
		if DriverzNFTStorefront.ListedDriverz[address] != nil{ 
			if (DriverzNFTStorefront.ListedDriverz[address]!).length == 1{ 
				DriverzNFTStorefront.ListedDriverz.remove(key: address)
			} else{ 
				let index = (DriverzNFTStorefront.ListedDriverz[address]!).firstIndex(of: storefrontID)!
				(DriverzNFTStorefront.ListedDriverz[address]!).remove(at: index)
			}
		}
	}
	
	access(all)
	struct SaleCut{ 
		access(all)
		let receiver: Capability<&{FungibleToken.Receiver}>
		
		// The amount of the payment FungibleToken that will be paid to the receiver.
		access(all)
		let amount: UFix64
		
		// initializer
		//
		init(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64){ 
			self.receiver = receiver
			self.amount = amount
		}
	}
	
	access(all)
	struct ListingDetails{ 
		access(all)
		var storefrontID: UInt64
		
		// Whether this listing has been purchased or not.
		access(all)
		var purchased: Bool
		
		// The Type of the NonFungibleToken.NFT that is being listed.
		access(all)
		let nftType: Type
		
		// The ID of the NFT within that type.
		access(all)
		let nftID: UInt64
		
		// The Type of the FungibleToken that payments must be made in.
		access(all)
		let salePaymentVaultType: Type
		
		// The amount that must be paid in the specified FungibleToken.
		access(all)
		let salePrice: UFix64
		
		// This specifies the division of payment between recipients.
		access(all)
		let saleCuts: [SaleCut]
		
		// setToPurchased
		// Irreversibly set this listing as purchased.
		//
		access(contract)
		fun setToPurchased(){ 
			self.purchased = true
		}
		
		// initializer
		//
		init(
			nftType: Type,
			nftID: UInt64,
			salePaymentVaultType: Type,
			saleCuts: [
				SaleCut
			],
			storefrontID: UInt64
		){ 
			self.storefrontID = storefrontID
			self.purchased = false
			self.nftType = nftType
			self.nftID = nftID
			self.salePaymentVaultType = salePaymentVaultType
			// Store the cuts
			assert(
				saleCuts.length > 0,
				message: "Listing must have at least one payment cut recipient"
			)
			self.saleCuts = saleCuts
			// Calculate the total price from the cuts
			var salePrice = 0.0
			// Perform initial check on capabilities, and calculate sale price from cut amounts.
			for cut in self.saleCuts{ 
				// Make sure we can borrow the receiver.
				// We will check this again when the token is sold.
				cut.receiver.borrow() ?? panic("Cannot borrow receiver")
				// Add the cut amount to the total price
				salePrice = salePrice + cut.amount
			}
			assert(salePrice > 0.0, message: "Listing must have non-zero price")
			// Store the calculated sale price
			self.salePrice = salePrice
		}
	}
	
	// ListingPublic
	// An interface providing a useful public interface to a Listing.
	//
	access(all)
	resource interface ListingPublic{ 
		// borrowNFT
		// This will assert in the same way as the NFT standard borrowNFT()
		// if the NFT is absent, for example if it has been sold via another listing.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowNFT(): &{NonFungibleToken.NFT}
		
		// purchase
		// Purchase the listing, buying the token.
		// This pays the beneficiaries and returns the token to the buyer.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun purchase(payment: @{FungibleToken.Vault}): @{NonFungibleToken.NFT}
		
		// getDetails
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun getDetails(): ListingDetails
	}
	
	// Listing
	// A resource that allows an NFT to be sold for an amount of a given FungibleToken,
	// and for the proceeds of that sale to be split between several recipients.
	// 
	access(all)
	resource Listing: ListingPublic{ 
		// The simple (non-Capability, non-complex) details of the sale
		access(self)
		let details: ListingDetails
		
		// A capability allowing this resource to withdraw the NFT with the given ID from its collection.
		// This capability allows the resource to withdraw *any* NFT, so you should be careful when giving
		// such a capability to a resource and always check its code to make sure it will use it in the
		// way that it claims.
		access(contract)
		let nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
		
		// borrowNFT
		// This will assert in the same way as the NFT standard borrowNFT()
		// if the NFT is absent, for example if it has been sold via another listing.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowNFT(): &{NonFungibleToken.NFT}{ 
			let ref = (self.nftProviderCapability.borrow()!).borrowNFT(self.getDetails().nftID)
			//- CANNOT DO THIS IN PRECONDITION: "member of restricted type is not accessible: isInstance"
			//  result.isInstance(self.getDetails().nftType): "token has wrong type"
			assert(ref.isInstance(self.getDetails().nftType), message: "token has wrong type")
			assert(ref.id == self.getDetails().nftID, message: "token has wrong ID")
			return (ref as &{NonFungibleToken.NFT}?)!
		}
		
		// getDetails
		// Get the details of the current state of the Listing as a struct.
		// This avoids having more public variables and getter methods for them, and plays
		// nicely with scripts (which cannot return resources). 
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun getDetails(): ListingDetails{ 
			return self.details
		}
		
		// purchase
		// Purchase the listing, buying the token.
		// This pays the beneficiaries and returns the token to the buyer.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun purchase(payment: @{FungibleToken.Vault}): @{NonFungibleToken.NFT}{ 
			pre{ 
				self.details.purchased == false:
					"listing has already been purchased"
				payment.isInstance(self.details.salePaymentVaultType):
					"payment vault is not requested fungible token"
				payment.balance == self.details.salePrice:
					"payment vault does not contain requested price"
			}
			// Make sure the listing cannot be purchased again.
			self.details.setToPurchased()
			let sellerAddress = ((self.nftProviderCapability.borrow()!).owner!).address
			DriverzNFTStorefront.removeListing(address: sellerAddress, storefrontID: self.uuid)
			// Fetch the token to return to the purchaser.
			let nft <- (self.nftProviderCapability.borrow()!).withdraw(withdrawID: self.details.nftID)
			// Neither receivers nor providers are trustworthy, they must implement the correct
			// interface but beyond complying with its pre/post conditions they are not gauranteed
			// to implement the functionality behind the interface in any given way.
			// Therefore we cannot trust the Collection resource behind the interface,
			// and we must check the NFT resource it gives us to make sure that it is the correct one.
			assert(nft.isInstance(self.details.nftType), message: "withdrawn NFT is not of specified type")
			assert(nft.id == self.details.nftID, message: "withdrawn NFT does not have specified ID")
			// Rather than aborting the transaction if any receiver is absent when we try to pay it,
			// we send the cut to the first valid receiver.
			// The first receiver should therefore either be the seller, or an agreed recipient for
			// any unpaid cuts.
			var residualReceiver: &{FungibleToken.Receiver}? = nil
			// Pay each beneficiary their amount of the payment.
			for cut in self.details.saleCuts{ 
				if let receiver = cut.receiver.borrow(){ 
					let paymentCut <- payment.withdraw(amount: cut.amount)
					receiver.deposit(from: <-paymentCut)
					if residualReceiver == nil{ 
						residualReceiver = receiver
					}
				}
			}
			assert(residualReceiver != nil, message: "No valid payment receivers")
			(			 // At this point, if all recievers were active and availabile, then the payment Vault will have
			 // zero tokens left, and this will functionally be a no-op that consumes the empty vault
			 residualReceiver!).deposit(from: <-payment)
			// If the listing is purchased, we regard it as completed here.
			// Otherwise we regard it as completed in the destructor.		
			emit ListingCompleted(listingResourceID: self.uuid, storefrontResourceID: self.details.storefrontID, purchased: self.details.purchased, nftType: self.details.nftType, nftID: self.details.nftID)
			return <-nft
		}
		
		// destructor
		//
		// initializer
		//
		init(nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>, nftType: Type, nftID: UInt64, salePaymentVaultType: Type, saleCuts: [SaleCut], storefrontID: UInt64){ 
			// Store the sale information
			self.details = ListingDetails(nftType: nftType, nftID: nftID, salePaymentVaultType: salePaymentVaultType, saleCuts: saleCuts, storefrontID: storefrontID)
			// Store the NFT provider
			self.nftProviderCapability = nftProviderCapability
			// Check that the provider contains the NFT.
			// We will check it again when the token is sold.
			// We cannot move this into a function because initializers cannot call member functions.
			let provider = self.nftProviderCapability.borrow()
			assert(provider != nil, message: "cannot borrow nftProviderCapability")
			// This will precondition assert if the token is not available.
			let nft = (provider!).borrowNFT(self.details.nftID)
			assert(nft.isInstance(self.details.nftType), message: "token is not of specified type")
			assert(nft.id == self.details.nftID, message: "token does not have specified ID")
		}
	}
	
	// StorefrontManager
	// An interface for adding and removing Listings within a Storefront,
	// intended for use by the Storefront's own
	//
	access(all)
	resource interface StorefrontManager{ 
		// createListing
		// Allows the Storefront owner to create and insert Listings.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun createListing(
			nftProviderCapability: Capability<
				&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}
			>,
			nftType: Type,
			nftID: UInt64,
			salePaymentVaultType: Type,
			saleCuts: [
				DriverzNFTStorefront.SaleCut
			]
		): UInt64
		
		// removeListing
		// Allows the Storefront owner to remove any sale listing, acepted or not.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun removeListing(listingResourceID: UInt64, address: Address)
	}
	
	// StorefrontPublic
	// An interface to allow listing and borrowing Listings, and purchasing items via Listings
	// in a Storefront.
	//
	access(all)
	resource interface StorefrontPublic{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun getListingIDs(): [UInt64]
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowListing(listingResourceID: UInt64): &Listing?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun cleanup(listingResourceID: UInt64)
	}
	
	// Storefront
	// A resource that allows its owner to manage a list of Listings, and anyone to interact with them
	// in order to query their details and purchase the NFTs that they represent.
	//
	access(all)
	resource Storefront: StorefrontManager, StorefrontPublic{ 
		// The dictionary of Listing uuids to Listing resources.
		access(self)
		var listings: @{UInt64: Listing}
		
		// insert
		// Create and publish a Listing for an NFT.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun createListing(nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>, nftType: Type, nftID: UInt64, salePaymentVaultType: Type, saleCuts: [SaleCut]): UInt64{ 
			let listing <- create Listing(nftProviderCapability: nftProviderCapability, nftType: nftType, nftID: nftID, salePaymentVaultType: salePaymentVaultType, saleCuts: saleCuts, storefrontID: self.uuid)
			let listingResourceID = listing.uuid
			let listingPrice = listing.getDetails().salePrice
			// Add the new listing to the dictionary.
			let oldListing <- self.listings[listingResourceID] <- listing
			// Note that oldListing will always be nil, but we have to handle it.
			DriverzNFTStorefront.addListing(address: self.owner?.address!, storefrontID: listingResourceID)
			destroy oldListing
			emit ListingAvailable(storefrontAddress: self.owner?.address!, listingResourceID: listingResourceID, nftType: nftType, nftID: nftID, ftVaultType: salePaymentVaultType, price: listingPrice)
			return listingResourceID
		}
		
		// removeListing
		// Remove a Listing that has not yet been purchased from the collection and destroy it.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun removeListing(listingResourceID: UInt64, address: Address){ 
			let listing <- self.listings.remove(key: listingResourceID) ?? panic("missing Listing")
			if DriverzNFTStorefront.ListedDriverz[address] != nil && (DriverzNFTStorefront.ListedDriverz[address]!).contains(listingResourceID){ 
				DriverzNFTStorefront.removeListing(address: address, storefrontID: listingResourceID)
			}
			// This will emit a ListingCompleted event.
			destroy listing
		}
		
		// getListingIDs
		// Returns an array of the Listing resource IDs that are in the collection
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun getListingIDs(): [UInt64]{ 
			return self.listings.keys
		}
		
		// borrowSaleItem
		// Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowListing(listingResourceID: UInt64): &Listing?{ 
			if self.listings[listingResourceID] != nil{ 
				return &self.listings[listingResourceID] as &Listing?
			} else{ 
				return nil
			}
		}
		
		// cleanup
		// Remove an listing *if* it has been purchased.
		// Anyone can call, but at present it only benefits the account owner to do so.
		// Kind purchasers can however call it if they like.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun cleanup(listingResourceID: UInt64){ 
			pre{ 
				self.listings[listingResourceID] != nil:
					"could not find listing with given id"
			}
			let listing <- self.listings.remove(key: listingResourceID)!
			assert(listing.getDetails().purchased == true, message: "listing is not purchased, only admin can remove")
			destroy listing
		}
		
		// destructor
		//
		// constructor
		//
		init(){ 
			self.listings <-{} 
			// Let event consumers know that this storefront exists
			emit StorefrontInitialized(storefrontResourceID: self.uuid)
		}
	}
	
	access(all)
	resource DriverzStorefrontAdmin{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun removeListing(address: Address, listingID: UInt64){ 
			DriverzNFTStorefront.removeListing(address: address, storefrontID: listingID)
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun removeAllListingsFromAddress(address: Address){ 
			DriverzNFTStorefront.ListedDriverz.remove(key: address)
		}
	}
	
	// createStorefront
	// Make creating a Storefront publicly accessible.
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun createStorefront(): @Storefront{ 
		return <-create Storefront()
	}
	
	init(){ 
		self.ListedDriverz ={} 
		self.StorefrontStoragePath = /storage/DriverzNFTStorefront
		self.StorefrontPublicPath = /public/DriverzNFTStorefront
		emit DriverzNFTStorefrontInitialized()
	}
}
