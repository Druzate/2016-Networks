
#ifndef SOCKET_H
#define SOCKET_H
#define BUFFER_SIZE 255

#define CONN_CLOSED 0
#define CONN_LISTEN 32
#define CONN_SYN_SENT 2
#define CONN_SYN_RCVD 3
#define CONN_ESTABLISHED 4
#define CONN_FIN_WAIT1 5
#define CONN_FIN_WAIT2 6
#define CONN_TIME_WAIT 7
#define CONN_CLOSE_WAIT 8
#define CONN_LAST_ACK 9

#define SERVER_SENTINEL 167

# include "protocol.h"
#include "channels.h"

typedef nx_struct socket_addr_t{
	nx_uint16_t location;
	nx_uint8_t port;
} socket_addr_t;

typedef nx_struct socket_t{
	socket_addr_t dest_addr;
	socket_addr_t src_addr;
	nx_uint16_t seq; 
	nx_uint8_t conn_state;
	nx_uint8_t advertised_window;
	nx_uint16_t lastRcvd;
	nx_uint16_t lastRead;
	nx_uint16_t lastExpected;
	nx_uint8_t recvBuffer[BUFFER_SIZE];
	nx_uint16_t recvBufferCounter;
	nx_uint16_t lastAcked;
	nx_uint16_t lastSent;
	nx_uint16_t lastWritten;
	nx_uint8_t sendBuffer[BUFFER_SIZE];	
	nx_uint16_t sendBufferCounter;
	nx_uint8_t isServer;
} socket_t;



#endif
