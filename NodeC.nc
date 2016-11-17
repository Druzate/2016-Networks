/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
	
	components new TimerMilliC() as beaconTimer;
	Node.beaconTimer -> beaconTimer;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

	components FloodingC;
	Node.FloodSender -> FloodingC.SimpleSend;
	Node.FloodReceive -> FloodingC.MainReceive;
	
	components NeighborDiscoveryC;
	Node.NeighborDiscovery -> NeighborDiscoveryC.NeighborDiscovery;
	
	components RoutingTableC;
	Node.RoutingTable -> RoutingTableC.RoutingTable;
	
	components ForwarderC;
	Node.ForwardSender -> ForwarderC.SimpleSend;
	Node.ForwardReceive -> ForwarderC.MainReceive;
	
	components TransportC;
	Node.Transport -> TransportC.Transport;
	components new QueueC(socket_t, 30) as sockQueue;
	Node.socketQueue->sockQueue;
	
}

