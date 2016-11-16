// Neighbor Discovery Interface

#include "../interfaces/aNeighbor.h"

interface NeighborDiscovery{
	command void start();
	command void print();
	command aNeighbor * getNeighborList();
	command uint16_t getNeighborListSize();
}

