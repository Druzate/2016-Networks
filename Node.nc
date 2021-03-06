/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/socket.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

#define SERVER_SOCKET 123
#define CLIENT_DEFAULT_SOCKET 200
#define APP_TIMER 135000
#define APP_BUFFER_SIZE 40



module Node{
   uses interface Boot;

   uses interface Timer<TMilli> as beaconTimer;
   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

	uses interface SimpleSend as FloodSender;
	uses interface Receive as FloodReceive;
	uses interface Receive as FloodReplyReceive;
	
	
	uses interface NeighborDiscovery;
	uses interface RoutingTable;

   uses interface CommandHandler;
   
	uses interface SimpleSend as ForwardSender;
	uses interface Receive as ForwardReceive;
	uses interface Receive as ForwardReplyReceive;
	
	uses interface Transport;
	uses interface Queue<socket_t> as socketQueue;
	
	
}

implementation{
   pack sendPackage;
   uint16_t nodeSeq = 0;
   
   	// queue list of connections
		// add connections on ESTABLISHED?

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
	 
   }

   event void AMControl.startDone(error_t err){
		call RoutingTable.start();
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

	event message_t* FloodReceive.receive(message_t* msg, void* payload, uint8_t len){
		return msg;
	}

	event message_t* FloodReplyReceive.receive(message_t* msg, void* payload, uint8_t len){
		return msg;
	}
	
	event message_t* ForwardReceive.receive(message_t* msg, void* payload, uint8_t len){
		return msg;
	}
	
	event message_t* ForwardReplyReceive.receive(message_t* msg, void* payload, uint8_t len){
		return msg;
	}
	
	
	

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
	  nodeSeq++;
      makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, nodeSeq, payload, PACKET_MAX_PAYLOAD_SIZE);
      call ForwardSender.send(sendPackage, destination);
   }

   event void CommandHandler.printNeighbors(){
	  dbg(GENERAL_CHANNEL, "PRINT NEIGHBORS EVENT \n");
	  call NeighborDiscovery.print();
   }

   event void CommandHandler.printRouteTable(){
	 dbg(GENERAL_CHANNEL, "PRINT ROUTING EVENT \n");
	call RoutingTable.dumpRoutingTable();
   
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}
   
   event socket_t Transport.accept(socket_t fd) {	// call when connection established; add to list on application layer (???)
			
			// signal me when server has ESTABLISHED a connection
			dbg(GENERAL_CHANNEL, "CONNECTION ACCEPTED - Server \n");
			
			//push to established queue
			call socketQueue.enqueue(fd);	//no socketQueue component.... bcs it's in Node not Transport interface. but want to push to node
			
			return fd;
			
	}
	
	event socket_t Transport.connectDone(socket_t fd) {	// call when connection established; add to list on application layer (???)
			
			// signal me when client has ESTABLISHED a connection
			dbg(GENERAL_CHANNEL, "CONNECTION COMPLETED - Client \n");
			
			//push to established queue
			call socketQueue.enqueue(fd);
			
			return fd;
			
	}
	
	
	 event void CommandHandler.setTestServer(){
		 
	   socket_t *mySocket;
	   socket_addr_t myAddr;
	   
	   // set this as server and begin listening
	   
	   
	   myAddr.location = TOS_NODE_ID;
	   myAddr.port = SERVER_SOCKET;
	   
	    // call Transport socket
	   mySocket = call Transport.socket();
	  
	   // call bind
	   call Transport.bind(*mySocket, &myAddr);
	   
	   // call listen
	   call Transport.listen(*mySocket);
	   
	   if (!call beaconTimer.isRunning())
				call beaconTimer.startPeriodic(APP_TIMER);
	   
   }


   event void CommandHandler.setTestClient(){
	   
		socket_t *mySocket;
	   socket_addr_t myAddr;
	   	// set this as client and try to connect to listening server
	   
	   myAddr.location = TOS_NODE_ID;
	   myAddr.port = CLIENT_DEFAULT_SOCKET;
		
		// call socket
		mySocket = call Transport.socket();
		mySocket->dest_addr.port = SERVER_SOCKET;
		mySocket->dest_addr.location = 1; //assume 1 is always serv for now
		
		// call connect
		call Transport.connect(*mySocket, &myAddr);
		
		 if (!call beaconTimer.isRunning())
				call beaconTimer.startPeriodic(APP_TIMER);
		
   }
   
   event void beaconTimer.fired(){
	   uint8_t writeBuffer[APP_BUFFER_SIZE];
	   uint8_t readBuffer[APP_BUFFER_SIZE];
	   uint8_t i, j = 1;
	   socket_t mySocket;
	   uint16_t* point;
	   uint8_t queueSize = call socketQueue.size();
	   
	   dbg(GENERAL_CHANNEL, "App timer fired. \n");
	   
	   for (i = 0; i < APP_BUFFER_SIZE; i++){
		   readBuffer[i] = 0;	// make sure readBuffer is initialized/clean
		   writeBuffer[i] = i+1;	// set up things to write to socket
	   }
	   
	   for (i=0; i< queueSize; i++) {
			mySocket = call socketQueue.element(i);
			j = call Transport.read(mySocket, readBuffer, APP_BUFFER_SIZE);
			call Transport.write(mySocket, writeBuffer, APP_BUFFER_SIZE);
			dbg(GENERAL_CHANNEL, "App read: ");
			if (j != 0) {
				for (j = 0; j< APP_BUFFER_SIZE; j++) {
					if (j == APP_BUFFER_SIZE - 1 && readBuffer[j] != 0) {
						dbg_clear(GENERAL_CHANNEL, "%hu\n", readBuffer[j]);
					} else if (readBuffer[j] != 0) {
						dbg_clear(GENERAL_CHANNEL, "%hu, ", readBuffer[j]);
					} else if (j == APP_BUFFER_SIZE - 1) {
						dbg_clear(GENERAL_CHANNEL, "\n");
					}
				}
			} else {
				dbg_clear(GENERAL_CHANNEL, "nothing.\n");
			}
			
		}
	   
   }



  
   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
