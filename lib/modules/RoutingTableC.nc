// Routing Table Config
#define AM_ROUTING 63

configuration RoutingTableC{
	provides interface RoutingTable;
}
implementation {
	components RoutingTableP;
	components new TimerMilliC() as beaconTimer;
	components new SimpleSendC(AM_ROUTING);
	components new AMReceiverC(AM_ROUTING);
	
	components NeighborDiscoveryC;
	RoutingTableP.NeighborDiscovery -> NeighborDiscoveryC;

	// external wiring
	RoutingTable = RoutingTableP.RoutingTable;

	// internal wiring
	RoutingTableP.RoutingSender -> SimpleSendC;
	RoutingTableP.MainReceive -> AMReceiverC;
	RoutingTableP.beaconTimer -> beaconTimer;
	
}

