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

import AFLNFT from "./AFLNFT.cdc"

import FiatToken from "./../../standardsV1/FiatToken.cdc"

access(all)
contract AFLPack{ 
	// event when a pack is bought
	access(all)
	event PackBought(templateId: UInt64, receiptAddress: Address?)
	
	// event when a pack is opened
	access(all)
	event PackOpened(nftId: UInt64, receiptAddress: Address?)
	
	// path for pack storage
	access(all)
	let PackStoragePath: StoragePath
	
	// path for pack public
	access(all)
	let PackPublicPath: PublicPath
	
	access(self)
	var ownerAddress: Address
	
	access(contract)
	let adminRef: Capability<&FiatToken.Vault>
	
	access(all)
	resource interface PackPublic{ 
		// making this function public to call by authorized users
		access(TMP_ENTITLEMENT_OWNER)
		fun openPack(packNFT: @AFLNFT.NFT, receiptAddress: Address): Void
	}
	
	access(all)
	resource Pack: PackPublic{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun updateOwnerAddress(owner: Address){ 
			pre{ 
				owner != nil:
					"owner must not be null"
			}
			AFLPack.ownerAddress = owner
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun buyPackFromAdmin(templateIds: [UInt64], packTemplateId: UInt64, receiptAddress: Address, price: UFix64){ 
			pre{ 
				price > 0.0:
					"Price should be greater than zero"
				templateIds.length > 0:
					"template id  must not be zero"
				receiptAddress != nil:
					"receipt address must not be null"
			}
			var allNftTemplateExists = true
			assert(templateIds.length <= 10, message: "templates limit exceeded")
			let nftTemplateIds: [AnyStruct] = []
			for tempID in templateIds{ 
				let nftTemplateData = AFLNFT.getTemplateById(templateId: tempID)
				if nftTemplateData == nil{ 
					allNftTemplateExists = false
					break
				}
				nftTemplateIds.append(tempID)
			}
			let originalPackTemplateData = AFLNFT.getTemplateById(templateId: packTemplateId)
			let originalPackTemplateImmutableData = originalPackTemplateData.getImmutableData()
			originalPackTemplateImmutableData["nftTemplates"] = nftTemplateIds
			assert(allNftTemplateExists, message: "Invalid NFTs")
			AFLNFT.createTemplate(maxSupply: 1, immutableData: originalPackTemplateImmutableData)
			let lastIssuedTemplateId = AFLNFT.getLatestTemplateId()
			AFLNFT.mintNFT(templateId: lastIssuedTemplateId, account: receiptAddress)
			(AFLNFT.allTemplates[packTemplateId]!).incrementIssuedSupply()
			emit PackBought(templateId: lastIssuedTemplateId, receiptAddress: receiptAddress)
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun buyPack(templateIds: [UInt64], packTemplateId: UInt64, receiptAddress: Address, price: UFix64, flowPayment: @{FungibleToken.Vault}){ 
			pre{ 
				price > 0.0:
					"Price should be greater than zero"
				templateIds.length > 0:
					"template id  must not be zero"
				flowPayment.balance == price:
					"Your vault does not have balance to buy NFT"
				receiptAddress != nil:
					"receipt address must not be null"
			}
			var allNftTemplateExists = true
			assert(templateIds.length <= 10, message: "templates limit exceeded")
			let nftTemplateIds: [AnyStruct] = []
			for tempID in templateIds{ 
				let nftTemplateData = AFLNFT.getTemplateById(templateId: tempID)
				if nftTemplateData == nil{ 
					allNftTemplateExists = false
					break
				}
				nftTemplateIds.append(tempID)
			}
			let originalPackTemplateData = AFLNFT.getTemplateById(templateId: packTemplateId)
			let originalPackTemplateImmutableData = originalPackTemplateData.getImmutableData()
			originalPackTemplateImmutableData["nftTemplates"] = nftTemplateIds
			assert(allNftTemplateExists, message: "Invalid NFTs")
			AFLNFT.createTemplate(maxSupply: 1, immutableData: originalPackTemplateImmutableData)
			let lastIssuedTemplateId = AFLNFT.getLatestTemplateId()
			let receiptAccount = getAccount(AFLPack.ownerAddress)
			let recipientCollection = receiptAccount.capabilities.get<&FiatToken.Vault>(FiatToken.VaultReceiverPubPath).borrow<&FiatToken.Vault>() ?? panic("Could not get receiver reference to the flow receiver")
			recipientCollection.deposit(from: <-flowPayment)
			AFLNFT.mintNFT(templateId: lastIssuedTemplateId, account: receiptAddress)
			(AFLNFT.allTemplates[packTemplateId]!).incrementIssuedSupply()
			emit PackBought(templateId: lastIssuedTemplateId, receiptAddress: receiptAddress)
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun openPack(packNFT: @AFLNFT.NFT, receiptAddress: Address){ 
			pre{ 
				packNFT != nil:
					"pack nft must not be null"
				receiptAddress != nil:
					"receipt address must not be null"
			}
			var packNFTData = AFLNFT.getNFTData(nftId: packNFT.id)
			var packTemplateData = AFLNFT.getTemplateById(templateId: packNFTData.templateId)
			let templateImmutableData = packTemplateData.getImmutableData()
			let allIds = templateImmutableData["nftTemplates"]! as! [AnyStruct]
			assert(allIds.length <= 10, message: "templates limit exceeded")
			for tempID in allIds{ 
				AFLNFT.mintNFT(templateId: tempID as! UInt64, account: receiptAddress)
			}
			emit PackOpened(nftId: packNFT.id, receiptAddress: self.owner?.address)
			destroy packNFT
		}
		
		init(){} 
	}
	
	init(){ 
		self.ownerAddress = (self.account!).address
		var adminRefCap =
			self.account.capabilities.get<&FiatToken.Vault>(FiatToken.VaultReceiverPubPath)
		self.adminRef = adminRefCap!
		self.PackStoragePath = /storage/AFLPack
		self.PackPublicPath = /public/AFLPack
		self.account.storage.save(<-create Pack(), to: self.PackStoragePath)
		var capability_1 =
			self.account.capabilities.storage.issue<&{PackPublic}>(self.PackStoragePath)
		self.account.capabilities.publish(capability_1, at: self.PackPublicPath)
	}
}
