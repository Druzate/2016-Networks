// Neighbor Discovery Config
#define AM_NEIGHBOR 62

configuration NeighborDiscoveryC{
	provides interface NeighborDiscovery;
}
implementation {
	components NeighborDiscoveryP;
	components new TimerMilliC() as beaconTimer;
	components new SimpleSendC(AM_NEIGHBOR);
	components new AMReceiverC(AM_NEIGHBOR);

	// external wiring
	NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

	// internal wiring
	NeighborDiscoveryP.NeighborSender -> SimpleSendC;
	NeighborDiscoveryP.MainReceive -> AMReceiverC;
	NeighborDiscoveryP.beaconTimer -> beaconTimer;
	
}

