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

	/* 
*
*  This is an example implementation of a Flow Non-Fungible Token.
*  This contract does not implement any sophisticated classification
*  system for its NFTs. It defines a simple NFT with minimal metadata.
*   
*/

//import NonFungibleToken from 0x631e88ae7f1d7c20 test
import NonFungibleToken from "./../../standardsV1/NonFungibleToken.cdc"

import ViewResolver from "../../standardsV1/ViewResolver.cdc"

import MetadataViews from "./../../standardsV1/MetadataViews.cdc"

access(all)
contract FlowMint: NonFungibleToken{ 
	access(all)
	var totalSupply: UInt64
	
	access(all)
	event ContractInitialized()
	
	access(all)
	event Withdraw(id: UInt64, from: Address?)
	
	access(all)
	event Deposit(id: UInt64, to: Address?)
	
	access(all)
	let CollectionStoragePath: StoragePath
	
	access(all)
	let CollectionPublicPath: PublicPath
	
	access(all)
	let MinterStoragePath: StoragePath
	
	access(all)
	struct FlowMintData{ 
		access(all)
		let id: UInt64
		
		access(all)
		let type: String
		
		access(all)
		let url: String
		
		init(_id: UInt64, _type: String, _url: String){ 
			self.id = _id
			self.type = _type
			self.url = _url
		}
	}
	
	access(all)
	resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver{ 
		access(all)
		let id: UInt64
		
		access(all)
		let type: String
		
		access(all)
		let url: String
		
		init(id: UInt64, type: String, url: String){ 
			self.id = id
			self.type = type
			self.url = url
		}
		
		access(all)
		view fun getViews(): [Type]{ 
			return [Type<FlowMintData>()]
		}
		
		access(all)
		fun resolveView(_ view: Type): AnyStruct?{ 
			switch view{ 
				case Type<FlowMintData>():
					return FlowMintData(_id: self.id, _type: self.type, _url: self.url)
			}
			return nil
		}
		
		access(all)
		fun createEmptyCollection(): @{NonFungibleToken.Collection}{ 
			return <-create Collection()
		}
	}
	
	access(all)
	resource interface FlowMintCollectionPublic{ 
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void
		
		access(all)
		view fun getIDs(): [UInt64]
		
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowFlowMint(id: UInt64): &FlowMint.NFT?{ 
			post{ 
				result == nil || result?.id == id:
					"Cannot borrow FlowMint reference: the ID of the returned reference is incorrect"
			}
		}
	}
	
	access(all)
	resource Collection: FlowMintCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.Collection, NonFungibleToken.CollectionPublic, ViewResolver.ResolverCollection{ 
		// dictionary of NFT conforming tokens
		// NFT is a resource type with an `UInt64` ID field
		access(all)
		var ownedNFTs: @{UInt64:{ NonFungibleToken.NFT}}
		
		init(){ 
			self.ownedNFTs <-{} 
		}
		
		// withdraw removes an NFT from the collection and moves it to the caller
		access(NonFungibleToken.Withdraw)
		fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT}{ 
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
			emit Withdraw(id: token.id, from: self.owner?.address)
			return <-token
		}
		
		// deposit takes an NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		access(all)
		fun deposit(token: @{NonFungibleToken.NFT}): Void{ 
			let token <- token as! @FlowMint.NFT
			let id: UInt64 = token.id
			// add the new token to the dictionary which removes the old one
			let oldToken <- self.ownedNFTs[id] <- token
			emit Deposit(id: id, to: self.owner?.address)
			destroy oldToken
		}
		
		// getIDs returns an array of the IDs that are in the collection
		access(all)
		view fun getIDs(): [UInt64]{ 
			return self.ownedNFTs.keys
		}
		
		// borrowNFT gets a reference to an NFT in the collection
		// so that the caller can read its metadata and call its methods
		access(all)
		view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?{ 
			return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowFlowMint(id: UInt64): &FlowMint.NFT?{ 
			if self.ownedNFTs[id] != nil{ 
				// Create an authorized reference to allow downcasting
				let ref = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
				return ref as! &FlowMint.NFT
			}
			return nil
		}
		
		access(all)
		view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}?{ 
			let nft = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
			let FlowMintNFT = nft as! &FlowMint.NFT
			return FlowMintNFT as &{ViewResolver.Resolver}
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
	}
	
	// public function that anyone can call to create a new empty collection
	access(all)
	fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection}{ 
		return <-create Collection()
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, type: String, url: String){ 
		// create a new NFT
		var newNFT <- create NFT(id: FlowMint.totalSupply, type: type, url: url)
		// deposit it in the recipient's account using their reference
		recipient.deposit(token: <-newNFT)
		FlowMint.totalSupply = FlowMint.totalSupply + UInt64(1)
	}
	
	init(){ 
		// Initialize the total supply
		self.totalSupply = 0
		// Set the named paths
		self.CollectionStoragePath = /storage/FlowMintCollection
		self.CollectionPublicPath = /public/FlowMintCollection
		self.MinterStoragePath = /storage/FlowMintMinter
		// Create a Collection resource and save it to storage
		let collection <- create Collection()
		self.account.storage.save(<-collection, to: self.CollectionStoragePath)
		// create a public capability for the collection
		var capability_1 = self.account.capabilities.storage.issue<&FlowMint.Collection>(self.CollectionStoragePath)
		self.account.capabilities.publish(capability_1, at: self.CollectionPublicPath)
		emit ContractInitialized()
	}
}
