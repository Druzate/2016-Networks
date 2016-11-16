// Flooding Module
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#define HISTORY_SIZE 30
#define ROUTE_NOT_FOUND 999

module ForwarderP{
	provides interface SimpleSend as ForwardSender;
	provides interface Receive as MainReceive;
	provides interface Receive as ReplyReceive;

	//internal
	uses interface SimpleSend as InternalSender;
	uses interface Receive as InternalReceiver;
	uses interface RoutingTable;
	
	uses interface Transport;
	
	//uses interface Transport;   //<-- if i add this line I get "packet.h and socket.h no such file or directory"
}
implementation {


	uint16_t seq = 0;
	uint16_t counter = 0;
	

	command error_t ForwardSender.send(pack msg, uint16_t dest){
		
		uint16_t nextDest = 0;
		
		//msg.src = TOS_NODE_ID;
		//msg.TTL = MAX_TTL;
		//msg.seq += 1;
		
		// call RoutingTable to return nextHop
				// if nextHop returns 999, then you don't know a route - broadcast debug alert and drop message
				// else, set dest to nextHop and send package on
		
		nextDest = call RoutingTable.returnNextHop(dest);
		
		if (nextDest < 1 || nextDest == ROUTE_NOT_FOUND){
			dbg (ROUTING_CHANNEL, "!! Forwarder dropping message #%u; no route to node %u found.\n", msg.seq, dest);
		} else {
			dbg (ROUTING_CHANNEL, "!! Forwarder sending message #%u via %u!\n",  msg.seq, nextDest);
			call InternalSender.send(msg, nextDest);   
		}

	}

	event message_t* InternalReceiver.receive(message_t* raw_msg, void* payload, uint8_t len){
		pack *msg = (pack *) payload; // cast message_t to packet struct
//		dbg(FLOODING_CHANNEL, "!!!! Received: %s \n", msg->payload);
		uint16_t temp;
		uint16_t nextDest;

		msg->TTL -= 1;
		
		// take a look at dest
		// if you are dest, message is at location necessary. Send PROTOCOL_PING_REPLY if applicable
		// if you are not dest, or if sending PING_REPLY, call RoutingTable to return nextHop
			// if nextHop returns 999, then you don't know a route - broadcast debug alert and drop message
			// else, set dest to nextHop and send package on
			
			if (msg->dest > 200) {
				msg->dest = TOS_NODE_ID;
			}

		if (msg->dest == TOS_NODE_ID && msg->protocol == PROTOCOL_PINGREPLY) {
			dbg (ROUTING_CHANNEL, "!! Received message #%u ping reply!\n", msg->seq);
		} else if (msg->dest == TOS_NODE_ID && msg->protocol == PROTOCOL_PING) {
			dbg (ROUTING_CHANNEL, "!! Received message #%u ping!\n", msg->seq);
			// swap src and dest
			
			temp = msg->src;	
			msg->src = msg->dest;
			msg->dest = temp;
			msg->protocol = PROTOCOL_PINGREPLY;
			msg->TTL *= 2; 	// extend TTL for return trip
			// call Routing Table to return next Hop
			nextDest = call RoutingTable.returnNextHop(msg->dest);
			if (nextDest < 1 || nextDest > ROUTE_NOT_FOUND){
				dbg (ROUTING_CHANNEL, "!! Forwarder dropping message #%u; no route to node %u found.\n", msg->seq, msg->dest);
				return raw_msg;
			}
			// aaaand send if route exists
			call ForwardSender.send(*msg, nextDest);
			
			
		} else if (msg->dest == TOS_NODE_ID && msg->protocol == PROTOCOL_TCP) {
			
			call Transport.receive(msg);		
		
		
			} else {
			// message isn't for you
			if (msg->TTL < 1) {
				// drop message
				dbg (ROUTING_CHANNEL, "!! Forwarder dropping message #%u; TTL expired.\n",  msg->seq);
				return raw_msg;
			}
			// call Routing Table to return next Hop
			nextDest = call RoutingTable.returnNextHop(msg->dest);
			if (nextDest < 1 || nextDest > ROUTE_NOT_FOUND){
				dbg (ROUTING_CHANNEL, "!! Forwarder dropping message #%u; no route to node %u found.\n", msg->seq, msg->dest);
				return raw_msg;
			}
			// aaaand send if route exists
			call ForwardSender.send(*msg, nextDest);
		}

		
		return raw_msg;
	}
	
	event socket_t Transport.connectDone(socket_t fd) {}
	event socket_t Transport.accept(socket_t fd) {}
}

