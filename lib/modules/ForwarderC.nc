// Config for Forward
#define AM_FORWARDING 81

configuration ForwarderC{
	provides interface SimpleSend;
	provides interface Receive as MainReceive;
	provides interface Receive as ReplyReceive;
}
implementation {
	components ForwarderP;
	components new SimpleSendC(AM_FORWARDING); 
	components new AMReceiverC(AM_FORWARDING); 
	
	
	components RoutingTableC;
	ForwarderP.RoutingTable -> RoutingTableC.RoutingTable;

	//wiring
	ForwarderP.InternalSender -> SimpleSendC;
	ForwarderP.InternalReceiver -> AMReceiverC;

	//external interfaces
	MainReceive = ForwarderP.MainReceive;
	ReplyReceive = ForwarderP.ReplyReceive;
	SimpleSend = ForwarderP.ForwardSender;
	
	
	components TransportC;
	ForwarderP.Transport -> TransportC.Transport;
	
}


