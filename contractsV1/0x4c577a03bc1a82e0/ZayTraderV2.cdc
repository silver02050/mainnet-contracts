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

	//  ____   ____ _   _ __  __  ___  _____ ____  
// / ___| / ___| | | |  \/  |/ _ \| ____/ ___| 
// \___ \| |   | |_| | |\/| | | | |  _| \___ \ 
//  ___) | |___|  _  | |  | | |_| | |___ ___) |
// |____/ \____|_| |_|_|  |_|\___/|_____|____/ 
// 
// Made by amit @ zay.codes
// Forked from NFTStorefront as a starter with many changes
//
import FungibleToken from "./../../standardsV1/FungibleToken.cdc"

import NonFungibleToken from "./../../standardsV1/NonFungibleToken.cdc"

import FlowToken from "./../../standardsV1/FlowToken.cdc"

import ZayVerifierV2 from "./ZayVerifierV2.cdc"

access(all)
contract ZayTraderV2{ 
	// NFTStorefrontInitialized
	// This contract has been deployed.
	// Event consumers can expect future events from this contract.
	//
	access(all)
	event Initialized()
	
	// TradeCollectionInitialized
	// A trade resource has been created.
	// Event consumers can now expect events from this TradeCollection.
	//
	access(all)
	event TradeCollectionInitialized(tradeCollectionResourceID: UInt64)
	
	// TradeCollectionDestroyed
	// A TradeCollection has been destroyed.
	// Event consumers can now stop processing events from this TradeCollection.
	// Note that we do not specify an address.
	//
	access(all)
	event TradeCollectionDestroyed(tradeCollectionResourceID: UInt64)
	
	// TradeOfferAvailable
	// A TradeOffer has been created and added to a TradeCollection resource.
	// The Address values here are valid when the event is emitted, but
	// the state of the accounts they refer to may be changed outside of the
	// TradeCollection workflow, so be careful to check when using them.
	//
	access(all)
	event TradeOfferAvailable(
		tradeCollectionAddress: Address,
		tradeOfferResourceID: UInt64,
		tradeCollectionResourceID: UInt64,
		offeredFtAmounts: [
			UFix64
		],
		offeredFtTypes: [
			Type
		],
		offeredNftIDs: [
			UInt64
		],
		offeredNftTypes: [
			Type
		],
		requestedFtAmounts: [
			UFix64
		],
		requestedFtTypes: [
			Type
		],
		requestedNftIDs: [
			UInt64
		],
		requestedNftTypes: [
			Type
		],
		requestedAddress: Address?,
		expiration: UFix64
	)
	
	// TradeExecuted
	// The TradeOffer has been resolved. It has either been purchased, or removed and destroyed.
	//
	access(all)
	event TradeExecuted(
		tradeOfferResourceID: UInt64,
		tradeCollectionResourceID: UInt64,
		offeredFtAmounts: [
			UFix64
		],
		offeredFtTypes: [
			Type
		],
		offeredNftIDs: [
			UInt64
		],
		offeredNftTypes: [
			Type
		],
		requestedFtAmounts: [
			UFix64
		],
		requestedFtTypes: [
			Type
		],
		requestedNftIDs: [
			UInt64
		],
		requestedNftTypes: [
			Type
		]
	)
	
	access(all)
	event TradeCancelled(tradeOfferResourceID: UInt64, tradeCollectionResourceID: UInt64)
	
	// CollectionStoragePath
	// The location in storage that a TradeCollection resource should be located.
	//
	access(all)
	let CollectionStoragePath: StoragePath
	
	// CollectionPublicPath
	// The public location for a TradeCollection link.
	//
	access(all)
	let CollectionPublicPath: PublicPath
	
	// CollectionPrivatePath
	// The private location for a TradeCollection manager link
	//
	access(all)
	let CollectionPrivatePath: PrivatePath
	
	// AdminStoragePath
	// The location in storage for the Admin resource
	//
	access(all)
	let AdminStoragePath: StoragePath
	
	// feePerTrader
	// The amount of fee required for each trader in order to fulfill this trade
	//
	access(all)
	var feePerTrader: UFix64
	
	// feeReceiver
	// The admin Flow account that receives the fee
	//
	access(all)
	var feeReceiver: Capability<&{FungibleToken.Receiver}>
	
	// TradeAsset
	// The piece of a trade that is required in all trades.
	// The type is needed to validate that types match when
	// confirming a trade
	//
	access(all)
	struct interface TradeAsset{ 
		access(all)
		let type: Type
	}
	
	// NftTradeAsset
	// The field to identify a valid NFT within a trade
	// The nftID + the type provided by a `TradeAsset` combined
	// allow for verification of a valid NFT being transferred
	//
	access(all)
	struct interface NftTradeAsset{ 
		access(all)
		let nftID: UInt64
	}
	
	// FungibleTradeAsset
	// The field to identify a valid FungibleToken within a trade
	// The amount + the type provided by a `TradeAsset` combined
	// allow for verification of a valid amount of a token
	// is being transferred as part of this trade
	//
	access(all)
	struct interface FungibleTradeAsset{ 
		access(all)
		let amount: UFix64
	}
	
	// Offered NFT structs include a capability that allows for direct access to user's collections for their assets
	// These are needed in order to complete a trade without needing to transfer all assets to a new temporary
	// collection. The offered NFT and FT trade asset structs are also used by the requested trader in order to
	// provide the capabilities to complete the trade on both sides.
	// OfferedNftTradeAsset
	// Offered NFT as part of a trade
	//
	access(all)
	struct OfferedNftTradeAsset: TradeAsset, NftTradeAsset{ 
		access(all)
		let type: Type
		
		access(all)
		let nftID: UInt64
		
		access(contract)
		let nftCollectionAccess: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getReadable():{ String: AnyStruct}{ 
			return{ "nftID": self.nftID, "type": self.type}
		}
		
		init(type: Type, nftID: UInt64, nftCollectionAccess: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>){ 
			self.type = type
			self.nftID = nftID
			self.nftCollectionAccess = nftCollectionAccess
		}
	}
	
	// OfferedFungibleTradeAsset
	// Offered fungible token as part of a trade
	//
	access(all)
	struct OfferedFungibleTradeAsset: TradeAsset, FungibleTradeAsset{ 
		access(all)
		let type: Type
		
		access(all)
		let amount: UFix64
		
		access(contract)
		let fungibleTokenAccess: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getReadable():{ String: AnyStruct}{ 
			return{ "amount": self.amount, "type": self.type}
		}
		
		init(type: Type, amount: UFix64, fungibleTokenAccess: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>){ 
			self.type = type
			self.amount = amount
			self.fungibleTokenAccess = fungibleTokenAccess
		}
	}
	
	// RequestedNftTradeAsset
	// Requested assets - access to the capability that can view the assets
	// And a place to deposit the asset
	//
	access(all)
	struct RequestedNftTradeAsset: TradeAsset, NftTradeAsset{ 
		access(all)
		let type: Type
		
		access(all)
		let nftID: UInt64
		
		access(all)
		let offererReceiverCapability: Capability<&{NonFungibleToken.CollectionPublic}>
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getReadable():{ String: AnyStruct}{ 
			return{ "nftID": self.nftID, "type": self.type}
		}
		
		init(type: Type, nftID: UInt64, offererReceiverCapability: Capability<&{NonFungibleToken.CollectionPublic}>){ 
			self.type = type
			self.nftID = nftID
			self.offererReceiverCapability = offererReceiverCapability
		}
	}
	
	// RequestedFungibleTradeAsset
	// Requested Fungible token amount and where it should be deposited
	//
	access(all)
	struct RequestedFungibleTradeAsset: TradeAsset, FungibleTradeAsset{ 
		access(all)
		let amount: UFix64
		
		access(all)
		let type: Type
		
		access(all)
		let offererReceiverCapability: Capability<&{FungibleToken.Receiver}>
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getReadable():{ String: AnyStruct}{ 
			return{ "amount": self.amount, "type": self.type}
		}
		
		init(type: Type, amount: UFix64, offererReceiverCapability: Capability<&{FungibleToken.Receiver}>){ 
			self.type = type
			self.amount = amount
			self.offererReceiverCapability = offererReceiverCapability
		}
	}
	
	// TradeOfferDetails
	// A struct containing a TradeOffer's data.
	//
	access(all)
	struct TradeOfferDetails{ 
		// The Resource ID that this TradeOffer refers to.
		access(all)
		let tradeOfferResourceID: UInt64
		
		// The TradeCollection that the TradeOffer is stored in.
		access(all)
		let tradeCollectionID: UInt64
		
		// Whether this tradeoffer TradeOffer been executed or not.
		access(all)
		var executed: Bool
		
		// When this trade offer should no longer be eligible to be accepted
		access(all)
		let expiration: UFix64
		
		// The requested items the TradeOffer creator is expected to get back from the assets
		// they have offered
		access(all)
		let requestedNfts: [RequestedNftTradeAsset]
		
		access(all)
		let requestedFts: [RequestedFungibleTradeAsset]
		
		// The requested address is what address is expected to complete this trade.
		// This is verified by way of a time-bound signature that is expected to be provided
		// by an account, if this requestedAddress exists
		access(all)
		let requestedAddress: Address?
		
		// The items that the TradeOffer creator is expected to give up in this trade
		access(contract)
		let offeredNfts: [OfferedNftTradeAsset]
		
		access(contract)
		let offeredFts: [OfferedFungibleTradeAsset]
		
		// Fees are taken from this provided capability when the trade is being executed
		access(contract)
		let offerFeePayer: Capability<&FlowToken.Vault>
		
		access(contract)
		let offerFee: UFix64
		
		access(contract)
		fun setToExecuted(){ 
			self.executed = true
		}
		
		// -----------------
		// getReadableTradeOfferDetails
		// It is difficult to read the TradeOfferDetails as a struct, and faces
		// JS conversion problems. This converts it to an easier readable format
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun getReadableTradeOfferDetails():{ String: AnyStruct}{ 
			let map:{ String: AnyStruct} ={} 
			map["tradeCollectionID"] = self.tradeCollectionID
			map["tradeOfferResourceID"] = self.tradeOfferResourceID
			map["executed"] = self.executed
			map["expiration"] = self.expiration
			map["requestedAddress"] = self.requestedAddress
			let offeredNftArr: [{String: AnyStruct}] = []
			let offeredFtArr: [{String: AnyStruct}] = []
			let requestedNftArr: [{String: AnyStruct}] = []
			let requestedFtArr: [{String: AnyStruct}] = []
			var index = 0
			while index < self.offeredNfts.length{ 
				offeredNftArr.append(self.offeredNfts[index].getReadable())
				index = index + 1
			}
			index = 0
			while index < self.offeredFts.length{ 
				offeredFtArr.append(self.offeredFts[index].getReadable())
				index = index + 1
			}
			index = 0
			while index < self.requestedNfts.length{ 
				requestedNftArr.append(self.requestedNfts[index].getReadable())
				index = index + 1
			}
			index = 0
			while index < self.requestedFts.length{ 
				requestedFtArr.append(self.requestedFts[index].getReadable())
				index = index + 1
			}
			map["offeredNfts"] = offeredNftArr
			map["offeredFts"] = offeredFtArr
			map["requestedNfts"] = requestedNftArr
			map["requestedFts"] = requestedFtArr
			return map
		}
		
		// initializer
		//
		init(
			tradeOfferResourceID: UInt64,
			tradeCollectionID: UInt64,
			offeredNfts: [
				OfferedNftTradeAsset
			],
			offeredFts: [
				OfferedFungibleTradeAsset
			],
			offerFeePayer: Capability<&FlowToken.Vault>,
			offerFee: UFix64,
			requestedNfts: [
				RequestedNftTradeAsset
			],
			requestedFts: [
				RequestedFungibleTradeAsset
			],
			requestedAddress: Address?,
			expiration: UFix64
		){ 
			self.tradeOfferResourceID = tradeOfferResourceID
			self.tradeCollectionID = tradeCollectionID
			self.offeredNfts = offeredNfts
			self.offeredFts = offeredFts
			self.offerFeePayer = offerFeePayer
			self.offerFee = offerFee
			self.requestedNfts = requestedNfts
			self.requestedFts = requestedFts
			self.requestedAddress = requestedAddress
			self.expiration = expiration
			self.executed = false
		}
	}
	
	// TradeBundle
	// Bundles all assets from the result of executing a trade to a single resource
	// in order to return the resource back to the caller, where the resources
	// can then be moved to appropriate locations as desired.
	access(all)
	resource TradeBundle{ 
		access(all)
		var fungibleAssets: @[{FungibleToken.Vault}]
		
		access(all)
		var nftAssets: @[{NonFungibleToken.NFT}]
		
		access(TMP_ENTITLEMENT_OWNER)
		fun extractAllFungibleAssets(): @[{FungibleToken.Vault}]{ 
			var assets: @[{FungibleToken.Vault}] <- []
			self.fungibleAssets <-> assets
			return <-assets
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun extractAllNftAssets(): @[{NonFungibleToken.NFT}]{ 
			var assets: @[{NonFungibleToken.NFT}] <- []
			self.nftAssets <-> assets
			return <-assets
		}
		
		init(fungibleAssets: @[{FungibleToken.Vault}], nftAssets: @[{NonFungibleToken.NFT}]){ 
			self.fungibleAssets <- fungibleAssets
			self.nftAssets <- nftAssets
		}
	}
	
	// TradeOfferPublic
	// An interface providing a useful public interface to a TradeOffer.
	//
	access(all)
	resource interface TradeOfferPublic{ 
		// acceptTrade
		// Accept the TradeOffer, buying the offered items and providing
		// the requested assets in return.
		// Optionally, params for a signature may be provided. This is required
		// if the referenced trade has a specific address that is allowed to
		// fulfill the trade. Also required if a Schmoe is wanted to be used
		// to void the otherwise required trading fee
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun acceptTrade(
			tradeBundle: @ZayTraderV2.TradeBundle,
			feeCap: Capability<&FlowToken.Vault>,
			signingAddress: Address?,
			signedMessage: String?,
			keyIds: [
				Int
			],
			signatures: [
				String
			],
			signatureBlock: UInt64?
		): @ZayTraderV2.TradeBundle
		
		// getDetails
		// Receive details of this trade offer
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun getDetails(): TradeOfferDetails
	}
	
	// TradeOffer
	// A resource that allows a group of NFTs and FungibleTokens to be offered
	// in an exchange for another group of NFTs and FungibleTokens
	// 
	access(all)
	resource TradeOffer: TradeOfferPublic{ 
		// The details of the trade
		access(self)
		let details: TradeOfferDetails
		
		// getDetails
		// Get the details of the current state of the TradeOffer as a struct.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun getDetails(): TradeOfferDetails{ 
			return self.details
		}
		
		// executeTrade
		// Execute the trade, providing access to the requested resources
		// and receiving back all of the initially offered resources
		// emptyFtVaults is needed in order to fill in the resulting tradebundle.
		//
		access(self)
		fun executeTrade(tradeBundle: @TradeBundle): @TradeBundle{ 
			pre{ 
				self.details.executed == false:
					"Trade has already been executed"
				getCurrentBlock().timestamp < self.details.expiration:
					"Trade has expired, unable to execute trade"
			}
			// As the assets are pulled out of the TradeBundle to execute the trade, the following is also done:
			//  - Assert that all of the offered items are accessible to fit the trade parameters.
			//  - Assert that all of the requested items are present to fit the trade parameters
			// ------------------------------------------------------
			// Fields needed for emitting TradeExecuted event
			let offeredFtAmounts: [UFix64] = []
			let offeredFtTypes: [Type] = []
			let offeredNftIDs: [UInt64] = []
			let offeredNftTypes: [Type] = []
			let requestedFtAmounts: [UFix64] = []
			let requestedFtTypes: [Type] = []
			let requestedNftIDs: [UInt64] = []
			let requestedNftTypes: [Type] = []
			// ------------------------------------------------------
			// Create a TradeBundle by withdrawing from the `offerers` collections and vaults
			let offererNfts: @[{NonFungibleToken.NFT}] <- []
			let offererFts: @[{FungibleToken.Vault}] <- []
			// Loop through all previously offered NFT assets and withdraw -> deposit them to the newly provided receivers
			var index = 0
			while index < self.details.offeredNfts.length{ 
				let offeredNftAsset = self.details.offeredNfts[index]
				let provider = offeredNftAsset.nftCollectionAccess.borrow()
				assert(provider != nil, message: "Unable to borrow collection to withdraw offered NFT.")
				let nft <- (provider!).withdraw(withdrawID: offeredNftAsset.nftID)
				// Verify the originally offered NFT matches the currently withdrawn NFT
				assert(nft.isInstance(offeredNftAsset.type), message: "Wrong type received from offered collection")
				assert(nft.id == offeredNftAsset.nftID, message: "Wrong nft ID received from offered collection")
				offeredNftIDs.append(nft.id)
				offeredNftTypes.append(nft.getType())
				offererNfts.append(<-nft)
				// Continue to the next NFT
				index = index + 1
			}
			assert(self.details.offeredNfts.length == offererNfts.length, message: "Invalid amount of NFTs in resulting bundle.")
			// Loop through all previously offered Fungible assets and withdraw -> deposit them to the newly provided receivers
			index = 0
			while index < self.details.offeredFts.length{ 
				let offeredFtAsset = self.details.offeredFts[index]
				let provider = offeredFtAsset.fungibleTokenAccess.borrow()
				assert(provider != nil, message: "Unable to borrow collection to withdraw offered FT")
				assert((provider!).isInstance(offeredFtAsset.type), message: "Invalid FT type provided by offered capability")
				// If we attempt to withdraw more than is available, the following will fail.
				// We aren't validating the balance is high enough before withdrawing because
				// it is not needed (would fail anyways because of FungibleToken defaults), and
				// with flow tokens that assert can be inaccurate due to storage costs
				let withdrawnVault <- (provider!).withdraw(amount: offeredFtAsset.amount)
				offererFts.append(<-withdrawnVault)
				offeredFtAmounts.append(offeredFtAsset.amount)
				offeredFtTypes.append((provider!).getType())
				// Continue to the next FT vault
				index = index + 1
			}
			let finalTradeBundle <- create TradeBundle(fungibleAssets: <-offererFts, nftAssets: <-offererNfts)
			// ------------------------------------------------------   
			// Deposit the given trade assets to the `offerer` the provided nft assets and fungible assets
			// Provided offered NFTs are expected to map 1-1 to the requestedNftTradeAssets from the trade details
			let providedNfts: @[{NonFungibleToken.NFT}] <- tradeBundle.extractAllNftAssets()
			let providedFts: @[{FungibleToken.Vault}] <- tradeBundle.extractAllFungibleAssets()
			destroy tradeBundle
			// Loop through all provided NFT assets, verify their validity
			// and withdraw -> deposit them to the original offering party
			index = 0
			assert(self.details.requestedNfts.length == providedNfts.length, message: "Mismatch in number of nfts provided and requested.")
			while index < self.details.requestedNfts.length{ 
				let requestedNft = self.details.requestedNfts[index]
				let nft <- providedNfts.remove(at: 0)
				// Verify the provided NFT matches the requested one
				assert(nft.isInstance(requestedNft.type), message: "Provided NFT type does not match requested NFT type")
				assert(nft.id == requestedNft.nftID, message: "Provided NFT ID does not match requested NFT")
				let nftReceiver = requestedNft.offererReceiverCapability.borrow()
				assert(nftReceiver != nil, message: "Unable to borrow offer creator NFT receiver")
				requestedNftTypes.append(nft.getType())
				requestedNftIDs.append(nft.id)
				(				 // deposit the NFT
				 nftReceiver!).deposit(token: <-nft)
				// Continue to the next NFT
				index = index + 1
			}
			assert(providedNfts.length == 0, message: "Failed to use/transfer all provided nfts.")
			destroy providedNfts
			// Loop through all provided FT assets, and withdraw -> deposit them to the original offering party
			index = 0
			while index < self.details.requestedFts.length{ 
				let requestedFt = self.details.requestedFts[index]
				let ftVault <- providedFts.remove(at: 0)
				// Verify the provided fungible token matches the requested one
				assert(ftVault.isInstance(requestedFt.type), message: "Provided FT type does not match requested ft type")
				assert(ftVault.balance == requestedFt.amount, message: "Provided FT amount does not match requested amount")
				let ftReceiver = requestedFt.offererReceiverCapability.borrow()
				assert(ftReceiver != nil, message: "Unable to borrow offer creator FT receiver")
				requestedFtAmounts.append(ftVault.balance)
				requestedFtTypes.append(ftVault.getType())
				(				 // deposit the tokens
				 ftReceiver!).deposit(from: <-ftVault.withdraw(amount: ftVault.balance))
				// destroy the empty vault
				destroy ftVault
				// Continue to the next FT Vault
				index = index + 1
			}
			assert(providedFts.length == 0, message: "Failed to use/transfer all provided nfts.")
			destroy providedFts
			// ------------------------------------------------------
			self.details.setToExecuted()
			emit TradeExecuted(tradeOfferResourceID: self.uuid, tradeCollectionResourceID: self.details.tradeCollectionID, offeredFtAmounts: offeredFtAmounts, offeredFtTypes: offeredFtTypes, offeredNftIDs: offeredNftIDs, offeredNftTypes: offeredNftTypes, requestedFtAmounts: requestedFtAmounts, requestedFtTypes: requestedFtTypes, requestedNftIDs: requestedNftIDs, requestedNftTypes: requestedNftTypes)
			return <-finalTradeBundle
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun acceptTrade(tradeBundle: @TradeBundle, feeCap: Capability<&FlowToken.Vault>, signingAddress: Address?, signedMessage: String?, keyIds: [Int], signatures: [String], signatureBlock: UInt64?): @TradeBundle{ 
			// Validate that the given fee is valid
			assert(feeCap.borrow() != nil, message: "Invalid fee capability provided.")
			let fee <- (feeCap.borrow()!).withdraw(amount: ZayTraderV2.feePerTrader) as! @FlowToken.Vault
			let signatureRequired = self.details.requestedAddress != nil
			if self.details.requestedAddress != nil{ 
				// Validate that the requested account is valid if
				// a requested address was present as part of this trade offer
				assert(signingAddress! == self.details.requestedAddress!, message: "Requested trade account does not match provided account or expected signature not provided")
				assert(feeCap.address == self.details.requestedAddress!, message: "Requested trade account does not match provided account given for fee payment")
				let requestedCollection = getAccount(self.details.requestedAddress!).capabilities.get<&ZayTraderV2.TradeCollection>(ZayTraderV2.CollectionPublicPath).borrow()!
				assert(requestedCollection.getCurrentApprovingOfferID()! == self.uuid, message: "Expected approving trade offer ID does not match UUID of this trade offer")
			}
			// Check provided signature is valid for the 
			// signing account if it was provided
			var validSignature = false
			if signingAddress != nil && signedMessage != nil{ 
				let signatureTimestamp = ZayVerifierV2.verifySignature(acctAddress: signingAddress!, message: signedMessage!, keyIds: keyIds, signatures: signatures, signatureBlock: signatureBlock!, intent: "Execute_Schwap_Account_Ownership_Verification_", identifier: self.uuid.toString())
				assert(signatureTimestamp != nil, message: "Invalid signature provided.")
				let curTime = getCurrentBlock().timestamp
				let timePassedSinceSignature = curTime - signatureTimestamp!
				// If the signature happened less than 10 minutes ago, consider the signature valid
				assert(timePassedSinceSignature < UFix64(10 * 60), message: "Invalid signature provided")
				validSignature = true
			}
			assert(validSignature || !signatureRequired, message: "Proof of requested account ownership failed")
			var accountHasSchmoe = false
			// If the user provided a valid signature, also check if they have a schmoe
			// in a standard public schmoe collection
			if validSignature{ 
				/*accountHasSchmoe = ZayVerifierV2.checkOwnership(
									address: signingAddress!,
									collectionPath: SchmoesNFT.CollectionPublicPath,
									nftType: Type<@SchmoesNFT.NFT>()
								)*/
				
				accountHasSchmoe = false
			}
			let feeReceiver = ZayTraderV2.feeReceiver.borrow()!
			if accountHasSchmoe{ 
				// If the user has a schmoe, and provided a fee with balance, fail the call
				// because we do not want to take their fees
				assert(fee.balance == 0.0, message: "Fee provided without the need for fee due to schmoe ownership")
				destroy fee
			} else{ 
				// If the user doesn't have a schmoe, then ensure a fee was provided equal to
				// the current expected flat fee
				assert(fee.balance == ZayTraderV2.feePerTrader, message: "Invalid balance provided for free.")
				feeReceiver.deposit(from: <-fee.withdraw(amount: fee.balance))
				destroy fee
			}
			let offerFee <- (self.details.offerFeePayer.borrow()!).withdraw(amount: self.details.offerFee) as! @FlowToken.Vault
			feeReceiver.deposit(from: <-offerFee.withdraw(amount: offerFee.balance))
			destroy offerFee
			return <-self.executeTrade(tradeBundle: <-tradeBundle)
		}
		
		// destructor
		//
		// initializer
		//
		init(tradeCollectionID: UInt64, offeredNfts: [OfferedNftTradeAsset], offeredFts: [OfferedFungibleTradeAsset], offerFeePayer: Capability<&FlowToken.Vault>, offerFee: UFix64, requestedNfts: [RequestedNftTradeAsset], requestedFts: [RequestedFungibleTradeAsset], creatorAddress: Address, requestedAddress: Address?, expiration: UFix64){ 
			// Store the trade information and capabilities to access
			// the needed trade assets at execution time
			self.details = TradeOfferDetails(tradeOfferResourceID: self.uuid, tradeCollectionID: tradeCollectionID, offeredNfts: offeredNfts, offeredFts: offeredFts, offerFeePayer: offerFeePayer, offerFee: offerFee, requestedNfts: requestedNfts, requestedFts: requestedFts, requestedAddress: requestedAddress, expiration: expiration)
			// Verify that all of the provided capabilities and nfts/fts are formed validly
			// We cannot move the following verification steps into a function because
			// initializers cannot call member functions.
			// The verification that is done here is just to validate this is a valid trade
			// to create - the execution of the trade will repeat this verification to ensure
			// everything remains accessible and valid true at the time of execution
			let offeredFtAmounts: [UFix64] = []
			let offeredFtTypes: [Type] = []
			let offeredNftIDs: [UInt64] = []
			let offeredNftTypes: [Type] = []
			let requestedFtAmounts: [UFix64] = []
			let requestedFtTypes: [Type] = []
			let requestedNftIDs: [UInt64] = []
			let requestedNftTypes: [Type] = []
			// Must verify all offered and requested NFT collections exist as stated
			// and have the valid ID as specified in the TradeAsset
			// nftCollectionAccess fungibleTokenAccess
			for tradeAsset in self.details.offeredNfts{ 
				let provider = tradeAsset.nftCollectionAccess.borrow()
				assert(provider != nil, message: "Cannot borrow one of the provided offered NFTs")
				let nft = (provider!).borrowNFT(tradeAsset.nftID)
				assert(nft.isInstance(tradeAsset.type), message: "Token is not of specified type")
				assert(nft.id == tradeAsset.nftID, message: "Token does not have expected ID")
				offeredNftTypes.append(nft.getType())
				offeredNftIDs.append(nft.id)
			}
			// Verify all offered and requested FTs capabilities
			// exist and have valid balances attached to them
			for tradeAsset in self.details.offeredFts{ 
				let provider = tradeAsset.fungibleTokenAccess.borrow()
				assert(provider != nil, message: "Cannot borrow provided FT capability")
				let ft = provider!
				assert(ft.isInstance(tradeAsset.type), message: "Token is not of specified type")
				assert(ft.balance > tradeAsset.amount, message: "Not a large enough balance present for trade")
				offeredFtAmounts.append(ft.balance)
				offeredFtTypes.append(ft.getType())
			}
			for tradeAsset in self.details.requestedNfts{ 
				requestedNftTypes.append(tradeAsset.type)
				requestedNftIDs.append(tradeAsset.nftID)
			}
			for tradeAsset in self.details.requestedFts{ 
				requestedFtTypes.append(tradeAsset.type)
				requestedFtAmounts.append(tradeAsset.amount)
			}
			emit TradeOfferAvailable(tradeCollectionAddress: creatorAddress, tradeOfferResourceID: self.uuid, tradeCollectionResourceID: tradeCollectionID, offeredFtAmounts: offeredFtAmounts, offeredFtTypes: offeredFtTypes, offeredNftIDs: offeredNftIDs, offeredNftTypes: offeredNftTypes, requestedFtAmounts: requestedFtAmounts, requestedFtTypes: requestedFtTypes, requestedNftIDs: requestedNftIDs, requestedNftTypes: requestedNftTypes, requestedAddress: requestedAddress, expiration: expiration)
		}
	}
	
	// TradeCollectionManager
	// An interface for adding and removing TradeOffers within a TradeCollection,
	// intended for use by the TradeCollections's owner
	//
	access(all)
	resource interface TradeCollectionManager{ 
		// createListing
		// Allows the TradeCollection owner to create and insert TradeOffers.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun createTradeOffer(
			offeredNfts: [
				ZayTraderV2.OfferedNftTradeAsset
			],
			offeredFts: [
				ZayTraderV2.OfferedFungibleTradeAsset
			],
			offerFeePayer: Capability<&FlowToken.Vault>,
			requestedNfts: [
				ZayTraderV2.RequestedNftTradeAsset
			],
			requestedFts: [
				ZayTraderV2.RequestedFungibleTradeAsset
			],
			expiration: UFix64,
			requestedAddress: Address?
		): UInt64
		
		// removeListing
		// Allows the TradeCollection owner to remove any open trade listing, accepted or not.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun removeTradeOffer(tradeOfferResourceID: UInt64)
		
		// setCurrentApprovingOfferID
		// Allows for TradeCollection owner to set which trade it is accepting.
		// This is used for verification during trade approval to ensure an extra
		// layer of protection that the trade being accepted is being accepted by
		// the correctly requested account.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun setCurrentApprovingOfferID(tradeOfferResourceID: UInt64?)
	}
	
	// TradeCollectionPublic
	// An interface to allow viewing and borrowing of open trade offers, and
	// and execute trades given that the proper assets are provided in return
	//
	access(all)
	resource interface TradeCollectionPublic{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun getTradeOfferIDs(): [UInt64]
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowTradeOffer(tradeOfferResourceID: UInt64): &TradeOffer?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getCurrentApprovingOfferID(): UInt64?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun cleanup(tradeOfferResourceID: UInt64)
	}
	
	// TradeCollection
	// A resource that allows its owner to manage a list of open trade offers, and anyone to interact with them
	// in order to query their details and execute a trade if they have the requested assets
	//
	access(all)
	resource TradeCollection: TradeCollectionManager, TradeCollectionPublic{ 
		// The dictionary of Listing uuids to Listing resources.
		access(self)
		var tradeOffers: @{UInt64: TradeOffer}
		
		// When accepting an offer from someone elses trade collection,
		// this variable is set to which trade offer ID is expected to being accepted.
		access(self)
		var currentApprovingOfferID: UInt64?
		
		// insert
		// Create and publish a listing for a new trade offer.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun createTradeOffer(offeredNfts: [OfferedNftTradeAsset], offeredFts: [OfferedFungibleTradeAsset], offerFeePayer: Capability<&FlowToken.Vault>, requestedNfts: [RequestedNftTradeAsset], requestedFts: [RequestedFungibleTradeAsset], expiration: UFix64, requestedAddress: Address?): UInt64{ 
			/*let accountHasSchmoe = ZayVerifierV2.checkOwnership(
							address: offerFeePayer.address,
							collectionPath: SchmoesNFT.CollectionPublicPath,
							nftType: Type<@SchmoesNFT.NFT>()
						)*/
			
			let accountHasSchmoe = false
			var requiredFeeAmount = 0.0
			if !accountHasSchmoe{ 
				requiredFeeAmount = ZayTraderV2.feePerTrader
			}
			assert(offerFeePayer.address == self.owner?.address!, message: "Mismatch between account owner and fee payer.")
			assert(offerFeePayer.borrow()! != nil, message: "Flow vault to pay fee could not be borrowed.")
			let tradeOffer <- create TradeOffer(tradeCollectionID: self.uuid, offeredNfts: offeredNfts, offeredFts: offeredFts, offerFeePayer: offerFeePayer, offerFee: requiredFeeAmount, requestedNfts: requestedNfts, requestedFts: requestedFts, creatorAddress: self.owner?.address!, requestedAddress: requestedAddress, expiration: expiration)
			let tradeOfferResourceID = tradeOffer.uuid
			// Add the new offer to the dictionary.
			let oldOffer <- self.tradeOffers[tradeOfferResourceID] <- tradeOffer
			// Destroy the old offer, which won't exist because this is a new resource ID
			// being placed into the map
			destroy oldOffer
			return tradeOfferResourceID
		}
		
		// removeTradeOffer
		// Remove a TradeOffer that has not yet been executed from the collection and destroy it.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun removeTradeOffer(tradeOfferResourceID: UInt64){ 
			let tradeOfferResource <- self.tradeOffers.remove(key: tradeOfferResourceID) ?? panic("missing Listing")
			// This will emit a TradeCancelled event. 
			destroy tradeOfferResource
		}
		
		// setCurrentApprovingOfferID
		// Sets the ID of the TradeOFfer that is currently being accepted
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun setCurrentApprovingOfferID(tradeOfferResourceID: UInt64?){ 
			self.currentApprovingOfferID = tradeOfferResourceID
		}
		
		// getTradeOfferIDs
		// Returns an array of the TradeOffer resource IDs that are in the collection
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun getTradeOfferIDs(): [UInt64]{ 
			return self.tradeOffers.keys
		}
		
		// borrowTradeOffer
		// Returns a read-only view of the TradeOffer for the given tradeOfferResourceID if it is contained by this collection.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowTradeOffer(tradeOfferResourceID: UInt64): &TradeOffer?{ 
			if self.tradeOffers[tradeOfferResourceID] != nil{ 
				return &self.tradeOffers[tradeOfferResourceID] as &TradeOffer?
			} else{ 
				return nil
			}
		}
		
		// getCurrentApprovingOfferID
		// Returns the ID of the TradeOffer that is currently attempting to be accepted
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun getCurrentApprovingOfferID(): UInt64?{ 
			return self.currentApprovingOfferID
		}
		
		// cleanup
		// Remove an listing *if* it has been purchased.
		// Anyone can call, but at present it only benefits the account owner to do so.
		// Kind purchasers can however call it if they like.
		//
		access(TMP_ENTITLEMENT_OWNER)
		fun cleanup(tradeOfferResourceID: UInt64){ 
			pre{ 
				self.tradeOffers[tradeOfferResourceID] != nil:
					"could not find listing with given id"
			}
			let tradeOffer <- self.tradeOffers.remove(key: tradeOfferResourceID)!
			assert(tradeOffer.getDetails().executed == true, message: "trade offer has not been executed, only owner can cancel it")
			destroy tradeOffer
		}
		
		// destructor
		//
		// constructor
		//
		init(){ 
			self.tradeOffers <-{} 
			self.currentApprovingOfferID = nil
			// Let event consumers know that this storefront exists
			emit TradeCollectionInitialized(tradeCollectionResourceID: self.uuid)
		}
	}
	
	// Admin resource allowing for the contract administrator to make specific changes
	// The only intended control over the contract from an administrator is over the
	// fees
	access(all)
	resource Admin{ 
		// Update the capability we use to send fees to
		access(TMP_ENTITLEMENT_OWNER)
		fun updateFeeReceiver(cap: Capability<&FlowToken.Vault>){ 
			ZayTraderV2.feeReceiver = cap
		}
		
		// Update the amount received from fees
		access(TMP_ENTITLEMENT_OWNER)
		fun updateFeeAmount(amount: UFix64){ 
			ZayTraderV2.feePerTrader = amount
		}
	}
	
	// Public functions
	// createTradeCollection
	// Make creating a TradeCollection publicly accessible.
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun createTradeCollection(): @TradeCollection{ 
		return <-create TradeCollection()
	}
	
	// createTradeBundle
	// Make a TradeBundle for transferring many trade assets
	//
	access(TMP_ENTITLEMENT_OWNER)
	fun createTradeBundle(
		fungibleAssets: @[{
			FungibleToken.Vault}
		],
		nftAssets: @[{
			NonFungibleToken.NFT}
		]
	): @TradeBundle{ 
		return <-create TradeBundle(fungibleAssets: <-fungibleAssets, nftAssets: <-nftAssets)
	}
	
	init(){ 
		self.CollectionStoragePath = /storage/ZayTraderCollectionV2
		self.CollectionPublicPath = /public/ZayTraderCollectionV2
		self.CollectionPrivatePath = /private/ZayTraderCollectionV2
		// Fees set to 0 to start - will be updated by the admin resource
		self.feePerTrader = 0.0
		// Default to receiving fees on this central contract - this is meant
		// to be updated by an admin so that this contract can go keyless
		// when it is mature/ready to
		self.feeReceiver = self.account.capabilities.get<&FlowToken.Vault>(
				/public/flowTokenReceiver
			)
		self.AdminStoragePath = /storage/ZayTraderAdminV2
		self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
		emit Initialized()
	}
}
