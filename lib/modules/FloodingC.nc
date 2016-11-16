// Config for Flood
#define AM_FLOODING 79

configuration FloodingC{
	provides interface SimpleSend;
	provides interface Receive as MainReceive;
	provides interface Receive as ReplyReceive;
}
implementation {
	components FloodingP;
	components new SimpleSendC(AM_FLOODING);
	components new AMReceiverC(AM_FLOODING);

	//wiring
	FloodingP.InternalSender -> SimpleSendC;
	FloodingP.InternalReceiver -> AMReceiverC;

	//external interfaces
	MainReceive = FloodingP.MainReceive;
	ReplyReceive = FloodingP.ReplyReceive;
	SimpleSend = FloodingP.FloodSender;
}


