#ifndef TCP_PACKET_H
#define TCP_PACKET_H


# include "protocol.h"
#include "channels.h"

#define DATA_FLAG 0
#define SYN_FLAG 1
#define SYN_ACK_FLAG 2
#define ACK_FLAG 3
#define FIN_FLAG 4
#define ACT_FIN_FLAG 5

// for reference: the payload of an "IP" packet is nx_uint8_t * PACKET_MAX_PAYLOAD_SIZE
// and PACKET_MAX_PAYLOAD_SIZE = 20.
// so, can store 20 uint8s worth of data.
// unfortunately, this is minus the header

enum{
	TCP_PACKET_HEADER_LENGTH = 8,
	TCP_PACKET_MAX_PAYLOAD_SIZE = 20 - TCP_PACKET_HEADER_LENGTH
};

// end result, payload can only be 12 uint8 in size

typedef nx_struct tcp_pack{
	nx_uint8_t dest_port;
	nx_uint8_t src_port;
	nx_uint8_t seq;		//Sequence Number	- which byte chunk is being sent
	// final payload needs sentinal
	// for all SYNACK it would be single random number
	nx_uint8_t ACK;		//ack - next byte expected (seq + 1)
	nx_uint8_t flags;
	nx_uint8_t advertised_window;	// buffer size
	nx_uint8_t payload[TCP_PACKET_MAX_PAYLOAD_SIZE];	// not in SYNACK
}tcp_pack;

/*
 * logPack
 * 	Sends packet information to the general channel.
 * @param:
 * 		pack *input = pack to be printed.
 */
/*
void logTCPPack(tcp_pack *input){
	dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
	input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
}
*/

#endif
