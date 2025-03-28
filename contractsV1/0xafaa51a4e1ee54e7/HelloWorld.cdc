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

	// HelloWorld.cdc
//
// Welcome to Cadence! This is one of the simplest programs you can deploy on Flow.
//
// The HelloWorld contract contains a single string field and a public getter function.
//
// Follow the "Hello, World!" tutorial to learn more: https://docs.onflow.org/cadence/tutorial/02-hello-world/
access(all)
contract HelloWorld{ 
	// Declare a public field of type String.
	//
	// All fields must be initialized in the init() function.
	access(all)
	let greeting: String
	
	// The init() function is required if the contract contains any fields.
	init(){ 
		self.greeting = "Hello, World, 2023.05!"
	}
	
	// Public function that returns our friendly greeting!
	access(all)
	fun hello(): String{ 
		return self.greeting
	}
}
