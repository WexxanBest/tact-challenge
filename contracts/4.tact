import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; // contains address of NFT and duration (uint32) to hold
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

message NftWithdrawal {
	queryId: Int as uint64;
	nftAddress: Address;
}

contract Task4 with Deployable {
	seed: Int as uint128;
	assignedTime: Int as uint32 = 0;
	assigned: Bool = false;
	nftAddress: Address?;
	owner: Address?;
	duration: Int as uint32 = 0;


	init(seed: Int) {
		self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
	}

	receive(msg: OwnershipAssigned) {
		if(self.assigned){ // There is already NFT locked
			send(SendParameters{
				to: sender(),
				value: 0,
				mode: SendIgnoreErrors,
				body: Transfer{
					queryId: msg.queryId,         
					newOwner: msg.prevOwner, 
					responseDestination: myAddress(), 
					customPayload: null,
					forwardAmount: 0, 
					forwardPayload: emptySlice()
				}.toCell()
			});
		} else {
			self.assigned = true;
			self.assignedTime = now();

			self.nftAddress = sender();
			self.owner = msg.prevOwner;
			self.duration = msg.forwardPayload.loadUint(32);
			send(SendParameters{
				to: sender(),
				value: 0,
				mode: SendIgnoreErrors + SendRemainingBalance,
				body: Transfer{
					queryId: msg.queryId,         
					newOwner: myAddress(), 
					responseDestination: myAddress(), 
					customPayload: null,
					forwardAmount: 0, 
					forwardPayload: emptySlice()
				}.toCell()
			});
		}
	}

	receive(msg: NftWithdrawal) {
		require(self.owner != null, "There is no owner yet.");
		require(sender() == self.owner, "Invalid sender");
		if(self.time() != 0){
			self.reply("NFT is still locked".asComment());
		}else{
			send(SendParameters{
				to: msg.nftAddress,
				value: 0,
				mode: SendIgnoreErrors + SendRemainingBalance,
				body: Transfer{
					queryId: msg.queryId,         
					newOwner: self.owner!!, 
					responseDestination: myAddress(), 
					customPayload: null,
					forwardAmount: 0, 
					forwardPayload: emptySlice()
				}.toCell()
			});
		}
	}

	get fun time(): Int {
		let timePassed: Int = now() - self.assignedTime;
		if(self.duration > timePassed){
			return self.duration - timePassed;
		} else {
			return 0;
		}
	}

	get fun nft(): Address? {
		return self.nftAddress;
	}

	get fun owner(): Address? {
		return self.owner;
	}
}