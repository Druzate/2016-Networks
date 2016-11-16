// Neighbor Discovery Module
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCPpacket.h"
#include <time.h>
#include <stdlib.h>
#define FALSE 0
#define TRUE 1
#define SOCKET_POOL_SIZE 30		// don't exceed 2^8

#define BEACON_PERIOD 70000		// potentially, timeout


module TransportP{
	// uses interfaces
	uses interface Timer<TMilli> as beaconTimer;
	uses interface SimpleSend as TransportSender;
	//uses interface Receive as MainReceive;
	uses interface Forwarder;
	
	uses interface Pool<socket_t> as pool;
	//uses interface Pool<socket_addr_t> as addresspool;
	
	uses interface Hashmap<socket_t*> as hashmap;
	// hash table list of connections
		// add connections on SYN
	
	
	//provides interfaces
	provides interface Transport;	
}
implementation {
		
	
	
	
		event void beaconTimer.fired(){
			
			// connection timeout
			
			// go through hash keys
			// for each hash entry
				// if ESTABLISHED, continue;
				// if CONN_SYN_SENT, resend SYN
				// if CONN_SYN_RCVD, resend SYN_ACK <-- actually, is this necessary? eventually you'd get another request if it was needed
				// if 
				// if [insert teardown stuff here]
			
			
		}
	
	
		command socket_t* Transport.socket() {	// Get a socket if there is one available.
			socket_t * sockPoint = call pool.get();
			
			// initialize values
			sockPoint->seq = 0;
			sockPoint->conn_state = CONN_CLOSED;
			sockPoint->advertised_window = 0;
			sockPoint->recvBufferCounter = 0;
			sockPoint->sendBufferCounter = 0;
			sockPoint->isServer = FALSE;
			dbg (TRANSPORT_CHANNEL, "Issuing socket.\n");
			
			return sockPoint;
		}

		command error_t Transport.bind(socket_t fd, socket_addr_t *addr) {	// binds src address to socket
			uint32_t myKey;
			fd.src_addr.location = addr->location;
			fd.src_addr.port = addr->port;
			
			// change isServer value
			fd.isServer = TRUE;
			fd.conn_state = CONN_LISTEN;	// begin to listen
			
			myKey = call Transport.getKey(SERVER_SOCKET, SERVER_SENTINEL, SERVER_SENTINEL);
			
			// insert into hashmap
			call hashmap.insert(myKey, &fd);
			dbg (TRANSPORT_CHANNEL, "Binding socket with key %u.\n", myKey);
		}
		
		
		command uint32_t Transport.getKey(uint8_t srcport, uint8_t destport, uint16_t destLoc) {
			uint32_t key = 0;
			// copy srcport into key
			key = srcport;
			// bitshift into front half
			key = key << 8;
			
			// XOR with destport 
			key = key^destport;
			// bitshift into front half
			key = key << 16;
			
			// XOR with destLoc for final value
			key = key^destLoc;
			
			
			return key;
		};
		
		
		
		command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
			/*
			* Write to the socket from a buffer. This data will eventually be
			* transmitted through your TCP implimentation.
			* Client side only for now.
			*/
			// in fd, you have sendBufferCounter. if that + bufflen is greater than buffer size, FAIL
			if (sizeof(nx_uint8_t)*BUFFER_SIZE < (bufflen+fd.sendBufferCounter)) {
				dbg (TRANSPORT_CHANNEL, "Not enough room in send buffer to write.\n");
				return 0;
			} else {	// else, memcpy and increment counter
				memcpy(fd.sendBuffer+fd.sendBufferCounter, buff, bufflen ); 
				// copy from buff to sendBuffer with sendBufferCounter offset; copy bufflen bytes
				fd.sendBufferCounter += bufflen;
				return bufflen;	// amount written
			}
			
		}
		
		//event message_t* MainReceive.receive(message_t* raw_msg, void* payload, uint8_t len){}
		
		command error_t Transport.receive(pack* package) {
			uint8_t srcPort, destPort, seqNum, ACKNum, flag, advertisedWin;
			uint8_t messageBuffer[TCP_PACKET_MAX_PAYLOAD_SIZE];
			uint32_t myKey;
			socket_t* mySocket = NULL;
			uint16_t bufflen = TCP_PACKET_MAX_PAYLOAD_SIZE; // TCP_PACKET_MAX_PAYLOAD_SIZE
			
			pack p;			
			tcp_pack* t;
			
			tcp_pack *msg = (tcp_pack*) package->payload;
			srcPort = msg->src_port;
			destPort = msg->dest_port;
			seqNum = msg->seq;
			ACKNum = msg->ACK;
			flag = msg->flags;
			
			myKey = call Transport.getKey(destPort, srcPort, package->src);
			
				// find socket with key
			if (call hashmap.contains(myKey)){
				mySocket = call hashmap.get(myKey);
			}
			
			
			if (flag != DATA_FLAG) {	// this is part of a handshake
				
				if (flag == SYN_FLAG) {	//if SYN you are server
					dbg (TRANSPORT_CHANNEL, "Received SYN.\n");
				
					if (mySocket != NULL) {
						//this is SYN resend, send SYN_ACK again
						dbg (TRANSPORT_CHANNEL, "Resending SYN_ACK.\n");
						
						// send SYN_ACK
						t = (tcp_pack*) p.payload;
						// create SYN_ACK in tcp
						t->dest_port = mySocket->dest_addr.port;
						t->src_port = mySocket->src_addr.port;
						srand(time(NULL));
						t->seq = rand();
						t->ACK = seqNum+1;
						t->flags = SYN_ACK_FLAG;
						t->advertised_window = BUFFER_SIZE;
						
						call Transport.makePack(&p, TOS_NODE_ID, mySocket->dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
						// payload manipulated directly
						
						// call send in Forwarder
						call TransportSender.send(p, mySocket->dest_addr.location);
						
						return;
					}
					
					// IF port is listening
					myKey = call Transport.getKey(destPort, SERVER_SENTINEL, SERVER_SENTINEL);
					if (call hashmap.contains(myKey)){
						mySocket = call hashmap.get(myKey);
						dbg (TRANSPORT_CHANNEL, "Fetched key %u.\n", myKey);
						dbg (TRANSPORT_CHANNEL, "Connection state is %u.\n", mySocket->conn_state);
					}
					
					if (mySocket->conn_state == CONN_LISTEN) {
						//fork new socket
						//change to SYN_RCVD
						// send SYN_ACK
						mySocket = call Transport.socket();
						mySocket->conn_state = CONN_SYN_RCVD;
						
						// set up addressing
						mySocket->dest_addr.location = package->src;
						mySocket->dest_addr.port = srcPort;
						mySocket->src_addr.location = TOS_NODE_ID;
						mySocket->src_addr.port = destPort;
						
						// add to hashmap
						myKey = call Transport.getKey(destPort, srcPort, package->src);
						call hashmap.insert(myKey, mySocket);
						
						dbg (TRANSPORT_CHANNEL, "Sending SYN ACK.\n");
						
						// send SYN_ACK
						t = (tcp_pack*) p.payload;
						// create SYN_ACK in tcp
						t->dest_port = mySocket->dest_addr.port;
						t->src_port = mySocket->src_addr.port;
						srand(time(NULL));
						t->seq = rand();
						t->ACK = seqNum+1;
						t->flags = SYN_ACK_FLAG;
						t->advertised_window = BUFFER_SIZE;
						
						call Transport.makePack(&p, TOS_NODE_ID, mySocket->dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
						// payload manipulated directly
						
						// call send in Forwarder
						call TransportSender.send(p, mySocket->dest_addr.location);
						
					}
					
					
						
				} else if  (flag == SYN_ACK_FLAG) {	// if SYN_ACK you are client	
					dbg (TRANSPORT_CHANNEL, "Received SYN ACK.\n");
					
					if (!(call hashmap.contains(myKey))){
						dbg (TRANSPORT_CHANNEL, "wtf where'd the key go\n");
						return;
					} 
					
					if (mySocket->conn_state = CONN_SYN_SENT) {
						
						// send ACK
						dbg (TRANSPORT_CHANNEL, "Sending ACK.\n");
						
						// send ACK
						t = (tcp_pack*) p.payload;
						// create SYN_ACK in tcp
						t->dest_port = mySocket->dest_addr.port;
						t->src_port = mySocket->src_addr.port;
						srand(time(NULL));
						t->seq = rand();
						t->ACK = seqNum+1;
						t->flags = ACK_FLAG;
						t->advertised_window = BUFFER_SIZE;
						
						call Transport.makePack(&p, TOS_NODE_ID, mySocket->dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
						// payload manipulated directly
						
						// call send in Forwarder
						call TransportSender.send(p, mySocket->dest_addr.location);
						
						// change to ESTABLISHED
						mySocket->conn_state = CONN_ESTABLISHED;
						// signal connectDone with your socket
						signal Transport.connectDone(*mySocket);
						
						
					} else if (mySocket->conn_state = CONN_ESTABLISHED) {	// server never got ACK, resend
						// send ACK
						dbg (TRANSPORT_CHANNEL, "Resending ACK.\n");
						
						// send ACK
						t = (tcp_pack*) p.payload;
						// create SYN_ACK in tcp
						t->dest_port = mySocket->dest_addr.port;
						t->src_port = mySocket->src_addr.port;
						srand(time(NULL));
						t->seq = rand();
						t->ACK = seqNum+1;
						t->flags = ACK_FLAG;
						t->advertised_window = BUFFER_SIZE;
						
						call Transport.makePack(&p, TOS_NODE_ID, mySocket->dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
						// payload manipulated directly
						
						// call send in Forwarder
						call TransportSender.send(p, mySocket->dest_addr.location);
						return;
					}
				
				} else if (flag == ACK_FLAG) {	// if ACK 
					dbg (TRANSPORT_CHANNEL, "Received ACK.\n");
					if (mySocket->conn_state = CONN_SYN_RCVD) {
						// if you are in SYN_RCVD, you are server, change to ESTABLISHED
						mySocket->conn_state = CONN_ESTABLISHED;
						// signal accept with your socket
						signal Transport.accept(*mySocket);
					}
				}
				
					
				// if FIN, if FIN_ACK
				
				
			} else {		// this is data
				dbg (TRANSPORT_CHANNEL, "Received data.\n");
				// copy into socket
				
				// bufflen = CHECK FOR SENTINEL VALUE
				// if does not exist, bufflen is full, else it is to that point
				
				if (sizeof(nx_uint8_t)*BUFFER_SIZE < (bufflen+mySocket->sendBufferCounter)) {
					dbg (TRANSPORT_CHANNEL, "Not enough room in recv buffer to write.\n");
					return 0;
				} else {	// else, memcpy and increment counter
					memcpy(mySocket->recvBuffer+mySocket->recvBufferCounter, msg->payload, bufflen ); 
					// copy from buff to recvBuffer with recvBufferCounter offset; copy bufflen bytes
					mySocket->recvBufferCounter += bufflen;
				}
				
			}

			return;
			
			/**
			* This will pass the packet so you can handle it internally. 
			* @param
			*    pack *package: the TCP packet that you are handling.
			* @Side Client/Server 
			* @return uint16_t - return SUCCESS if you are able to handle this
			*    packet or FAIL if there are errors.
			*/
		}
		
		command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {	// Reverse of write, roughly speaking.
			/**
			* Read from the socket and write this data to the buffer. This data
			* is obtained from your TCP implimentation.
			* Server side only, for now.
			*/
			uint16_t temp = 0;	// purely for reporting amount read
			
			// if nothing in socket buffer, return 0
			if (fd.recvBufferCounter == 0) {
				return 0;	// nothing to read
			}
			// if what is in socket buffer is less than bufflen, read that much.
			else if (fd.recvBufferCounter < bufflen) {
				memcpy(buff, fd.recvBuffer, fd.recvBufferCounter ); 
				
				temp = fd.recvBufferCounter;
				fd.recvBufferCounter = 0;	// aaaand decrement back to empty
				return temp;	// report amount read
			}
			else if (fd.recvBufferCounter >= bufflen) {
				memcpy(buff, fd.recvBuffer, bufflen );	// first, copy necessary to buffer
				// next, we have to move the socket's buffer over (ie, leave only what has not been read)
				// to do this, we memcpy from the recvBuffer with the offset of what has been read
				// to the beginning of recvBuffer (moving it)
				// how many bytes moved? the counter of bytes previously stored in buffer, minus what was just read.
				memcpy(fd.recvBuffer, fd.recvBuffer+bufflen, (fd.recvBufferCounter - bufflen) );
				// then we decrement counter by what was just read.
				fd.recvBufferCounter -= bufflen;
				// finally, we report the amount read.
				return bufflen;
			}
			
		}
		
		command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {
			pack p;			
			tcp_pack* t;
			socket_t* mySocket;
			uint32_t myKey;
			
			t = (tcp_pack*) p.payload;
			
			// create SYN in tcp
			t->dest_port = fd.dest_addr.port;
			t->src_port = fd.src_addr.port;
			srand(time(NULL));
			t->seq = rand();
			t->ACK = 0;
			t->flags = SYN_FLAG;
			t->advertised_window = BUFFER_SIZE;
			
			dbg (TRANSPORT_CHANNEL, "Issuing SYN to %u.\n", fd.dest_addr.location);
			
			call Transport.makePack(&p, TOS_NODE_ID, fd.dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
			// payload manipulated directly
			
			// call send in Forwarder
			call TransportSender.send(p, fd.dest_addr.location);
		
		
		
			// add to hashmap
						mySocket = call Transport.socket();
						mySocket->conn_state = CONN_SYN_SENT;
						
						// set up addressing
						mySocket->dest_addr.location = fd.dest_addr.location;
						mySocket->dest_addr.port = fd.dest_addr.port;	// server has this as client src
						mySocket->src_addr.location = TOS_NODE_ID;
						mySocket->src_addr.port = fd.src_addr.port;
					
						myKey = call Transport.getKey(fd.src_addr.port, fd.dest_addr.port, fd.dest_addr.location);
						call hashmap.insert(myKey, mySocket);
			
			
			
			/**
			* Attempts a connection to an address.
			* @param
			*    socket_t fd: file descriptor that is associated with the socket
			*       that you are attempting a connection with. 
			* @param
			*    socket_addr_t *addr: the destination address and port where
			*       you will atempt a connection.
			* @side Client
			* @return socket_t - returns SUCCESS if you are able to attempt
			*    a connection with the fd passed, else return FAIL.
			*/
		}
	
		
		command error_t Transport.close(socket_t fd) {	// Closes the socket.
			
			// if closing server
			
			// if closing client
			
			/*
			* @return socket_t - returns SUCCESS if you are able to attempt
			*    a closure with the fd passed, else return FAIL.
			*/
		}
		
		command error_t Transport.listen(socket_t fd) {	// Listen to the socket and wait for a connection.
			/*dbg (TRANSPORT_CHANNEL, "Beginning to listen.\n");
			if (fd.conn_state == CONN_CLOSED) {	// can listen only if no connection open/not already listening
				fd.conn_state = CONN_LISTEN;
				return SUCCESS;
			}
			return FAIL;*/
		}
		
	

	

	
	
	

	 command void Transport.makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
	
	
	
	
	
	

}

