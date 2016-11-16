// Forwarding Interface

interface Forwarder{
	// based on Flooding
	
	command error_t send(pack msg, uint16_t dest);
	//event message_t* InternalReceiver.receive(message_t* raw_msg, void* payload, uint8_t len);
}

