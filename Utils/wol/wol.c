/*
* Linkstation/Kuro ARM series WOL for standby feature
* 
* Written by Bob Perry (2008) lb-source@users.sourceforge.net
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*
*/

#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

#include <sys/ioctl.h>
#include <net/if.h>

#define PACKET_SIZE 112
#define NPACK 1
#define PORT 7

typedef struct {
	unsigned char flag[6];
	unsigned char sa_data[16][6];
} MAGIC_PACKET;

void dump_error(char *s) {
	perror(s);
	exit(1);
}

int main(int argc, char *argv[]) {
	struct sockaddr_in this_addr;
	struct sockaddr from_addr;
	int sockFd;
	int i;
	int iport=7;
	int from_len=sizeof(from_addr);
	unsigned char buf[PACKET_SIZE];
	MAGIC_PACKET* wol = (MAGIC_PACKET*)&buf[0];
	struct ifreq dev;
	int iFlag;
	char *thisarg;

	argc--;
	argv++;

	// Parse any options
	while (argc >= 1 && '-' == **argv) {
		thisarg = *argv;
		thisarg++;
		switch (*thisarg) {
		case 'p':
			argc--;
			argv++;
			iport = atoi(*argv);
			break;
		}
	}
	
	// Grab the socket
	if ((sockFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP))==-1)
		dump_error("WOL: socket failed");

	// Bind to port
	memset((char *) &this_addr, 0, sizeof(this_addr));
	this_addr.sin_family = AF_INET;
	this_addr.sin_port = htons(PORT);
	this_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	if (bind(sockFd, &this_addr, sizeof(this_addr))==-1)
		dump_error("WOL: bind failed");

	// Get the device hardware info block
	strcpy (dev.ifr_name, "eth0");
	if (ioctl(sockFd, SIOCGIFHWADDR, &dev) < 0)
		dump_error("WOL: hardware info failed");

	printf("Listening on port %d: ", iport);
	for (i=0; i<6; i++) {
		printf("%02X", dev.ifr_hwaddr.sa_data[i] & 0xFF);
		if (i < 5)
			printf(":");
	}

	printf(" for magic packet\n");
	
	while(1) {
		// Get packet
		if (recvfrom(sockFd, buf, PACKET_SIZE, 0, &from_addr, &from_len) != -1) {
			iFlag = 0;
			// Magic packet header flag?
			for (i=0;i<6;i++) {
				if (wol->flag[i] == 0xFF)
					iFlag++;
			}
			
			// Magic packet? Yes, then check for MAC address
			if (iFlag == 6) {
				for (i=0;i<16;i++) {
					// See if it is for us
					if (strncmp(dev.ifr_hwaddr.sa_data, &wol->sa_data[i][0], 6) == 0)
						iFlag++;
				}
			}
			
			// All in check? Wake her up
			if (iFlag == 22) {
				printf("Wake up via EventScript\n");
				system("/tmp/micro_evtd/EventScript B 1 0 micon");
			}
		}
	}

	close(sockFd);
	return 0;
}
