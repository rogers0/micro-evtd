/*
* Linkstation/Kuro ARM series MAC address changer
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>

#include <net/if.h>

int main (int argc, char *argv[]) {
	int i, j;
	unsigned int byte;
	int iSet=0;
	char *thisarg;
	char strMAC[12] = {"000000000000"};
	char strTemp[80];
	int sockFd;
	struct ifreq dev;

	argc--;
	argv++;

	// Parse any options
	while (argc >= 1 && '-' == **argv) {
		thisarg = *argv;
		thisarg++;
		switch (*thisarg) {
		case 's':
			argc--;
			argv++;
			j = 0;
			strcpy(strTemp, *argv);
			for (i=0;i<12;i++) {
				strMAC[i] = strTemp[j];
				j++;
				if (strTemp[j] == ':')
					j++;
			}

			iSet = 1;
			break;
		}
	}
	
	sockFd = socket (AF_INET, SOCK_DGRAM, 0);
	if (sockFd < 0) {
		printf("Socket allocation error\n");
	}

	strcpy (dev.ifr_name, "eth0");
	if (ioctl(sockFd, SIOCGIFHWADDR, &dev) < 0) {
		printf("Unable to get ether device\n");
	}

	for (i=0; i<6; i++) {
		printf("%02X", dev.ifr_hwaddr.sa_data[i] & 0xFF);
		if (i < 5)
			printf(":");
	}

	printf("\n");
	
	sleep(2);
	
	if (iSet) {
		for (i=0; i<6; i++) {
			sscanf(&strMAC[i*2], "%02X", &byte);
			dev.ifr_hwaddr.sa_data[i] = byte;
		}
		
		if (ioctl(sockFd, SIOCSIFHWADDR, &dev) < 0) {
			printf ("Can not change MAC address");
			return -1;
		}
	}
	
	return 0;
}
