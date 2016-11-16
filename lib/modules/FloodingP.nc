// Flooding Module
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#define HISTORY_SIZE 30

module FloodingP{
	provides interface SimpleSend as FloodSender;
	provides interface Receive as MainReceive;
	provides interface Receive as ReplyReceive;

	//internal
	uses interface SimpleSend as InternalSender;
	uses interface Receive as InternalReceiver;
}
implementation {

	typedef struct histentry{
		uint16_t src;
		uint16_t seq;
	};

	uint16_t seq = 0;
	uint16_t counter = 0;
	struct histentry History[HISTORY_SIZE];

	bool isInHistory(uint16_t theSrc, uint16_t theSeq){
		uint32_t i;
		for (i = 0; i < HISTORY_SIZE; i++) {
			if (theSrc == History[i].src && theSeq == History[i].seq) {
//				dbg(FLOODING_CHANNEL, "!!!! Found in History: src%u seq%u\n", theSrc, theSeq);
				return TRUE;
			}
		}
		return FALSE;
	}

	void addToHistory(uint16_t theSrc, uint16_t theSeq) {
		if (counter < HISTORY_SIZE) { // if storage limit wasn't reached yet
			// add to end of currently extant list
			History[counter].src = theSrc;
			History[counter].seq = theSeq;
			counter++;
		} else {
			uint32_t i;
			// shift all history over, erasing oldest
			for (i = 0; i<(HISTORY_SIZE-1); i++) {
				History[i].src = History[i+1].src;
				History[i].seq = History[i+1].seq;
			}
			// add to end of list
			History[HISTORY_SIZE].src = theSrc;
			History[HISTORY_SIZE].seq = theSeq;
		}
//		dbg(FLOODING_CHANNEL, "!!!! Added to History: src%u seq%u\n", theSrc, theSeq);
		return;
	}

	command error_t FloodSender.send(pack msg, uint16_t dest){
		msg.src = TOS_NODE_ID;
		msg.TTL = MAX_TTL;

		msg.seq = seq++;
//		dbg(FLOODING_CHANNEL, "!!!! Flooding Network: %s\n", msg.payload);
		call InternalSender.send(msg, AM_BROADCAST_ADDR);
	}

	event message_t* InternalReceiver.receive(message_t* raw_msg, void* payload, uint8_t len){
		pack *msg = (pack *) payload; // cast message_t to packet struct
//		dbg(FLOODING_CHANNEL, "!!!! Received: %s \n", msg->payload);

		
		// if we have seen it before
		if (isInHistory(msg->src,msg->seq)) {
			return raw_msg;
		}		
		
		addToHistory(msg->src, msg->seq);
	
		

		// if neither of the above
			
		// if final destination
		if (msg->dest == TOS_NODE_ID) { // check own ID
			if (msg->protocol == PROTOCOL_PING) {	// if not a ping reply
				// swap src and dest
				uint16_t temp = msg->src;
				msg->src = msg->dest;
				msg->dest = temp;
				msg->protocol = PROTOCOL_PINGREPLY;

				dbg(FLOODING_CHANNEL, "!!!! Sending Ping Response to: %u \n", msg->dest);
				//RESPOND 
				call FloodSender.send(*msg, msg->dest);
				return signal MainReceive.receive(raw_msg, payload, len);
			} else {
				// this is a ping reply, can end
				dbg(FLOODING_CHANNEL, "!!!! Recieved final response from: %u \n", msg->src);
			}
		} else { 
			// decrement TTL
			msg->TTL--;
			
			// if TTL expired
			if (msg->TTL == 0) {		
//				dbg(FLOODING_CHANNEL, "!!!! TTL Expired: %s \n", msg->payload);
				return raw_msg;		
			}
			
			// pass on? call Sender
			call InternalSender.send(*msg, AM_BROADCAST_ADDR);
//			dbg(FLOODING_CHANNEL, "!!!! Decrementing TTL and Re-Flooding: %s \n", msg->payload);
		} 

		
		return raw_msg;
	}
}

