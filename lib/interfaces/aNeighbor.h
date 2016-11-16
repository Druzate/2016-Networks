	#ifndef ANEIGHBOR_H
	#define ANEIGHBOR_H
	
	typedef struct aNeighbor{
		uint16_t id;
		uint16_t TTL;
	} aNeighbor;
	
	typedef struct routingTableEntry{
		uint16_t id; // final destination
		uint16_t distance; 
		uint16_t nextHop;
	} routingTableEntry;
	
	#endif
