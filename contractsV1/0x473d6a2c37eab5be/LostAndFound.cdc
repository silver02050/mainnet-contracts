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

import FlowStorageFees from "../0xe467b9dd11fa00df/FlowStorageFees.cdc"

import FlowToken from "./../../standardsV1/FlowToken.cdc"

import NonFungibleToken from "./../../standardsV1/NonFungibleToken.cdc"

import MetadataViews from "./../../standardsV1/MetadataViews.cdc"

import FeeEstimator from "./FeeEstimator.cdc"

access(all)
contract LostAndFound{ 
	access(contract)
	let storageFees:{ UInt64: UFix64}
	
	access(all)
	let LostAndFoundPublicPath: PublicPath
	
	access(all)
	let LostAndFoundStoragePath: StoragePath
	
	access(all)
	let DepositorPublicPath: PublicPath
	
	access(all)
	let DepositorStoragePath: StoragePath
	
	access(all)
	event TicketDeposited(
		redeemer: Address,
		ticketID: UInt64,
		type: Type,
		memo: String?,
		name: String?,
		description: String?,
		thumbnail: String?
	)
	
	access(all)
	event TicketRedeemed(redeemer: Address, ticketID: UInt64, type: Type)
	
	access(all)
	event BinDestroyed(redeemer: Address, type: Type)
	
	access(all)
	event ShelfDestroyed(redeemer: Address)
	
	access(all)
	event DepositorCreated(uuid: UInt64)
	
	access(all)
	event DepositorBalanceLow(uuid: UInt64, threshold: UFix64, balance: UFix64)
	
	access(all)
	event DepositorTokensAdded(uuid: UInt64, tokens: UFix64, balance: UFix64)
	
	access(all)
	event DepositorTokensWithdrawn(uuid: UInt64, tokens: UFix64, balance: UFix64)
	
	// Placeholder receiver so that any resource can be supported, not just FT and NFT Receivers
	access(all)
	resource interface AnyResourceReceiver{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun deposit(_resource: @AnyResource)
	}
	
	access(all)
	resource DepositEstimate{ 
		access(all)
		var item: @AnyResource?
		
		access(all)
		let storageFee: UFix64
		
		init(item: @AnyResource, storageFee: UFix64){ 
			self.item <- item
			self.storageFee = storageFee
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun withdraw(): @AnyResource{ 
			let _resource <- self.item <- nil
			return <-_resource!
		}
	}
	
	// Tickets are the resource that hold items to be redeemed. They carry with them:
	// - item: The Resource which has been deposited to be withdrawn/redeemed
	// - memo: An optional message to attach to this ticket
	// - redeemer: The address which is allowed to withdraw the item from this ticket
	// - redeemed: Whether the ticket has been redeemed. This can only be set by the LostAndFound contract
	access(all)
	resource Ticket{ 
		// The item to be redeemed
		access(contract)
		var item: @AnyResource?
		
		// An optional message to attach to this item.
		access(all)
		let memo: String?
		
		// an optional Display view so that frontend's that borrow this ticket know how to show it
		access(all)
		let display: MetadataViews.Display?
		
		// The address that it allowed to withdraw the item fromt this ticket
		access(all)
		let redeemer: Address
		
		//The type of the resource (non-optional) so that bins can represent the true type of an item
		access(all)
		let type: Type
		
		// State maintained by LostAndFound
		access(all)
		var redeemed: Bool
		
		// flow token amount used to store this ticket is returned when the ticket is redeemed
		access(contract)
		let flowTokenRepayment: Capability<&FlowToken.Vault>?
		
		init(
			item: @AnyResource,
			memo: String?,
			display: MetadataViews.Display?,
			redeemer: Address,
			flowTokenRepayment: Capability<&FlowToken.Vault>?
		){ 
			self.type = item.getType()
			self.item <- item
			self.memo = memo
			self.display = display
			self.redeemer = redeemer
			self.redeemed = false
			self.flowTokenRepayment = flowTokenRepayment
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		view fun itemType(): Type{ 
			return self.type
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun checkItem(): Bool{ 
			return self.item != nil
		}
		
		// A function to get depositor address / flow Repayment address
		access(TMP_ENTITLEMENT_OWNER)
		fun getFlowRepaymentAddress(): Address?{ 
			return self.flowTokenRepayment?.address
		}
		
		// If this is an instance of NFT, return the id , otherwise return nil
		access(TMP_ENTITLEMENT_OWNER)
		fun getNonFungibleTokenID(): UInt64?{ 
			if self.type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()){ 
				let ref = (&self.item as &AnyResource?)!
				let nft = ref as! &{NonFungibleToken.NFT}
				return nft.id
			}
			return nil
		}
		
		// If this is an instance of FT, return the vault balance , otherwise return nil
		access(TMP_ENTITLEMENT_OWNER)
		fun getFungibleTokenBalance(): UFix64?{ 
			if self.type.isSubtype(of: Type<@{FungibleToken.Vault}>()){ 
				let ref = (&self.item as &AnyResource?)!
				let ft = ref as! &{FungibleToken.Vault}
				return ft.balance
			}
			return nil
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun withdraw(receiver: Capability){ 
			pre{ 
				receiver.address == self.redeemer:
					"receiver address and redeemer must match"
				!self.redeemed:
					"already redeemed"
			}
			var redeemableItem <- self.item <- nil
			let cap = receiver.borrow<&AnyResource>()!
			if cap.isInstance(Type<@{NonFungibleToken.Collection}>()){ 
				let target = receiver.borrow<&{NonFungibleToken.CollectionPublic}>()!
				let token <- redeemableItem as! @{NonFungibleToken.NFT}?
				self.redeemed = true
				emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: token.getType())
				target.deposit(token: <-token!)
				return
			} else if cap.isInstance(Type<@{FungibleToken.Vault}>()){ 
				let target = receiver.borrow<&{FungibleToken.Receiver}>()!
				let token <- redeemableItem as! @{FungibleToken.Vault}?
				self.redeemed = true
				emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: token.getType())
				target.deposit(from: <-token!)
				return
			} else if cap.isInstance(Type<@{LostAndFound.AnyResourceReceiver}>()){ 
				let target = receiver.borrow<&{LostAndFound.AnyResourceReceiver}>()!
				self.redeemed = true
				emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: redeemableItem.getType())
				target.deposit(_resource: <-redeemableItem)
				return
			} else{ 
				panic("cannot redeem resource to receiver")
			}
		}
		
		// we need to be able to take our item back for storage cost estimation
		// otherwise we can't actually deposit a ticket
		access(account)
		fun takeItem(): @AnyResource{ 
			self.redeemed = true
			var redeemableItem <- self.item <- nil
			return <-redeemableItem!
		}
	// destructon is only allowed if the ticket has been redeemed and the underlying item is a our dummy resource
	}
	
	// A Bin is a resource that gathers tickets whos item have the same type.
	// For instance, if two TopShot Moments are deposited to the same redeemer, only one bin
	// will be made which will contain both tickets to redeem each individual moment.
	access(all)
	resource Bin{ 
		access(contract)
		let tickets: @{UInt64: Ticket}
		
		access(contract)
		let type: Type
		
		access(all)
		let flowTokenRepayment: Capability<&{FungibleToken.Receiver}>?
		
		init(type: Type, flowTokenRepayment: Capability<&{FungibleToken.Receiver}>?){ 
			self.tickets <-{} 
			self.type = type
			self.flowTokenRepayment = flowTokenRepayment
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowTicket(id: UInt64): &LostAndFound.Ticket?{ 
			return &self.tickets[id] as &LostAndFound.Ticket?
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowAllTicketsByType(): [&LostAndFound.Ticket]{ 
			let tickets: [&LostAndFound.Ticket] = []
			let ids = self.tickets.keys
			for id in ids{ 
				tickets.append(self.borrowTicket(id: id)!)
			}
			return tickets
		}
		
		// deposit a ticket to this bin. The item type must match this bin's item type.
		// this function is not public because if it were there would be a way to get around
		// deposit fees
		access(contract)
		fun deposit(ticket: @LostAndFound.Ticket){ 
			pre{ 
				ticket.itemType() == self.type:
					"ticket and bin types must match"
				ticket.item != nil:
					"nil item not allowed"
			}
			let redeemer = ticket.redeemer
			let ticketID = ticket.uuid
			let memo = ticket.memo
			let name = ticket.display?.name
			let description = ticket.display?.description
			let thumbnail = ticket.display?.thumbnail?.uri()
			self.tickets[ticket.uuid] <-! ticket
			emit TicketDeposited(
				redeemer: redeemer,
				ticketID: ticketID,
				type: self.type,
				memo: memo,
				name: name,
				description: description,
				thumbnail: thumbnail
			)
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getTicketIDs(): [UInt64]{ 
			return self.tickets.keys
		}
		
		access(contract)
		fun withdrawTicket(ticketID: UInt64): @LostAndFound.Ticket{ 
			let ticket <- self.tickets.remove(key: ticketID)
			return <-ticket!
		}
	}
	
	// A shelf is our top-level organization resource.
	// It groups bins by type to help make discovery of the assets that a
	// redeeming address can claim.
	access(all)
	resource Shelf{ 
		access(self)
		let bins: @{String: Bin}
		
		access(self)
		let identifierToType:{ String: Type}
		
		access(self)
		let redeemer: Address
		
		access(contract)
		let flowTokenRepayment: Capability<&{FungibleToken.Receiver}>?
		
		init(redeemer: Address, flowTokenRepayment: Capability<&{FungibleToken.Receiver}>?){ 
			self.bins <-{} 
			self.identifierToType ={} 
			self.redeemer = redeemer
			self.flowTokenRepayment = flowTokenRepayment
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getOwner(): Address{ 
			return (self.owner!).address
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getRedeemableTypes(): [Type]{ 
			let types: [Type] = []
			for k in self.bins.keys{ 
				let t = self.identifierToType[k]!
				if t != nil{ 
					types.append(t)
				}
			}
			return types
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun hasType(type: Type): Bool{ 
			return self.bins[type.identifier] != nil
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowBin(type: Type): &LostAndFound.Bin?{ 
			return &self.bins[type.identifier] as &LostAndFound.Bin?
		}
		
		access(contract)
		fun ensureBin(
			type: Type,
			flowTokenRepayment: Capability<&{FungibleToken.Receiver}>?
		): &Bin{ 
			if !self.bins.containsKey(type.identifier){ 
				let storageBefore = LostAndFound.account.storage.used
				let bin <- create Bin(type: type, flowTokenRepayment: flowTokenRepayment)
				let uuid = bin.uuid
				let oldValue <- self.bins.insert(key: type.identifier, <-bin)
				LostAndFound.storageFees[uuid] = FeeEstimator.storageUsedToFlowAmount(LostAndFound.account.storage.used - storageBefore)
				self.identifierToType[type.identifier] = type
				destroy oldValue
			}
			return (&self.bins[type.identifier] as &LostAndFound.Bin?)!
		}
		
		access(contract)
		fun deposit(
			ticket: @LostAndFound.Ticket,
			flowTokenRepayment: Capability<&{FungibleToken.Receiver}>?
		){ 
			// is there a bin for this yet?
			let type = ticket.itemType()
			let bin = self.ensureBin(type: type, flowTokenRepayment: flowTokenRepayment)
			bin.deposit(ticket: <-ticket)
		}
		
		// Redeem all the tickets of a given type. This is just a convenience function
		// so that a redeemer doesn't have to coordinate redeeming each ticket individually
		// Only one of the three receiver options can be specified, and an optional maximum number of tickets
		// to redeem can be picked to prevent gas issues in case there are large numbers of tickets to be
		// redeemed at once.
		access(TMP_ENTITLEMENT_OWNER)
		fun redeemAll(type: Type, max: Int?, receiver: Capability){ 
			pre{ 
				receiver.address == self.redeemer:
					"receiver must match the redeemer of this shelf"
				self.bins.containsKey(type.identifier):
					"no bin for provided type"
			}
			var count = 0
			let borrowedBin = self.borrowBin(type: type)!
			for key in borrowedBin.getTicketIDs(){ 
				if max != nil && max == count{ 
					return
				}
				self.redeem(type: type, ticketID: key, receiver: receiver)
				count = count + 1
			}
		}
		
		// Redeem a specific ticket instead of all of a certain type.
		access(TMP_ENTITLEMENT_OWNER)
		fun redeem(type: Type, ticketID: UInt64, receiver: Capability){ 
			pre{ 
				receiver.address == self.redeemer:
					"receiver must match the redeemer of this shelf"
				self.bins.containsKey(type.identifier):
					"no bin for provided type"
			}
			let borrowedBin = self.borrowBin(type: type)!
			let ticket <- borrowedBin.withdrawTicket(ticketID: ticketID)
			let uuid = ticket.uuid
			ticket.withdraw(receiver: receiver)
			let refundCap = ticket.flowTokenRepayment
			if refundCap != nil && (refundCap!).check() && LostAndFound.storageFees[uuid] != nil{ 
				let refundProvider = LostAndFound.getFlowProvider()
				let repaymentVault <- refundProvider.withdraw(amount: LostAndFound.storageFees[uuid]!)
				((refundCap!).borrow()!).deposit(from: <-repaymentVault)
			}
			destroy ticket
			if borrowedBin.getTicketIDs().length == 0{ 
				let bin <- self.bins.remove(key: type.identifier)!
				let uuid = bin.uuid
				let flowTokenRepayment = bin.flowTokenRepayment
				emit BinDestroyed(redeemer: self.redeemer, type: type)
				let provider = LostAndFound.getFlowProvider()
				if flowTokenRepayment != nil && LostAndFound.storageFees[uuid] != nil{ 
					let vault <- provider.withdraw(amount: LostAndFound.storageFees[uuid]!)
					((flowTokenRepayment!).borrow()!).deposit(from: <-vault)
				}
				destroy bin
			}
		}
	}
	
	access(contract)
	fun getFlowProvider(): &FlowToken.Vault{ 
		return self.account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
	}
	
	// ShelfManager is a light-weight wrapper to get our shelves into storage.
	access(all)
	resource ShelfManager{ 
		access(self)
		let shelves: @{Address: Shelf}
		
		init(){ 
			self.shelves <-{} 
		}
		
		access(contract)
		fun ensureShelf(
			_ addr: Address,
			flowTokenRepayment: Capability<&FlowToken.Vault>?
		): &LostAndFound.Shelf{ 
			if !self.shelves.containsKey(addr){ 
				let storageBefore = LostAndFound.account.storage.used
				let shelf <- create Shelf(redeemer: addr, flowTokenRepayment: flowTokenRepayment)
				let uuid = shelf.uuid
				let oldValue <- self.shelves.insert(key: addr, <-shelf)
				LostAndFound.storageFees[uuid] = FeeEstimator.storageUsedToFlowAmount(LostAndFound.account.storage.used - storageBefore)
				destroy oldValue
			}
			return (&self.shelves[addr] as &LostAndFound.Shelf?)!
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun deposit(
			redeemer: Address,
			item: @AnyResource,
			memo: String?,
			display: MetadataViews.Display?,
			storagePayment: &{FungibleToken.Vault},
			flowTokenRepayment: Capability<&FlowToken.Vault>?
		): UInt64{ 
			pre{ 
				flowTokenRepayment == nil || (flowTokenRepayment!).check():
					"flowTokenRepayment is not valid"
				storagePayment.getType() == Type<@FlowToken.Vault>():
					"storage payment must be in flow tokens"
			}
			let receiver =
				LostAndFound.account.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)
					.borrow()!
			let storageBeforeShelf = LostAndFound.account.storage.used
			let shelf = self.ensureShelf(redeemer, flowTokenRepayment: flowTokenRepayment)
			if LostAndFound.account.storage.used != storageBeforeShelf
			&& LostAndFound.storageFees[shelf.uuid] != nil{ 
				receiver.deposit(
					from: <-storagePayment.withdraw(amount: LostAndFound.storageFees[shelf.uuid]!)
				)
			}
			let storageBeforeBin = LostAndFound.account.storage.used
			let bin = shelf.ensureBin(type: item.getType(), flowTokenRepayment: flowTokenRepayment)
			if LostAndFound.account.storage.used != storageBeforeBin{ 
				receiver.deposit(from: <-storagePayment.withdraw(amount: LostAndFound.storageFees[bin.uuid]!))
			}
			let storageBefore = LostAndFound.account.storage.used
			let ticket <-
				create Ticket(
					item: <-item,
					memo: memo,
					display: display,
					redeemer: redeemer,
					flowTokenRepayment: flowTokenRepayment
				)
			let uuid = ticket.uuid
			let flowTokenRepayment = ticket.flowTokenRepayment
			shelf.deposit(ticket: <-ticket, flowTokenRepayment: flowTokenRepayment)
			let storageUsedAfter = LostAndFound.account.storage.used
			let storageFee = FeeEstimator.storageUsedToFlowAmount(storageUsedAfter - storageBefore)
			LostAndFound.storageFees[uuid] = storageFee
			let storagePaymentVault <- storagePayment.withdraw(amount: storageFee)
			receiver.deposit(from: <-storagePaymentVault)
			return uuid
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun borrowShelf(redeemer: Address): &LostAndFound.Shelf?{ 
			return &self.shelves[redeemer] as &LostAndFound.Shelf?
		}
		
		// deleteShelf
		//
		// delete a shelf if it has no redeemable types
		access(TMP_ENTITLEMENT_OWNER)
		fun deleteShelf(_ addr: Address){ 
			let storageBefore = LostAndFound.account.storage.used
			assert(self.shelves.containsKey(addr), message: "shelf does not exist")
			let tmp <- self.shelves[addr] <- nil
			let shelf <-! tmp!
			assert(
				shelf.getRedeemableTypes().length! == 0,
				message: "shelf still has redeemable types"
			)
			let flowTokenRepayment = shelf.flowTokenRepayment
			let uuid = shelf.uuid
			if flowTokenRepayment != nil && (flowTokenRepayment!).check()
			&& LostAndFound.storageFees[uuid] != nil{ 
				let provider = LostAndFound.getFlowProvider()
				let vault <- provider.withdraw(amount: LostAndFound.storageFees[uuid]!)
				((flowTokenRepayment!).borrow()!).deposit(from: <-vault)
			}
			destroy shelf
			emit ShelfDestroyed(redeemer: addr)
		}
	}
	
	access(all)
	resource interface DepositorPublic{ 
		access(TMP_ENTITLEMENT_OWNER)
		fun balance(): UFix64
		
		access(TMP_ENTITLEMENT_OWNER)
		fun addFlowTokens(vault: @FlowToken.Vault)
	}
	
	access(all)
	resource Depositor: DepositorPublic{ 
		access(self)
		let flowTokenVault: @FlowToken.Vault
		
		access(all)
		let flowTokenRepayment: Capability<&FlowToken.Vault>
		
		access(self)
		var lowBalanceThreshold: UFix64?
		
		access(self)
		fun checkForLowBalance(): Bool{ 
			if self.lowBalanceThreshold != nil && self.balance() <= self.lowBalanceThreshold!{ 
				emit DepositorBalanceLow(uuid: self.uuid, threshold: self.lowBalanceThreshold!, balance: self.balance())
				return true
			}
			return false
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun setLowBalanceThreshold(threshold: UFix64?){ 
			self.lowBalanceThreshold = threshold
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun getLowBalanceThreshold(): UFix64?{ 
			return self.lowBalanceThreshold
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun deposit(redeemer: Address, item: @AnyResource, memo: String?, display: MetadataViews.Display?): UInt64{ 
			let receiver = LostAndFound.account.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver).borrow()!
			let storageBeforeShelf = LostAndFound.account.storage.used
			let shelfManager = LostAndFound.borrowShelfManager()
			let shelf = shelfManager.ensureShelf(redeemer, flowTokenRepayment: self.flowTokenRepayment)
			if LostAndFound.account.storage.used != storageBeforeShelf && LostAndFound.storageFees[shelf.uuid] != nil{ 
				receiver.deposit(from: <-self.withdrawTokens(amount: LostAndFound.storageFees[shelf.uuid]!))
			}
			let storageBeforeBin = LostAndFound.account.storage.used
			let bin = shelf.ensureBin(type: item.getType(), flowTokenRepayment: self.flowTokenRepayment)
			if storageBeforeBin != LostAndFound.account.storage.used{ 
				receiver.deposit(from: <-self.withdrawTokens(amount: LostAndFound.storageFees[bin.uuid]!))
			}
			let storageBefore = LostAndFound.account.storage.used
			let ticket <- create Ticket(item: <-item, memo: memo, display: display, redeemer: redeemer, flowTokenRepayment: self.flowTokenRepayment)
			let flowTokenRepayment = ticket.flowTokenRepayment
			let uuid = ticket.uuid
			(shelf!).deposit(ticket: <-ticket, flowTokenRepayment: flowTokenRepayment)
			let storageFee = FeeEstimator.storageUsedToFlowAmount(LostAndFound.account.storage.used - storageBefore)
			LostAndFound.storageFees[uuid] = storageFee
			let storagePaymentVault <- self.withdrawTokens(amount: storageFee)
			receiver.deposit(from: <-storagePaymentVault)
			return uuid
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun trySendResource(item: @AnyResource, cap: Capability, memo: String?, display: MetadataViews.Display?){ 
			if cap.check<&{NonFungibleToken.CollectionPublic}>(){ 
				let nft <- item as! @{NonFungibleToken.NFT}
				(cap.borrow<&{NonFungibleToken.CollectionPublic}>()!).deposit(token: <-nft)
			} else if cap.check<&{NonFungibleToken.Receiver}>(){ 
				let nft <- item as! @{NonFungibleToken.NFT}
				(cap.borrow<&{NonFungibleToken.Receiver}>()!).deposit(token: <-nft)
			} else if cap.check<&{FungibleToken.Receiver}>(){ 
				let vault <- item as! @{FungibleToken.Vault}
				(cap.borrow<&{FungibleToken.Receiver}>()!).deposit(from: <-vault)
			} else{ 
				self.deposit(redeemer: cap.address, item: <-item, memo: memo, display: display)
			}
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun withdrawTokens(amount: UFix64): @{FungibleToken.Vault}{ 
			let tokens <- self.flowTokenVault.withdraw(amount: amount)
			emit DepositorTokensWithdrawn(uuid: self.uuid, tokens: amount, balance: self.flowTokenVault.balance)
			self.checkForLowBalance()
			return <-tokens
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun addFlowTokens(vault: @FlowToken.Vault){ 
			let tokensAdded = vault.balance
			self.flowTokenVault.deposit(from: <-vault)
			emit DepositorTokensAdded(uuid: self.uuid, tokens: tokensAdded, balance: self.flowTokenVault.balance)
			self.checkForLowBalance()
		}
		
		access(TMP_ENTITLEMENT_OWNER)
		fun balance(): UFix64{ 
			return self.flowTokenVault.balance
		}
		
		init(_ flowTokenRepayment: Capability<&FlowToken.Vault>, lowBalanceThreshold: UFix64?){ 
			self.flowTokenRepayment = flowTokenRepayment
			let vault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
			self.flowTokenVault <- vault as! @FlowToken.Vault
			self.lowBalanceThreshold = lowBalanceThreshold
		}
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun createDepositor(
		_ flowTokenRepayment: Capability<&FlowToken.Vault>,
		lowBalanceThreshold: UFix64?
	): @Depositor{ 
		let depositor <-
			create Depositor(flowTokenRepayment, lowBalanceThreshold: lowBalanceThreshold)
		emit DepositorCreated(uuid: depositor.uuid)
		return <-depositor
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun borrowShelfManager(): &LostAndFound.ShelfManager{ 
		return self.account.capabilities.get<&LostAndFound.ShelfManager>(
			LostAndFound.LostAndFoundPublicPath
		).borrow()!
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun borrowAllTicketsByType(addr: Address, type: Type): [&LostAndFound.Ticket]{ 
		let manager = LostAndFound.borrowShelfManager()
		let shelf = manager.borrowShelf(redeemer: addr)
		if shelf == nil{ 
			return []
		}
		let bin = (shelf!).borrowBin(type: type)
		if bin == nil{ 
			return []
		}
		return (bin!).borrowAllTicketsByType()
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun borrowAllTickets(addr: Address): [&LostAndFound.Ticket]{ 
		let manager = LostAndFound.borrowShelfManager()
		let shelf = manager.borrowShelf(redeemer: addr)
		if shelf == nil{ 
			return []
		}
		let types = (shelf!).getRedeemableTypes()
		let allTickets = [] as [&LostAndFound.Ticket]
		for type in types{ 
			let tickets = LostAndFound.borrowAllTicketsByType(addr: addr, type: type)
			allTickets.appendAll(tickets)
		}
		return allTickets
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun redeemAll(type: Type, max: Int?, receiver: Capability){ 
		let manager = LostAndFound.borrowShelfManager()
		let shelf = manager.borrowShelf(redeemer: receiver.address)
		assert(shelf != nil, message: "shelf not found")
		(shelf!).redeemAll(type: type, max: max, receiver: receiver)
		let remainingTypes = (shelf!).getRedeemableTypes()
		if remainingTypes.length == 0{ 
			manager.deleteShelf(receiver.address)
		}
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun estimateDeposit(
		redeemer: Address,
		item: @AnyResource,
		memo: String?,
		display: MetadataViews.Display?
	): @DepositEstimate{ 
		// is there already a shelf?
		let manager = LostAndFound.borrowShelfManager()
		let shelf = manager.borrowShelf(redeemer: redeemer)
		var shelfFee = 0.0
		var binFee = 0.0
		if shelf == nil{ 
			shelfFee = 0.00001
			binFee = 0.00001
		} else{ 
			let bin = (shelf!).borrowBin(type: item.getType())
			if bin == nil{ 
				binFee = 0.00001
			}
		}
		let ftReceiver =
			LostAndFound.account.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)
		let ticket <-
			create LostAndFound.Ticket(
				item: <-item,
				memo: memo,
				display: display,
				redeemer: redeemer,
				flowTokenRepayment: ftReceiver
			)
		let tmpEstimate <- FeeEstimator.estimateDeposit(item: <-ticket)
		let tmpItem <- tmpEstimate.withdraw() as! @LostAndFound.Ticket
		let item <- tmpItem.takeItem()
		destroy tmpItem
		let estimate <-
			create DepositEstimate(
				item: <-item,
				storageFee: tmpEstimate.storageFee + shelfFee + binFee
			)
		destroy tmpEstimate
		return <-estimate
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun getRedeemableTypes(_ addr: Address): [Type]{ 
		let manager = LostAndFound.borrowShelfManager()
		let shelf = manager.borrowShelf(redeemer: addr)
		if shelf == nil{ 
			return []
		}
		return (shelf!).getRedeemableTypes()
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun deposit(
		redeemer: Address,
		item: @AnyResource,
		memo: String?,
		display: MetadataViews.Display?,
		storagePayment: &{FungibleToken.Vault},
		flowTokenRepayment: Capability<&FlowToken.Vault>?
	): UInt64{ 
		pre{ 
			flowTokenRepayment == nil || (flowTokenRepayment!).check():
				"flowTokenRepayment is not valid"
			storagePayment.getType() == Type<@FlowToken.Vault>():
				"storage payment must be in flow tokens"
		}
		let shelfManager = LostAndFound.borrowShelfManager()
		return shelfManager.deposit(
			redeemer: redeemer,
			item: <-item,
			memo: memo,
			display: display,
			storagePayment: storagePayment,
			flowTokenRepayment: flowTokenRepayment
		)
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun trySendResource(
		_resource: @AnyResource,
		cap: Capability,
		memo: String?,
		display: MetadataViews.Display?,
		storagePayment: &{FungibleToken.Vault},
		flowTokenRepayment: Capability<&FlowToken.Vault>
	){ 
		if cap.check<&{NonFungibleToken.CollectionPublic}>(){ 
			let nft <- _resource as! @{NonFungibleToken.NFT}
			(cap.borrow<&{NonFungibleToken.CollectionPublic}>()!).deposit(token: <-nft)
		} else if cap.check<&{NonFungibleToken.Receiver}>(){ 
			let nft <- _resource as! @{NonFungibleToken.NFT}
			(cap.borrow<&{NonFungibleToken.Receiver}>()!).deposit(token: <-nft)
		} else if cap.check<&{FungibleToken.Receiver}>(){ 
			let vault <- _resource as! @{FungibleToken.Vault}
			(cap.borrow<&{FungibleToken.Receiver}>()!).deposit(from: <-vault)
		} else{ 
			LostAndFound.deposit(redeemer: cap.address, item: <-_resource, memo: memo, display: display, storagePayment: storagePayment, flowTokenRepayment: flowTokenRepayment)
		}
	}
	
	access(TMP_ENTITLEMENT_OWNER)
	fun getAddress(): Address{ 
		return self.account.address
	}
	
	init(){ 
		self.storageFees ={} 
		self.LostAndFoundPublicPath = /public/lostAndFound
		self.LostAndFoundStoragePath = /storage/lostAndFound
		self.DepositorPublicPath = /public/lostAndFoundDepositor
		self.DepositorStoragePath = /storage/lostAndFoundDepositor
		let manager <- create ShelfManager()
		self.account.storage.save(<-manager, to: self.LostAndFoundStoragePath)
		var capability_1 =
			self.account.capabilities.storage.issue<&LostAndFound.ShelfManager>(
				self.LostAndFoundStoragePath
			)
		self.account.capabilities.publish(capability_1, at: self.LostAndFoundPublicPath)
	}
}
