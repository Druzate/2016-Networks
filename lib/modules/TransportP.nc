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

#define BEACON_TIME 140000		// potentially, timeout


module TransportP{
	// uses interfaces
	uses interface Timer<TMilli> as beaconTimer;
	uses interface Timer<TMilli> as queueTimer;
	uses interface SimpleSend as TransportSender;
	//uses interface Receive as MainReceive;
	uses interface Forwarder;
	
	uses interface Pool<socket_t> as pool;
	
	uses interface Hashmap<socket_t*> as hashmap;
	// hash table list of connections
	
	uses interface Queue<pack> as toSendQueue;
	
	
	//provides interfaces
	provides interface Transport;	
}
implementation {
		
	
		event void queueTimer.fired(){
			// if queue exists
				// pull head
				// if last byte acked < head.tcp.ACK
					// resend
					// requeue
				// else if last byte acked > head.tcp.ACK && last byte written > head.tcp.ACK
					// resend
					// requeue
				// else
					// no need to resend
				
				// if queue exists && beacon is not set
					// set one time beacon again
		}
	
		event void beaconTimer.fired(){
			
			uint16_t hashSize;
			uint16_t i;
			uint32_t* hashKeys;
			socket_t* mySocket;
			uint8_t isWrap;
			
			pack p;			
			tcp_pack* t;
			
			hashKeys = call hashmap.getKeys();
			hashSize = call hashmap.size();
			
			
			// connection timeout
			
			// go through hash keys
			// for each hash entry
			for (i = 0; i<hashSize; i++) {
				
				if (call hashmap.contains(*(hashKeys+i))){
					mySocket = call hashmap.get(*(hashKeys+i));
										
					if (mySocket->conn_state == CONN_LISTEN) {
						// all good, connection is established or listening and need not send anything
						continue;
					} else if (mySocket->conn_state == CONN_ESTABLISHED){		// if ESTABLISHED, continue;
						// IF THERE IS DATA TO SEND AND WINDOW IS OPEN, SEND DATA
						
						
						if (mySocket->lastWritten - mySocket->lastSent != 0) {	// if there is something to send
							if (mySocket->lastSent - mySocket->lastAcked == 0) {	// change to "< mySocket->advertised_window" later
								//prepare TCP packet
								t = (tcp_pack*) p.payload;
								t->dest_port = mySocket->dest_addr.port;
								t->src_port = mySocket->src_addr.port;
								srand(time(NULL));
								t->seq = mySocket->seq;
								t->ACK = mySocket->seq;
								t->flags = DATA_FLAG;
								if (mySocket->lastRead <= mySocket->lastRcvd) {	// wrapping, can write from rcvd to end and from beginning to read
									t->advertised_window = (BUFFER_SIZE - mySocket->lastRcvd) + mySocket->lastRead;
								} else {	// non-wrapping, can write from rcvd to read
									t->advertised_window = mySocket->lastRead - mySocket->lastRcvd;
								}
								
								if ((mySocket->lastSent + TCP_PACKET_MAX_PAYLOAD_SIZE) > BUFFER_SIZE) {
									isWrap = TRUE;
									memcpy(t->payload, mySocket->sendBuffer+(mySocket->lastSent), (mySocket->lastSent + TCP_PACKET_MAX_PAYLOAD_SIZE) - BUFFER_SIZE);
									memcpy(t->payload, mySocket->sendBuffer, TCP_PACKET_MAX_PAYLOAD_SIZE - ((mySocket->lastSent + TCP_PACKET_MAX_PAYLOAD_SIZE) - BUFFER_SIZE));
									mySocket->lastSent = TCP_PACKET_MAX_PAYLOAD_SIZE - ((mySocket->lastSent + TCP_PACKET_MAX_PAYLOAD_SIZE) - BUFFER_SIZE);
								} else {
									isWrap = FALSE;
									memcpy(t->payload, mySocket->sendBuffer+(mySocket->lastSent), TCP_PACKET_MAX_PAYLOAD_SIZE);
									mySocket->lastSent += TCP_PACKET_MAX_PAYLOAD_SIZE;
								}
								
								
								
								call Transport.makePack(&p, TOS_NODE_ID, mySocket->dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
								// payload manipulated directly
						
								// stick this in queue
								call toSendQueue.enqueue(p);
						
								// call send in Forwarder
								call TransportSender.send(p, mySocket->dest_addr.location);
								
								mySocket->seq++;
								
								
							}
						}
						
						

						// if (written-sent > 0) - aka, there is data to be sent that has not been sent yet
						// and (sent - acked) < window - aka, window still has room
						// but start with (sent - acked) == 0
							// send a packet of data
							// insert into queue and start queue timer if not yet started
							// increment sent
						
						
						
						
						continue;
					} else if (mySocket->conn_state == CONN_SYN_SENT){	// if CONN_SYN_SENT, resend SYN
						t->dest_port = mySocket->dest_addr.port;
						t->src_port = mySocket->src_addr.port;
						t->seq = rand();
						t->ACK = 0;
						t->flags = SYN_FLAG;
						t->advertised_window = BUFFER_SIZE;
						
						dbg (TRANSPORT_CHANNEL, "Resending SYN to %u.\n", mySocket->dest_addr.location);
						
						call Transport.makePack(&p, TOS_NODE_ID, mySocket->dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
						
						call TransportSender.send(p, mySocket->dest_addr.location);
		
					} else if (mySocket->conn_state == CONN_SYN_RCVD){	// if CONN_SYN_RCVD, resend SYN_ACK 
						// actually, is this necessary? eventually you'd get another request if it was needed
						// codes it anyway
						t->dest_port = mySocket->dest_addr.port;
						t->src_port = mySocket->src_addr.port;
						t->seq = rand();
						t->ACK = 0;
						t->flags = SYN_ACK_FLAG;
						t->advertised_window = BUFFER_SIZE;
						
						dbg (TRANSPORT_CHANNEL, "Resending SYN ACK to %u.\n", mySocket->dest_addr.location);
						
						call Transport.makePack(&p, TOS_NODE_ID, mySocket->dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
						
						call TransportSender.send(p, mySocket->dest_addr.location);
						
					} else { // if [insert teardown stuff here]
						dbg (TRANSPORT_CHANNEL, "Teardown state, %u.\n", mySocket->conn_state);
						
					}
					
				} else {
					dbg (TRANSPORT_CHANNEL, "Some error in fetching key for timeout.\n");
				}
				
			
				
			}
			
			
		}
	
	
		command socket_t* Transport.socket() {	// Get a socket if there is one available.
			uint16_t i;
			socket_t * sockPoint = call pool.get();
			
			// initialize values
			sockPoint->seq = 0;
			sockPoint->conn_state = CONN_CLOSED;
			sockPoint->advertised_window = 0;
			
			sockPoint->recvBufferCounter = 0;
			sockPoint->sendBufferCounter = 0;
			
			sockPoint->lastRcvd = 0;
			sockPoint->lastRead = 0;
			sockPoint->lastExpected = 0;
			sockPoint->lastAcked = 0;
			sockPoint->lastSent = 0;
			sockPoint->lastWritten = 0;
			
			for (i = 0; i < BUFFER_SIZE; i++){
				sockPoint->recvBuffer[i] = 0;
				sockPoint->sendBuffer[i] = 0;
			}		
			
			sockPoint->isServer = FALSE;
			dbg (TRANSPORT_CHANNEL, "Issuing socket.\n");
			
			if (!call beaconTimer.isRunning())
				call beaconTimer.startPeriodic(BEACON_TIME);
			
			call queueTimer.startOneShot(BEACON_TIME+3000);
			
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
			
			uint16_t temp;
			socket_t* mySocket;
			uint32_t myKey;
			uint16_t writeLengthPossible;
			uint8_t isWrap;
			
			myKey = call Transport.getKey(fd.src_addr.port, fd.dest_addr.port, fd.dest_addr.location);
			
				// find socket with key
			if (call hashmap.contains(myKey)){
				mySocket = call hashmap.get(myKey);
			} else {
				dbg (TRANSPORT_CHANNEL, "Hash error in write.\n");
				return;
			}
			
			if (mySocket->lastWritten >= mySocket->lastAcked) {
				// can write from beginning to acked and from written to end
				isWrap = TRUE;
				writeLengthPossible = (BUFFER_SIZE - mySocket->lastWritten) + (mySocket->lastAcked);
			} else {	// if (mySocket->lastWritten < mySocket->lastAcked)
				// non-wrap, can write from written to acked
				isWrap = FALSE;
				writeLengthPossible = (mySocket->lastAcked - mySocket->lastWritten);
			}
			
			// in either case, you start writing from lastWritten (assuming there is room ofc)
			// if isWrap == true, then you memcopy BUFFER_SIZE-lastWritten of uint8s first, 
			// then, with that size as offset in buffer you are copying, you memcopy bufflen - that size, starting to write from 0.
			// else, you just memcopy the entire thing 
			// and ofc, you set the new bytes written.
			
			
			if (sizeof(nx_uint8_t)*BUFFER_SIZE < writeLengthPossible) {
				dbg (TRANSPORT_CHANNEL, "Not enough room in socket send buffer to write; write length possible is %u and app trying to write %u.\n", writeLengthPossible, bufflen);
				return 0;
			} else {	// else, memcpy and increment counter
			
				if (isWrap == TRUE) {
					temp = BUFFER_SIZE - mySocket->lastWritten;	//let's store here for simplicity
					// first, copy from lastWritten to end
					memcpy(mySocket->sendBuffer+mySocket->lastWritten, buff, temp*sizeof(uint8_t) );
					// next, copy from beginning to up to lastAcked for what remains. with offset in buff
					memcpy(mySocket->sendBuffer, buff+temp, (bufflen - temp)*sizeof(uint8_t) );
					
					// next, set new written position
					if (writeLengthPossible < (BUFFER_SIZE - mySocket->lastWritten)) {
						mySocket->lastWritten += bufflen;
					} else {
						mySocket->lastWritten = (bufflen - temp);
					}
					
				} else {
					// first, copy from lastWritten up to lastAcked
					memcpy(mySocket->sendBuffer+mySocket->lastWritten, buff, bufflen*sizeof(uint8_t) );
					
					// next, set new written position
					mySocket->lastWritten += bufflen;
				}
				
				
				dbg (TRANSPORT_CHANNEL, "Wrote to send buffer.\n");
				return bufflen;	// amount written
			}
			
		}
		
		
		command error_t Transport.receive(pack* package) {
			uint8_t srcPort, destPort, seqNum, ACKNum, flag, advertisedWin;
			uint8_t messageBuffer[TCP_PACKET_MAX_PAYLOAD_SIZE];
			uint32_t myKey;
			socket_t* mySocket = NULL;
			uint16_t bufflen = TCP_PACKET_MAX_PAYLOAD_SIZE; // TCP_PACKET_MAX_PAYLOAD_SIZE
			uint16_t i;
			uint16_t recieveLengthPossible;
			uint8_t isWrap;
			
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
			
			
			if (flag != DATA_FLAG || flag != DATA_ACK_FLAG) {	// this is part of a handshake
				
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
						mySocket->advertised_window = msg->advertised_window;
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
						mySocket->advertised_window = msg->advertised_window;
						// signal accept with your socket
						signal Transport.accept(*mySocket);
					}
				}
				
					
				// if FIN, if FIN_ACK
				
				
			} else {		// this is data !!
			
				if (flag == DATA_ACK_FLAG) {
					dbg (TRANSPORT_CHANNEL, "Recieved ack of data packet.");
					mySocket->lastAcked = ACKNum + 1;
				} else {
			
					dbg (TRANSPORT_CHANNEL, "Received data packet.\n");
					// copy into socket
					
					
					// bufflen = CHECK FOR SENTINEL VALUE
					// if does not exist, bufflen is full, else it is full to that point
					// sentinel value is "0" bcs i'm boring and hoping desperately it won't give me any problems
					for (i = 0; i< TCP_PACKET_MAX_PAYLOAD_SIZE; i++){
						if (msg->payload[i] == 0) {
							bufflen = i;
							break;
						}
					}
					
					// this is w/ lastRead, lastRcvd, lastExpected
					//uint16_t recieveLengthPossible;
					//uint8_t isWrap;
					
					if (mySocket->lastRead <= mySocket->lastRcvd) {	// wrapping, can write from rcvd to end and from beginning to read
						isWrap = TRUE;
						recieveLengthPossible = (BUFFER_SIZE - mySocket->lastRcvd) + mySocket->lastRead;
					} else {	// non-wrapping, can write from rcvd to read
						isWrap = FALSE;
						recieveLengthPossible = mySocket->lastRead - mySocket->lastRcvd;
					}
					
					
					if (bufflen > recieveLengthPossible) {
						dbg (TRANSPORT_CHANNEL, "Discarding package; not enough room in buffer. ...this shouldn't be happening, oops.\n");
					} else {
						if (isWrap == TRUE && bufflen > (BUFFER_SIZE - mySocket->lastRcvd)) {
							// first, copy from rcvd up to end
							memcpy(mySocket->recvBuffer+(mySocket->lastRcvd), msg->payload, (BUFFER_SIZE - mySocket->lastRcvd)*sizeof(uint8_t) );
							// next, copy from beginning to read
							memcpy(mySocket->recvBuffer, msg->payload+(BUFFER_SIZE - mySocket->lastRcvd), (bufflen - (BUFFER_SIZE - mySocket->lastRcvd))*sizeof(uint8_t) );
							// next adjust lastRecvd
							mySocket->lastRcvd = (bufflen - (BUFFER_SIZE - mySocket->lastRcvd));
						} else { // no wrap possible, or bufflen is small enough that no wrap happens
							memcpy(mySocket->recvBuffer+(mySocket->lastRcvd), msg->payload, bufflen*sizeof(uint8_t) );
							mySocket->lastRcvd += bufflen;
						}
						
						// next, send ack of data
						t = (tcp_pack*) p.payload;
						t->dest_port = mySocket->dest_addr.port;
						t->src_port = mySocket->src_addr.port;
						srand(time(NULL));
						t->seq = seqNum;
						t->ACK = seqNum+1;
						t->flags = DATA_ACK_FLAG;
						if (isWrap == TRUE) {
							t->advertised_window = (BUFFER_SIZE - mySocket->lastRcvd) + mySocket->lastRead;
						} else {
							t->advertised_window = mySocket->lastRead - mySocket->lastRcvd;
						}
						
						
						call Transport.makePack(&p, TOS_NODE_ID, mySocket->dest_addr.location, MAX_TTL, PROTOCOL_TCP, 0, t, 0);
						// payload manipulated directly
						
						// stick this in queue
						call toSendQueue.enqueue(p);
						
						// call send in Forwarder
						call TransportSender.send(p, mySocket->dest_addr.location);
						
					}
					
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
			uint16_t j;
			socket_t* mySocket;
			uint32_t myKey;
			uint16_t readLengthPossible;
			uint8_t isWrap;
			
			myKey = call Transport.getKey(fd.src_addr.port, fd.dest_addr.port, fd.dest_addr.location);
			
				// find socket with key
			if (call hashmap.contains(myKey)){
				mySocket = call hashmap.get(myKey);
			} else {
				dbg (TRANSPORT_CHANNEL, "Hash error in read.\n");
				return;
			}
			
			if (mySocket->lastRcvd == mySocket->lastRead) {
				// nothing to read
				return 0;
			} else if (mySocket->lastRcvd > mySocket->lastRead) {
				// can read from lastRead to lastRcvd
				isWrap = FALSE;
				readLengthPossible = mySocket->lastRcvd - mySocket->lastRead;
			} else { 	// read is > rcvd, it wraps
				isWrap = TRUE;
				readLengthPossible = (BUFFER_SIZE-mySocket->lastRead) + mySocket->lastRcvd;
			}			
			// either way: cannot read more than buffer can contain. So:
			if (bufflen < readLengthPossible)
				readLengthPossible = bufflen; // constrain by buffsize if there is more to read than it can contain
			
			// start reading at lastRead either way
			
			
			if (isWrap == TRUE) {
				// first copy from lastRead to end of socket buffer
				memcpy(buff, mySocket->recvBuffer+mySocket->lastRead, (BUFFER_SIZE - mySocket->lastRead) * sizeof(uint8_t) ); 
				// next, copy from beginning of buffer to remaining amount
				memcpy(buff+(BUFFER_SIZE - mySocket->lastRead), mySocket->recvBuffer, (readLengthPossible - (BUFFER_SIZE - mySocket->lastRead))* sizeof(uint8_t) );
				// next, set new read position
				if (readLengthPossible < (BUFFER_SIZE - mySocket->lastRead)) {
					mySocket->lastRead += readLengthPossible;
				} else {
					mySocket->lastRead = (readLengthPossible - (BUFFER_SIZE - mySocket->lastRead));
				}
			} else {
				// first, copy from lastRead as much as is possible
				memcpy(buff, mySocket->recvBuffer+mySocket->lastRead, (readLengthPossible) * sizeof(uint8_t) );
				// next, set new read position
				mySocket->lastRead += readLengthPossible;
			}
			
			
			// finally, we report the amount read.
			return readLengthPossible;
			
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
			
			dbg (TRANSPORT_CHANNEL, "Sending SYN to %u.\n", fd.dest_addr.location);
			
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

