// RoutingTable Interface

#include "../interfaces/aNeighbor.h"

interface RoutingTable{
	command void start();	
	command void dumpRoutingTable();
	command uint16_t returnNextHop(uint16_t finalDest);
}

