// Neighbor Discovery Module
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../interfaces/aNeighbor.h"
#define BEACON_PERIOD 9000
#define NEIGHBORLIST_SIZE 255
#define TIMEOUT_MAX 10

module NeighborDiscoveryP{
	// uses interfaces
	uses interface Timer<TMilli> as beaconTimer;
	uses interface SimpleSend as NeighborSender;
	uses interface Receive as MainReceive;
	
	//provides interfaces
	provides interface NeighborDiscovery;	
}
implementation {


	pack sendPackage;
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
			uint32_t globi;


	uint16_t counter = 0;
	struct aNeighbor Neighbors[NEIGHBORLIST_SIZE];

	void updateNeighborList(uint16_t theSrc) {
		uint32_t i;
		
		// if it is already in the list, refresh timeout
		for (i = 0; i<NEIGHBORLIST_SIZE; i++) {
			if (Neighbors[i].id == theSrc) {
				Neighbors[i].TTL = TIMEOUT_MAX;
				return;
			}
		}
		
		// otherwise, add to end of currently extant list
			Neighbors[counter].id = theSrc;
			Neighbors[counter].TTL = TIMEOUT_MAX;
			counter++;
		//	dbg(NEIGHBOR_CHANNEL, "!!!! Added to NeighborList: src%u \n", theSrc);
		return;
	}
	
	void refreshNeighborList() {
		uint32_t i;
		// first, go through all neighbors and decrement TTL
		for (i = 0; i<NEIGHBORLIST_SIZE; i++) {
			if (Neighbors[i].TTL > 1) {
				Neighbors[i].TTL--;
			}
		}
		
		// NEXT, remove from list anyone who has hit TTL 1.
		
		for (i = 0; i<(NEIGHBORLIST_SIZE); i++) {
			if (Neighbors[i].TTL == 1) {
			uint32_t j;
			for (j = i; j<(NEIGHBORLIST_SIZE-1); j++) {
				Neighbors[j].id = Neighbors[j+1].id;
				Neighbors[j].TTL = Neighbors[j+1].TTL;
			}
			// change end of list
			Neighbors[NEIGHBORLIST_SIZE-1].id = 0;
			Neighbors[NEIGHBORLIST_SIZE-1].TTL = 0;
			//decrement counter
			counter--;
			}
			
			
		}
	}
	
	
	command aNeighbor * NeighborDiscovery.getNeighborList(){
		return Neighbors;
	}
	
	command uint16_t NeighborDiscovery.getNeighborListSize() {
		return counter;
	}
	


	command void NeighborDiscovery.start(){
		//one shot timer, include random element
		dbg( NEIGHBOR_CHANNEL, "Initializing Neighbor Discovery\n");
		call beaconTimer.startPeriodic(BEACON_PERIOD);
	}

	command void NeighborDiscovery.print(){
		dbg(NEIGHBOR_CHANNEL, "Printing neighbors of %u: \n", TOS_NODE_ID);
		for (globi=0; globi<NEIGHBORLIST_SIZE; globi++) {
			if (Neighbors[globi].id != 0) {
				dbg(NEIGHBOR_CHANNEL, "%u, with TTL: %u\n", Neighbors[globi].id, Neighbors[globi].TTL);
			}
		}
		
	}

	event void beaconTimer.fired(){
		//remove after debugging
		//dbg(NEIGHBOR_CHANNEL, "beaconTimer fired\n");

		// create and BROADCAST MESSAGE
		
		
		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, 0, PROTOCOL_PING, "test", PACKET_MAX_PAYLOAD_SIZE);
		
		
		
		//dbg(NEIGHBOR_CHANNEL, "!!!! Flooding Network: %s\n", sendPackage.payload);
		call NeighborSender.send(sendPackage, sendPackage.dest);

		// decrement time since last response
		// if any time has hit 0, remove from neighbor list
		refreshNeighborList();
	}

	event message_t* MainReceive.receive(message_t* raw_msg, void* payload, uint8_t len){
	
		pack *msg = (pack *) payload;
		// dbg(NEIGHBOR_CHANNEL, "!!!! Received! \n");
		
		// if the destination is AM_BROADCAST_ADDR, respond directly
		if (msg->dest == AM_BROADCAST_ADDR) {
			msg->dest = msg->src;
			msg->src = TOS_NODE_ID;
			msg->protocol = PROTOCOL_PINGREPLY;
			call NeighborSender.send(*msg, msg->dest);
		} else if (msg->dest == TOS_NODE_ID) {
			//dbg(NEIGHBOR_CHANNEL, "!!!! Received back from %u! \n", msg->src);
			updateNeighborList(msg->src);
		}
		
		return raw_msg;
	}

	
	
	
	
	 void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
	
	
	
	

}

