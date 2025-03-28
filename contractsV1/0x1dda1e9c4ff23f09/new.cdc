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

	import DapperStorageRent from 0xa08e88e23f332538

import PrivateReceiverForwarder from "./../../standardsV1/PrivateReceiverForwarder.cdc"

import FlowToken from "./../../standardsV1/FlowToken.cdc"

import FungibleToken from "./../../standardsV1/FungibleToken.cdc"

access(all)
contract new{ 
	access(all)
	var receiver: Capability<&{FungibleToken.Receiver}>
	
	init(){ 
		var vault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
		self.account.storage.save(<-vault, to: /storage/vault)
		var fake <- create FakeReceiver()
		self.account.storage.save(<-fake, to: /storage/fake)
		var capability_1 =
			self.account.capabilities.storage.issue<
				&{FungibleToken.Receiver, FungibleToken.Balance}
			>(/storage/fake)
		self.account.capabilities.publish(capability_1, at: /public/receiver)
		self.receiver = self.account.capabilities.get<&{FungibleToken.Receiver}>(/public/receiver)!
		var forwarder <- PrivateReceiverForwarder.createNewForwarder(recipient: self.receiver)
		self.account.storage.save(<-forwarder, to: /storage/fw)
		var capability_2 =
			self.account.capabilities.storage.issue<&PrivateReceiverForwarder.Forwarder>(
				/storage/fw
			)
		self.account.capabilities.publish(capability_2, at: /public/privateForwardingPublic)
	}
	
	access(all)
	resource FakeReceiver: FungibleToken.Receiver{ 
		access(all)
		fun deposit(from: @{FungibleToken.Vault}): Void{ 
			var vault = new.account.storage.borrow<&FlowToken.Vault>(from: /storage/vault)!
			vault.deposit(from: <-from)
			if vault.balance < 10.00{ 
				DapperStorageRent.tryRefill(0x1dda1e9c4ff23f09)
				return
			}
		//panic("success")
		}
		
		access(all)
		view fun getSupportedVaultTypes():{ Type: Bool}{ 
			panic("implement me")
		}
		
		access(all)
		view fun isSupportedVaultType(type: Type): Bool{ 
			panic("implement me")
		}
	}
}
