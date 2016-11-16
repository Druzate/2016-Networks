// Neighbor Discovery Module
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#define BEACON_PERIOD 10000
#define TABLE_SIZE 255
#define NEIGHBORLIST_SIZE 255
#define COPY_TABLE_SIZE 3
#define TIMEOUT_MAX 10
#define NO_ROUTE_FOUND 999
#define FALSE 0
#define TRUE 1


module RoutingTableP{
	// uses interfaces
	uses interface Timer<TMilli> as beaconTimer;
	uses interface SimpleSend as RoutingSender;
	uses interface Receive as MainReceive;
	uses interface NeighborDiscovery;
	
	//provides interfaces
	provides interface RoutingTable;	
}
implementation {


	uint16_t counter = 0;
	routingTableEntry RoutingTableArr[TABLE_SIZE];


	pack sendPackage;
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
			uint32_t globi;



	command void RoutingTable.start(){		
		dbg( ROUTING_CHANNEL, "Initializing Routing\n");
		call NeighborDiscovery.start();
		
		call beaconTimer.startPeriodic(BEACON_PERIOD);
	}
	
	command void RoutingTable.dumpRoutingTable() {
		uint32_t i = 0;
		
		dbg( ROUTING_CHANNEL, "Printing Routing Table\n");
		dbg( ROUTING_CHANNEL, "Dest\tHop\tCount\n");
				
		for (i = 0; i<TABLE_SIZE; i++) {
			if (RoutingTableArr[i].id != 0) {
				dbg( ROUTING_CHANNEL, "%u\t\t%u\t%u\n", RoutingTableArr[i].id, RoutingTableArr[i].nextHop, RoutingTableArr[i].distance);
			}
		}
	}
	
	command uint16_t RoutingTable.returnNextHop(uint16_t finalDest){		
		uint32_t i = 0;	
			
		for (i = 0; i<TABLE_SIZE; i++) {
			if (RoutingTableArr[i].id == finalDest && RoutingTableArr[i].distance < NO_ROUTE_FOUND) {
				return RoutingTableArr[i].nextHop;
			}
		}
		
		return NO_ROUTE_FOUND;
	}
	
	uint32_t isInRoutingTable(uint16_t id) {	// returns Routing Table index, or NO_ROUTE_FOUND if not in table
		uint32_t i;
		for (i=0; i<counter; i++) {
			if (RoutingTableArr[i].id == id) {
				return i;
			}
		}
		return NO_ROUTE_FOUND;
	}
	

	void addToRoutingTable(uint16_t cid, uint16_t cdistance, uint16_t cnextHop){
		
		if (counter >= TABLE_SIZE) {
			dbg( ROUTING_CHANNEL, "Routing Table size exceeded! No more entries can be created.\n");
			// end. cannot add
		} else if (cid == 0 || cid == TOS_NODE_ID) {
			// just don't add it. this node doesn't exist, or is this node itself and doesn't need an entry
		} else {
			RoutingTableArr[counter].id = cid;
			RoutingTableArr[counter].distance = cdistance;	
			RoutingTableArr[counter].nextHop = cnextHop;	
			counter++;
		}
		return;
	}
	
	void removeRoute(uint16_t cid) {	// if a neighbor got removed, remove all their next hops as well
		uint32_t i;
		for (i=0; i<counter; i++) {
			if (RoutingTableArr[i].nextHop == cid) {
				RoutingTableArr[i].distance = NO_ROUTE_FOUND;
				RoutingTableArr[i].nextHop = 0;
			}
		}
	}
	
	
	void checkNeighbors(){
		uint16_t i = 0;
		uint16_t j = 0;
		void* tempNeighb;
		uint32_t tempTableSize = 0;
		
		// first, retrieve NeighborList
		
		struct aNeighbor TempNeighbors[NEIGHBORLIST_SIZE];
		tempNeighb = call NeighborDiscovery.getNeighborList();
		tempTableSize = call NeighborDiscovery.getNeighborListSize();
		// memcpy
		memcpy(TempNeighbors, tempNeighb, sizeof(aNeighbor)*NEIGHBORLIST_SIZE );
		
		for (j=0; j<tempTableSize; j++) {	// add to NeighborList
			if (isInRoutingTable(TempNeighbors[j].id) == NO_ROUTE_FOUND) {	// if neighbor was not found in list at all, even with NO_ROUTE_FOUND distance
				addToRoutingTable(TempNeighbors[j].id, 1, TempNeighbors[j].id);
			}
		}
		
		// next, update own RoutingList 
		// first, set all neighbors (those with dist 1) to 999
		for (i=0; i<counter; i++) {
			if (RoutingTableArr[i].distance == 1){	// if this member in Routing Table is a direct neighbor
				RoutingTableArr[i].distance = NO_ROUTE_FOUND;
			}
		}	
		// then, re-update neighbors that do exist
		for (i=0; i<counter; i++) {			// for each entry in Routing Table
				for (j=0; j<tempTableSize; j++) {	// check Neighbor Discovery list for it
					if (TempNeighbors[j].id == RoutingTableArr[i].id) {
						RoutingTableArr[i].nextHop = RoutingTableArr[i].id;
						RoutingTableArr[i].distance = 1;		// and if you find it, set distance to 1 - neighbor exists and is online
					}
				}
				
		}
		
	}
	
	void broadcastRoutingTable(){			// if still having problems, edit this to cater packets
		uint16_t i = 0;
		uint16_t j = 0;
		routingTableEntry tempRoutingTable[COPY_TABLE_SIZE];
		
		
		// BEFORE BROADCASTING
		// go through routing table and remove any routes that route through a nextHop that is now unreachable.
		for (i=0; i<counter; i++) {			// for each entry in Routing Table
			if (RoutingTableArr[i].distance == NO_ROUTE_FOUND) {	// if there is no route to this location
				removeRoute(RoutingTableArr[i].id);	
				// technically this will get called way more often than necessary (not just for removed neighbors)
				// but I've been having problems with routes getting updated so I'm keeping it in for safety
			}
		}
		
		
		
		// create and broadcast several messages with offset based on num entries
		
		for (i = 0; i < counter; i+= COPY_TABLE_SIZE) {
			//dbg (ROUTING_CHANNEL, "Current i = %u\n", i);
			// copies 5 entries into tempRoutingTable (or fills with 0s if doesn't exist)
			for (j = 0; j<COPY_TABLE_SIZE; j++) {
				if ((i+j) < counter) {
					tempRoutingTable[j].id = RoutingTableArr[i+j].id;
					tempRoutingTable[j].distance = RoutingTableArr[i+j].distance;
					tempRoutingTable[j].nextHop = RoutingTableArr[i+j].nextHop;
				} else {
					tempRoutingTable[j].id = 0;
					tempRoutingTable[j].distance = 0;
					tempRoutingTable[j].nextHop = 0;
				}
			}
			
			/*if (TOS_NODE_ID == 2 || TOS_NODE_ID == 4) {
				dbg( ROUTING_CHANNEL, "Advertising %u | d %u.\n", tempRoutingTable[0].id, tempRoutingTable[0].distance);
				dbg( ROUTING_CHANNEL, "Advertising %u | d %u.\n", tempRoutingTable[1].id, tempRoutingTable[1].distance);
				dbg( ROUTING_CHANNEL, "Advertising %u | d %u.\n", tempRoutingTable[2].id, tempRoutingTable[2].distance);
				dbg( ROUTING_CHANNEL, "Advertising %u | d %u.\n", tempRoutingTable[3].id, tempRoutingTable[3].distance);
				dbg( ROUTING_CHANNEL, "Advertising %u | d %u.\n", tempRoutingTable[4].id, tempRoutingTable[4].distance);

			}*/
		
			makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, 0, PROTOCOL_PING, (uint8_t*)tempRoutingTable, sizeof(routingTableEntry)*COPY_TABLE_SIZE);
			call RoutingSender.send(sendPackage, sendPackage.dest);
		
		}
	}
	

	event void beaconTimer.fired(){
		
			
		checkNeighbors();

		broadcastRoutingTable();
		
		
	}

	
	event message_t* MainReceive.receive(message_t* raw_msg, void* payload, uint8_t len){
		routingTableEntry tempRoutingTable[COPY_TABLE_SIZE];
		uint16_t i = 0;
		uint16_t j = 0;
		uint32_t RTindex = NO_ROUTE_FOUND;
		
		// recieve and copy the pack of COPY_TABLE_SIZE
		pack *msg = (pack *) payload;	
		memcpy(tempRoutingTable, msg->payload, sizeof(routingTableEntry)*COPY_TABLE_SIZE );
		
		
		//for each entry
		for (i = 0; i<COPY_TABLE_SIZE; i++) {
			RTindex = NO_ROUTE_FOUND;
			RTindex = isInRoutingTable(tempRoutingTable[i].id);	// check if it is already in routing table
			// this also returns the full routing table index for this node's entry, conveniently enough
			
			// if you are the extant nextHop, set distance to NO_ROUTE_FOUND - 1. no route this way (split horizon with poison reverse, makeshift)
			if (tempRoutingTable[i].nextHop == TOS_NODE_ID)
				tempRoutingTable[i].distance = NO_ROUTE_FOUND;
			
			
			// if the entry exists in the routing table
			if (RTindex < NO_ROUTE_FOUND) {
				// if the msg->src is the nextHop in your routing table for this node's entry 
				// (aka, check the routing table for the index of this node in it, compare the nextHop in routing table to msg->src)
				if (RoutingTableArr[RTindex].nextHop == msg->src) {
					// it is from your route. update regardless of distance; new distance is distance + 1
					if (tempRoutingTable[i].distance < NO_ROUTE_FOUND)
						RoutingTableArr[RTindex].distance = tempRoutingTable[i].distance + 1;
					else
						RoutingTableArr[RTindex].distance = NO_ROUTE_FOUND;	// or plain old 999
				// else if its distance+1 is less than your current distance
				} else if ( (tempRoutingTable[i].distance + 1) < RoutingTableArr[RTindex].distance) {
					// update your distance to the new distance + 1
					RoutingTableArr[RTindex].distance = tempRoutingTable[i].distance + 1;
					// update your nextHop to msg->src
					RoutingTableArr[RTindex].nextHop = msg->src;
				}
				// else just ignore it, no change required
				
				
			// else (if it doesn't exist in table, and isn't == TOS_NODE_ID || == 0)
			} else {
				// add it to your routing table
				addToRoutingTable(tempRoutingTable[i].id, tempRoutingTable[i].distance, msg->src);
				// next hop will, of course, be where you just got it from: msg->src
			}
	
	
		}
		
		
		//check neighbors again
		//checkNeighbors();
		
		// re-broadcast table
		//broadcastRoutingTable();
			
		
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

