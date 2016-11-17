// Routing Table Config
#define AM_TRANSPORT 66

configuration TransportC{
	provides interface Transport;
}
implementation {
	components TransportP;
	components new TimerMilliC() as beaconTimer;
	components new TimerMilliC() as queueTimer;
	components new SimpleSendC(AM_TRANSPORT);
	components new AMReceiverC(AM_TRANSPORT);
	
	//components ForwarderC;
	//TransportP.Forwarder -> ForwarderC;

	// external wiring
	Transport = TransportP.Transport;

	// internal wiring
	TransportP.TransportSender -> SimpleSendC;
	//TransportP.MainReceive -> AMReceiverC;
	TransportP.beaconTimer -> beaconTimer;
	TransportP.queueTimer -> queueTimer;
	
	//pools
	components new PoolC(socket_t, 30) as sockPool;
	components new HashmapC(socket_t*, 30) as sockHash;
	//components new PoolC(socket_addr_t) as addrPool;
	TransportP.pool->sockPool;
	TransportP.hashmap->sockHash;
	//TransportP.addresspool->addrPool;
	
	components ForwarderC;
	TransportP.TransportSender -> ForwarderC.SimpleSend;
	
	components new QueueC(socket_t, 100) as sockQueue;
	TransportP.toSendQueue->sockQueue;

	
}

