/*
* Linkstation/Kuro/Terastation ARM series Micro daemon
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

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/statfs.h>
#include <stdio.h> 
#include <string.h> 
#include <stdlib.h> 
#include <sys/time.h> 
#include <linux/serial.h>
#include <stdlib.h>

#include <sys/mman.h>

#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/file.h>

#include <sys/io.h>
#include <syslog.h>

#include <sys/resource.h>

#include "version.h"

// Event message definitions
#define FAN_FAULT		'4'
#define CP_SCRIPT		'C'
#define OVER_HEAT		'O'
#define INFO			'I'
#define BUTTON_EVENT    	'B'
#define TIMED_STANDBY		'S'
#define WARNING             	'W'
#define TIMER_INFO		'T'
#define CREATE_PID		'P'

#define FAN_SEIZE_TIME		30
#define ENTER_EM_TIME        4

#define CALL_NO_WAIT         0
#define CALL_WAIT			 1

#define GPP_DATA_OUT_REG	64
#define GPP_DATA_OUT_EN_REG	65
#define GPP_BLINK_EN_REG	66
#define GPP_DATA_IN_POL_REG	67
#define GPP_DATA_IN_REG		68
#define GPP_INT_CAUSE_REG	69
#define GPP_INT_MASK_REG	70
#define GPP_INT_LVL_REG		71
#define MAP_SIZE 			4096UL
#define MAP_MASK 			(MAP_SIZE - 1)

#define TWELVEHR			12*60
#define TWENTYFOURHR        TWELVEHR*2
#define FIVE_MINUTES		5*60

/**
Macro event object definition
*/
typedef struct _OFF_TIMER
{
	char day;	///< Event day
	long time;	///< Event time (24hr)
	void* pointer;	///< Pointer to next event
} TIMER;

// Some global variables
const char strVersion[]="Micro-monitor daemon Version";
const char micro_device[]="/dev/ttyS1";
const char micro_conf[]="/etc/micro_evtd/micro_evtd.conf";
const char micro_lock[]="/var/lock/micro_evtd";
TIMER* poffTimer=NULL;
TIMER* ponTimer=NULL;
int last_day;
char i_debug=0;
int iTempRange[4]={30, 37, 40, 60};
int fanFaultSeize=30;
int iControlFan=1;
time_t tt_LastMicroAcess = 999;
int refreshRate=40;
int iHysteresis=2;
char i_Use_Trend=1;
char log_path[20]="/var/log";
int iDebugLevel=0;
char strTmpPath[20]="/tmp";
int i_FileDescriptor = 0;
int i_Poll = 0;
int mutexId=0;
key_t mutex;
int iLastSwitch=0;
volatile unsigned long *gpio = NULL;
int m_fd = 0;
long l_TimerEvent=3420300; /* Careful here */
char c_FirstTimeFlag=1;
char c_TimerFlag = 0;
char i_instandby = 0;
int resourceLock_fd = 0;
int s_dst = 0; // Daylight saving flag
#ifdef TEST
  long override_time=0;
#endif
char c_Skip = 0;
int iButtonAction = 0; ///< Defines type of button action, 0=OFF, 128=STANDBY
int iButtonHeld = 0;
time_t tOnLastTime = 999;
char alt = 1; ///< Provides control for alternating sound on held button
long iOffTime = 0;
long iOnTime = 0;

static void open_serial(void);
static int writeUART(int, unsigned char*);
static void check_configuration(char);
static void fan_set_speed(char);
static void micro_evtd_main(void);
static void parse_configuration(char*);
static int execute_command2(char, char*, char, char, long);
static int execute_command(char, char, char);
static int temp_get(void);
static void open_gpio(void);
static void GetTime(long, TIMER*, long*);
static char FindNextToday(long, TIMER*, long*);
static char FindNextDay(long, TIMER*, long*, long*);
static void destroyObject(TIMER*);
static void validate_time(time_t ltime);

/**
************************************************************************
*
*  function    : execute_command()
*
*  description : Pass the supplied values to the event script and execute
*				 it.
*
*  arguments   : (in)	char				= Event script command
*						char				= script command
*						char				= either 0=execute and wait, 
*													 1=execute and no wait.
*					  
*  returns     : 		int					= -1 indicates an error.
************************************************************************
*/	
static int execute_command(char cmd, char cmd2, char type)
{
	return execute_command2(cmd, ".", type, type, cmd2);
}

/**
************************************************************************
*
*  function    : open_serial()
*
*  description : Gain access to the micro interface.
*
*  arguments   : (in)	void
*					  
*  returns     : 		void
************************************************************************
*/	
static void open_serial(void)
{
	struct termios newtio;

	/* Need read/write access to the micro  */
	i_FileDescriptor = open(micro_device, O_RDWR);

	/* Successed? */
	if(i_FileDescriptor < 0) {
		perror(micro_device);
	}

	/* Yes */
	else {
		ioctl(i_FileDescriptor, TCFLSH, 2);
		/* Clear data structures */
		memset(&newtio, 0, sizeof(newtio));
		
		newtio.c_iflag =IGNBRK;
		newtio.c_cflag = PARENB | CLOCAL | CREAD | CSTOPB | CS8 | B38400;
		newtio.c_lflag &= (~ICANON);
		newtio.c_cc[VMIN] = 0;
		newtio.c_cc[VTIME] = 100;

		/* Update tty settings */
		ioctl(i_FileDescriptor, TCSETS, &newtio);
		ioctl(i_FileDescriptor, TCFLSH, 2);
	}
}

/**
************************************************************************
*
*  function    : open_gpio()
*
*  description : Gain access to the GPIO.
*
*  arguments   : (in)	void
*					  
*  returns     : 		void
************************************************************************
*/	
static void open_gpio(void)
{
#ifndef TS
	off_t target = 0xF1010100;
	// Grab memory resource
	m_fd = open("/dev/mem", O_RDWR | O_SYNC);
	if (m_fd>0) {
		// Grab GPIO resource
		gpio = (unsigned long*)mmap(NULL, MAP_MASK, PROT_READ | PROT_WRITE, MAP_SHARED, m_fd, (target & ~MAP_MASK));
		// Our GPIO pointer valid?
		if (gpio >0) {
			// Ensure GPIO mode setup correctly
			if ((gpio[GPP_DATA_OUT_EN_REG] & 0xD) != 0xD)
				gpio[GPP_DATA_OUT_EN_REG] |= 0xD;	// Read modified write
			/* MICON detect bit please */
			gpio[GPP_DATA_IN_POL_REG] = 4;
			/* Clear MICON interrupt BIT */
			gpio[GPP_INT_CAUSE_REG] &= ~0x4;
		}
	}
#else
#warning "TS Build supports button events via serial control"
#endif
}

/**
************************************************************************
*
*  function    : close_serial()
*
*  description : Release our serial port handle along with the resource
*				 lock.
*
*  arguments   : (in)	void
*					  
*  returns     : 		void
************************************************************************
*/	
static void close_serial(void)
{
	union semun {
		int val;
		struct semid_ds *buf;
		ushort *array;
	} arg;
	
	if (i_FileDescriptor > 0) {
		/* Close port and invalidate our pointer */
		close(i_FileDescriptor);
	}

	// Close memory handle too
	if (m_fd > 0)
		close(m_fd);
	
	/* Close flock handles if we have one */
	if (resourceLock_fd > 0)
		close(resourceLock_fd);
		
	// Remove it mutex if we have one
	if (mutexId >0)
		semctl(mutexId, 0, IPC_RMID, arg);
}

/**
************************************************************************
*
*  function    : reset()
*
*  description : Demand micro reset.
*
*  arguments   : (in)	void
*					  
*  returns     : 		void
************************************************************************
*/	
static void reset(void)
{
	char buf[40]={0xFF,};
	int i;
	write(i_FileDescriptor, &buf, sizeof(buf));
	// Give micro some time
	usleep(400);
	for (i=0;i<2;i++) {
		read(i_FileDescriptor, buf, sizeof(buf));
	}
}

/**
************************************************************************
*
*  function    : termination_handler()
*
*  description : User termination handler.  Handle the system events here.
*
*  arguments   : (in)	int				= system handler.
*					  
*  returns     : 		void
************************************************************************
*/	
static void termination_handler(int signum)
{
	switch (signum) {
	case SIGTERM:
		close_serial();
		exit(0);
		break;
	/* Signalled shutdown delay */
	case SIGCONT:
		l_TimerEvent += FIVE_MINUTES;
		/* Reset warning flag */
		c_FirstTimeFlag = 1;
	case SIGHUP:
		execute_command2(TIMER_INFO, ".", CALL_NO_WAIT, s_dst, l_TimerEvent/60);
		break;
	/* Signalled skip this shutdown time */
	case SIGINT:
		c_Skip = 1;
		break;
	default:
		break;
	}
}

/**
************************************************************************
*
*  function    : lockMutex()
*
*  description : Lock/un-lock the micro interface resource.
*
*  arguments   : (in)	char				= lock flag.
*					  
*  returns     : 		void
************************************************************************
*/	
static void lockMutex(char iLock) {
	// Handle mutex locking/un-locking here
	struct sembuf mutexKey = {0, -1, 0};  // set to allocate resource
	// Mutex valid?
	if (mutexId > 0) {
		// Lock resource
		if (!iLock)
			mutexKey.sem_op = 1; // free resource

		semop(mutexId, &mutexKey, 1);
	}
	
	// Drop back to flocks
	else
		flock(resourceLock_fd, (iLock) ? LOCK_EX : LOCK_UN);
}

/**
************************************************************************
*
*  function    : writeUART()
*
*  description : Send the supplied transmit buffer to the micro.  We
*				 calculate and populate the checksum and return the
*				 micro response.
*
*  arguments   : (in)	int					= number of characters
*						unsigned char*		= pointer to transmit buffer
*					  
*  returns     : 		int					= micro return
************************************************************************
*/	
static int writeUART(int n, unsigned char* output)
{
	/* Handle ALL UART messages from a central point, reduce code
	 * overhead */
	unsigned char icksum = 0;
	unsigned char rbuf[32] = {0,};
	char retries = 1;
	int i;
	int len = 0;
	fd_set fReadFS;
	struct timeval tt_TimeoutPoll;
	int iResult;
	int iReturn = -1;

	lockMutex(1);
	
	do {
		if (n >0) {
			icksum = 0;
			/* Calculate the checksum */
			for (i=0; i<n; i++) {
				icksum -= output[i];
				/* Send data  */
				write(i_FileDescriptor, &output[i], 1);
				// Give micro time to process
				usleep(400);
			}
			
			/* Send  checksum */
			write(i_FileDescriptor, &icksum, 1);
		} 

		tt_TimeoutPoll.tv_usec = 500000;
		tt_TimeoutPoll.tv_sec = 0;

		FD_ZERO(&fReadFS);
		FD_SET(i_FileDescriptor, &fReadFS);

		iResult = select(i_FileDescriptor + 1, &fReadFS, NULL, NULL, &tt_TimeoutPoll);
		
		if (iResult !=0) {
			/* Ignore data errors */
			len = read(i_FileDescriptor, rbuf, sizeof(rbuf));
		}
		
		if (len < 4) {
			reset();
		}
		else if (len>0) {
			// Calculate data sum for validation
			icksum = 0;
			for (i=0;i<len;i++)
				icksum = icksum-rbuf[i];
			
			// Process if data valid
			if (0 == icksum){
				if (n>0) {
					// Check returned command status
					if (rbuf[1] == output[1])
						n = 0;
				}
			}
				
		    if (0 == n) {
			    iReturn = (int)rbuf[2];
				if (len-3 > 1) {
					for (i=0;i<len-4;i++)
						printf("%d ", rbuf[2+i]);
					iReturn = (int)rbuf[2+len-4];
				}
				goto exit;
			}
		}
	} while (--retries > 0);

exit:
	lockMutex(0);
	
	return iReturn;
}

/**
************************************************************************
*
*  function    : temp_get()
*
*  description : Get the current MB temperature from the micro.
*
*  arguments   : (in)	void
*					  
*  returns     : 		int					= actual temperature
************************************************************************
*/	
static int temp_get(void)
{
	int iTemp = writeUART(2, (unsigned char*)"\x080\x037");
	// Ensure within range
	return ((iTemp & 0x80) != 0 ? 0 : iTemp);
}

/**
************************************************************************
*
*  function    : fan_set_speed()
*
*  description : Set the fan RPM.
*
*  arguments   : (in)	char				= Demanded speed 1=OFF
*															 2=SLOW
*															 3=FAST
*															 4=FULL
*					  
*  returns     : 		void
************************************************************************
*/	
static void fan_set_speed(char cSpeed)
{
	unsigned char ucSpdDemand[3] = {'\x001','\x033', ' '};

	ucSpdDemand[2] = cSpeed - 1;
	writeUART(3, ucSpdDemand);  // 0, 1, 2, 3
}

/**
************************************************************************
*
*  function    : fan_get_rpm()
*
*  description : Retrieve the fan RPM from the micro.
*
*  arguments   : (in)	void
*					  
*  returns     : 		int					= actual fan RPMs
************************************************************************
*/	
static int fan_get_rpm(void)
{
#ifdef TS
	return writeUART(2, (unsigned char*)"\x080\x038") * 15;
#else
	return writeUART(2, (unsigned char*)"\x080\x038") * 30;
#endif
}

/**
************************************************************************
*
*  function    : system_set_watchdog()
*
*  description : Set the micro watchdog timer.
*
*  arguments   : (in)	char				= defeat time, in seconds
*					  
*  returns     : 		void
************************************************************************
*/	
static void system_set_watchdog(char cTimer)
{
	unsigned char ucWatchDogDemand[3] = {'\x001','\x035', ' '};

	ucWatchDogDemand[2] = 255 - cTimer;
	//  timer = 255 - time
	writeUART(3, ucWatchDogDemand);
}

/**
************************************************************************
*
*  function    : execute_command2()
*
*  description : Pass the supplied values to the event script and execute
*				 it.
*
*  arguments   : (in)	char				= Event script command
*						char*				= pointer to a command string
*						char				= either 0=execute and wait, 
*													 1=execute and no wait.
*						char				= script command
*						long				= long value
*					  
*  returns     : 		int					= -1 indicates an error.
************************************************************************
*/	
static int execute_command2(char cmd, char* cmdstring, char type, char cmd2, long cmd3)
{
	char strEventScript[80];
	
	// Create the command line
	sprintf(strEventScript, "/%s/micro_evtd.event %c %d %ld %s %s %d %c", 
	(CP_SCRIPT ==  cmd? "etc/micro_evtd" : strTmpPath), 
	cmd, 
	cmd2, 
	cmd3,
	cmdstring,
	(CP_SCRIPT ==  cmd? strTmpPath : log_path), 
	iDebugLevel, (CALL_NO_WAIT == type ? '&' : ' '));
	
	// Invoke request
	return system(strEventScript);
}

/**
************************************************************************
*
*  function    : getResourceLock()
*
*  description : Establish the resource lock for the Micro interface.
*
*  arguments   : (in)	void
*					  
*  returns     : 		void
*
************************************************************************
*/
static void getResourceLock(void)
{
	union semun {
		int val;
		struct semid_ds *buf;
		ushort *array;
	} arg;

	if (mutex >0) {
		// Get semaphore
		mutexId = semget(mutex, 1, IPC_CREAT|0666);
		// Check if got, failed then must still be valid so get it
		if (mutexId == 0) {
			// Release the mutex
			if (semctl(mutexId, 0, IPC_RMID, arg) != -1) {
				mutexId = semget(mutex, 1, IPC_CREAT|0666);
			}
		}
			
		if (mutexId > 0) {
			// Initialise semaphore to 0
			arg.val = 1;
			semctl(mutexId, 0, SETVAL, arg);
		}
	}
	
	/* No IPC available, fall-back to file-lock mechanism */
	else
		resourceLock_fd = open(micro_lock, O_WRONLY|O_CREAT, 0700);
}

/**
************************************************************************
*
*  function    : check_shutdown()
*
*  description : If standby is enabled, then we check and act on the
*				 time remaining value.
*
*  arguments   : (in)	time_t				= time we last ran
*					  
*  returns     : 		void
*
************************************************************************
*/
static void check_shutdown(time_t tt_LastTimerEventPing)
{
	time_t ltime;
	
	// shutdown timer event?
	if(1 == c_TimerFlag) {

		// Decrement our powerdown timer
		if (l_TimerEvent > 0) {
			long l_check;
			struct tm tm; 
			/* We adjust the time to GMT so we can catch DST changes. */ 
			l_check = time(&ltime) - tt_LastTimerEventPing;
			tm = *localtime(&ltime); 
			l_TimerEvent -= l_check;
			/* Large clock drift, either user set time or an ntp update, handle accordingly. */
			if (abs(l_check) > 60 || tm.tm_isdst != s_dst) {
				s_dst = tm.tm_isdst;
				validate_time(ltime);
			}

			/* Not skipping and less than 5 mins to go? */
			if (!c_Skip && l_TimerEvent < FIVE_MINUTES) {
				if (c_FirstTimeFlag) {
					validate_time(ltime);
					execute_command(WARNING, i_instandby, CALL_NO_WAIT);
					c_FirstTimeFlag = 0;
				}
			}
		}

		/* User demanded next time? */
		else if (c_Skip) {
			check_configuration(1);
			c_Skip = 0;
		}

		else {
			// Prevent re-entry and execute command
			c_TimerFlag = 2;
			execute_command(TIMED_STANDBY, i_instandby, CALL_WAIT);
		}
	}
}

/**
************************************************************************
*
*  function    : gpio_button_press()
*
*  description : Process the button event.
*
*  arguments   : (in)	int					= Button held counter
*					  
*  returns     : 		void
*
************************************************************************
*/
static void gpio_button_press(void)
{
	// Check to see if we have a GPIO interupt, takes 4 seconds to latch (must be a timer here somewhere?)
	if (gpio>0) {
		/* Check both interrupt and PIN; if we run without GPIO IRQ then we can capture it quicker here. */
		if ((gpio[GPP_INT_CAUSE_REG] & 0x04) != 0 || (gpio[GPP_DATA_IN_REG] & 0x04) != 0) {
			/* Clear cause of interrupt */
			gpio[GPP_INT_CAUSE_REG] &= ~0x4;
			alt = iButtonHeld = 1;
		}
	}
	
	// Provide an alternative button control in the event of gpio failure (support 
	else {
		int iButton = 0xF ^ writeUART(2, (unsigned char*)"\x080\x036");
		if (iButton != 0 && iLastSwitch != iButton)
			alt = iButtonHeld = 1;
	}
	
	/* Has button been and still is pressed? */
	if (iButtonHeld) {
		char cButtonHeld = iButtonHeld > ENTER_EM_TIME;
		int iSwitch = 0xF ^ writeUART(2, (unsigned char*)"\x080\x036");
		iButtonHeld +=1;

		/* Button held for longer than shutdown event */
		if (ENTER_EM_TIME == iButtonHeld)
			alt = 3;
		
		/* Check for switch event change */
		if (iLastSwitch != iSwitch) {
			/* On release please */
			if (0 == iSwitch) {
				if (cButtonHeld)
					iLastSwitch = 65;
				iButtonHeld = 0;
				alt = 3;
				/* Pipe data out through the event  script */
				execute_command2(BUTTON_EVENT, "micon", CALL_NO_WAIT, (iButtonAction | iLastSwitch), 0);
			}
				
			iLastSwitch = iSwitch;
		}
		
		if (1 == alt) {
			alt = 1;
		}
		
		/* Toggle sound if button held too long */
		else if (3 == alt || cButtonHeld) {
			alt = 2;
		}

		if (alt >0)
			execute_command2(BUTTON_EVENT, "micon", CALL_NO_WAIT, (199 + alt), 0);

		alt--;
	}
}

#define FAN_SPEED_RPM iResult

/**
************************************************************************
*
*  function    : micro_evtd_main()
*
*  description : Main processing loop.
*
*  arguments   : (in)	void
*					  
*  returns     : 		void
*
************************************************************************
*/
static void micro_evtd_main(void)
{
	char iBoost=1;
	int iLastTemp=0;
	int iFan_speed=0;
	int iTemp=0;
	int dooze=2;
	int iOverTemp=0;
	char iFanStops=0;
	int iResult;
	char iCount = 20;
	char iFan_failure=0;
	char iCmd=0;
	char iCurrent_speed=0;
	char changeSpeed=0;
	float fTrend_temp=-1;
	time_t tt_LastTimerEventPing;
	struct timespec sysSleep;
	int iTmp;
	float fTempCheck;
	char iUpdate=0;

	// Reset the clock
	tt_LastTimerEventPing = time(NULL);
	// Do watch-dog disable
	system_set_watchdog(255); // 0 will kill it dead
	// do boot_end here
	writeUART(2, (unsigned char*)"\x000\x003");
	// Grab access to the GPIO registers
	open_gpio();

	while (i_FileDescriptor) {
		// Set the sleep but speed up on button press
		sysSleep.tv_sec = (iLastSwitch != 0) ? 0 : 2;
		sysSleep.tv_nsec = (iLastSwitch != 0) ? 500000000 : 0;
		
		nanosleep(&sysSleep, NULL);
		
		iCount+=2;
		
		// Get button press event
		gpio_button_press();
		
		/* Poll the system status? */
		if (iCount >= dooze && !iButtonHeld && (2 != c_TimerFlag)) {
			iCount = 0;
			// See if our configuration file has changed?
			check_configuration(0);
			if (refreshRate > 0) {
				// Do some watch-dog refreshing (250 seconds)
				system_set_watchdog(250);
			}
			// Get system temp
			iTmp = temp_get();
			// Check for over-heat
			if (iTemp > iTempRange[3]) {
				// Increment number of over-heat events
				iOverTemp++;
				// Keep a close eye on this
				dooze = 2;
				// Inform script
				execute_command(OVER_HEAT, iOverTemp, CALL_WAIT);
			}
			// Reset over-temp count
			else {
				if ( iOverTemp > 0) {
					execute_command(OVER_HEAT, 0, CALL_WAIT);
					// Clear overheat timer
					iOverTemp = 0;
				}
			}

			// Determine if the fan is already running
			FAN_SPEED_RPM = fan_get_rpm();

			// Determine current fan speed
			if (FAN_SPEED_RPM > 0) {
				iCurrent_speed = 3;
				// Slow speed  ~1740rpm
				if (FAN_SPEED_RPM < 1950)
					iCurrent_speed = 2;
				// Full speed ~ 3000rpm
				else if (FAN_SPEED_RPM > 2900)
					iCurrent_speed = 4;
			}
			
			// Must be stopped
			else
				iCurrent_speed = 1;

			// Alert user to temp and fan speed info on change only
			if (iTmp != iTemp || iFan_speed != FAN_SPEED_RPM) {
				iUpdate++;
			}
				
			iTemp = iTmp;
			iFan_speed = FAN_SPEED_RPM;
			
			// See if we need to control the fan speed?
			if (iControlFan && 0 == iOverTemp) {
				// Use the trend as the fan monitor?
				if (i_Use_Trend) {
					// Seed the trend
					if (fTrend_temp <0)
						fTrend_temp = (float)iTemp;
					// calculate the temp trend, based on simple averaging filter
					fTempCheck = ((float)iTemp + fTrend_temp)/2.0f;
					fTrend_temp = fTempCheck;
				}
				// Use actual sampled temp.
				else
					fTempCheck = (float)iTemp;

				iTmp = 0;
				// Add some hysteresis around desired temp switching
				if (iLastTemp > iTemp)
					iTmp = -iHysteresis;

				// Determine the desired fan speed based on returned box temp.
				if (fTempCheck <= (iTempRange[0]) + iTmp) iCmd = 2;
				else if (fTempCheck > (iTempRange[2])) iCmd = 5;
				else if (fTempCheck > (iTempRange[1])) iCmd = 4;
				else iCmd = 3;

				if (iControlFan > 1) iCmd = ((iCmd > iControlFan) ? iCmd : iControlFan);
				iCmd--;
				
				// Check if we had requested a speed-up request from stopped
				if (changeSpeed > 1 && 1 == iCurrent_speed) {
					iUpdate++;
					// Check often on change to ensure it happens
					dooze = 2;
					// Start incrementing our fan failure count
					iFan_failure++;
					// Can take a while to speed-up
					if (iCurrent_speed < changeSpeed && iFan_failure > 10) {
						// 1st fan failure?
						if (11 == iFan_failure) {
							iFanStops++;
							// Boost fan speed if jammed
							fan_set_speed(3);
							execute_command(FAN_FAULT, 0, CALL_NO_WAIT);
						}
						// Fan still failed after our stalled timer?
						else if (iFan_failure > fanFaultSeize/2) {
							execute_command(FAN_FAULT, 2, CALL_WAIT);
						}
					}
				}
				else {
					// Recovered from fan failure message
					if (iFan_failure > 11)
						execute_command(FAN_FAULT, 1, CALL_WAIT);

					// Reset our snooze time
					if (iCmd == iCurrent_speed) {
						// Re-issue fan speed request
						if (changeSpeed) {
							fan_set_speed(iCmd);
							// Clear fan speed request flag
							changeSpeed = 0;
						}
						// Back to normal refresh rate
						dooze = (refreshRate > 0 ? refreshRate : fanFaultSeize);
					}

					// Clear fault  flag
					iFan_failure = 0;

					// Clear boost as demanded RPMs have been reached
					if (2 == iBoost)
						iBoost = 0;
				}

				// Fan speed up request?
				if (iCmd != iCurrent_speed) {
					// Ensure we check the fan update
					dooze = 2;
					// Set the flag and boost speed
					changeSpeed = iCmd;
					// On first switch on, go full power for two seconds to over come any dirt/dust spin-up issues
					if (1 == iCurrent_speed && iCmd > 1) {
						if (iBoost) {
							iBoost = 2;
							iCmd = 4;
						}
					}
					
					fan_set_speed(iCmd);
					iLastTemp = fTempCheck + (float)(-iTmp);
				}
			}
			// Are we in overheat?
			else if (0 == iOverTemp)
				// Back to normal refresh rate
				dooze = (refreshRate > 0 ? refreshRate : fanFaultSeize);
		}

		// Check our remaining time
		check_shutdown(tt_LastTimerEventPing);
		
		// Do we need to update my_status?
		if (iUpdate) {
			char str[32];
			sprintf(str, "%d", iFanStops);
			execute_command2(INFO, str, CALL_NO_WAIT, iTemp, iFan_speed);
			iUpdate = 0;
		}
		
		// Keep track of shutdown time remaining
		tt_LastTimerEventPing = time(NULL);
	};
}

/**
************************************************************************
*
*  function    : parse_configuration()
*
*  description : Parse the configuration file entries.  Depending on the
*				 entry, we set daemon variables on retrieved values.  As
*				 this daemon is to retain a small memory foot-print, only
*				 simple checks are made on retrieved values.
*
*  arguments   : (in)	char*				= pointer to configuration file
*											  contents
*					  
*  returns     : 		void
*
************************************************************************
*/
static void parse_configuration(char* buff)
{
	const char *command[] = {
			"REFRESH",
			"FANSTOP",
			"TEMP-RANGE",
			"MONITOR",
			"HYSTERESIS",
			"DEBUG",
			"LOG",
			"TMP",
			"ON",
			"OFF",
			"SUN", "MON", "TUE", "WED", "THR", "FRI", "SAT",
			"BUTTON"
			};
	int i;
	int j;
	int cmd;
	char bTime=1; /* Specifies time format */
	char* pos;
	char* last; // Used by strtoc_r to point to current token
	long current_time;
	time_t ltime;
	struct tm* decode_time;
	int iHour;
	int iMinutes;
	int iGroup = 0;
	int ilastGroup = 0;
	int iFirstDay=-1;
	int iProcessDay=-1;
	TIMER* pTimer;
	TIMER* pOff;
	TIMER* pOn;
	long iFixer=0;

	// Get time of day
	time(&ltime);

	decode_time = localtime(&ltime);
	s_dst = decode_time->tm_isdst;
	current_time = (decode_time->tm_hour*60) + decode_time->tm_min;
	last_day = decode_time->tm_wday;
#ifdef TEST
	if (override_time) {
		ltime -= (current_time-override_time)*60;
		current_time = override_time;
	}
#endif
	if (buff) {
		// Parse our time requests
		pos = strtok_r(buff, ",=\n", &last);

		/* Now create our timer objects for on and off events */
		pOn = ponTimer = (TIMER*)calloc(sizeof(TIMER), sizeof(char));
		pOff = poffTimer = (TIMER*)calloc(sizeof(TIMER), sizeof(char));

		// To prevent looping
		for (i=0;i<100;i++)
		{
			cmd = -1;
			bTime = 0;

			// Ignore comment lines?
			if ('#' != pos[0]) {
				/* Could return groups, say MON-THR, need to strip '-' out */
				if ('-' == pos[3]) {
					*(last-1)=(char)'='; /* Plug the '0' with token parameter  */
					iGroup = 1;
					last-=8;
					pos = strtok_r(NULL, "-", &last);
				}

				/* Could use a '>' character in the time format */
				else if ('>' == pos[3]) {
					bTime = 1;
					*(last-1)=(char)'=';
					last-=10;
					pos = strtok_r(NULL, ">", &last);
				}

				// Locate our expected commands
				for(cmd=0;cmd<18;cmd++)
					if (strcasecmp(pos, command[cmd]) == 0) break;
					
				pos = strtok_r(NULL, ",=\n", &last);
			}
			else {
				pos = strtok_r(NULL, "\n", &last);

				if (pos) {
					/* After the first remark we have ignored, make sure we detect a valid line
					and move the tokeniser pointer if none remark field */
					if ('#' != pos[0]) {
						j = strlen(pos);
						*(last-1)=(char)'='; /* Plug the '0' with token parameter  */
						last=last-(j+1);

						/* Now lets tokenise this valid line */
						pos = strtok_r(NULL, ",=\n", &last);
					}
				}
			}

			if (!pos)
				break;

			if ('#' == pos[0]) cmd = -1;

			int iTemp = atoi(pos);
			
			// Now parse the setting
			// Excuse the goto coding, not nice but necessary here
			switch (cmd) {
				// Refresh/re-scan time?
				case 0: 
					if (strcasecmp(pos, "OFF") == 0) {
						refreshRate = -1;
						// Ensure that the watchdog is turned off, may have been on before
						system_set_watchdog(255);
					}

					else
						sscanf(pos, "%02d", &refreshRate);

					break;
				// Fan failure stop time before event trigger
				case 1:
					fanFaultSeize = iTemp;
					// Limit to something sensible
					if (fanFaultSeize > 60) fanFaultSeize = 60;
					else if (fanFaultSeize < 1) fanFaultSeize = 1;
					else fanFaultSeize = FAN_SEIZE_TIME;
					break;
				// Get control details
				case 2:
					sscanf(pos, "%02d %02d %02d %02d", &iTempRange[0], &iTempRange[1], &iTempRange[2], &iTempRange[3]);
					break;
				// See if to control fan or not?
				case 3:
					// Default ON
					iControlFan = 1;
					// No monitoring?
					if (strcasecmp(pos, "OFF") == 0)
						iControlFan = 0;
					// Demanded minimum speed?
					else if (iTemp > 0)
						iControlFan = iTemp + 1;
					break;
				case 4:
					iHysteresis = iTemp;
				    // Limit swing
				    if (iHysteresis < 1) iHysteresis = 1;
				    else if (iHysteresis > 5) iHysteresis = 5;
				    break;
				// Get debug settings, do not bother checking level data
				case 5:
					iDebugLevel = iTemp;
					break;
				// Pickup user's log path, no directory checking occurs
				case 6:
					sprintf( log_path, "%s", pos);
					break;
				// Get the tmp/RAM path name, no checking occurs
				case 7:
					sprintf( strTmpPath, "%s", pos);
					break;
				// Get on time
				case 8:
					pTimer = pOn; iHour = iMinutes = 0;
process:
					sscanf(pos, "%02d:%02d", &iHour, &iMinutes);
					if (bTime) {
						iHour+=(int)(iFixer/60);
						iMinutes+=iFixer - ((int)(iFixer/60))*60;
					}

					/* Ensure time entry is valid */
					if ((iHour>=0 && iHour <=48) && (iMinutes >=0 && iMinutes <= 120)) {
						/* Group macro so create the other events */
						if (iGroup!=0) {
							j = iFirstDay-1;
							/* Create the multiple entries for each day in range specified */
							while (j!=iProcessDay) {
								j++;
								if (j>7) j = 0;
								pTimer->day = (char)j;
								pTimer->time = (iHour*60)+iMinutes;
								/* Allocate space for the next event object */
								pTimer->pointer = (void*)calloc(sizeof(TIMER), sizeof(char));
								pTimer = (TIMER*)pTimer->pointer;
							}
						}
						else {
							pTimer->day = iProcessDay;
							pTimer->time = (iHour*60)+iMinutes;
							/* Allocate space for the next event object */
							pTimer->pointer = (void*)calloc(sizeof(TIMER), sizeof(char));
							pTimer = (TIMER*)pTimer->pointer;
						}
					}

					/* Update our pointers */
					if (cmd == 8) pOn = pTimer;
					else pOff = pTimer;

					break;
				// Get on time
				case 9:
					iFixer = current_time;
					/* This relies on correct association of ON/OFF times */
					if (bTime && pOn->pointer)
						iFixer = iHour*60 + iMinutes;

					pTimer = pOff; iHour = 24; iMinutes = 0;
					goto process;
					break;
				/* Macro days in week? */
				case 10:
				case 11:
				case 12:
				case 13:
				case 14:
				case 15:
				case 16:
					/* For groups, */
					iProcessDay = cmd-10;
					/* Remove grouping flag for next defintion */
					ilastGroup += iGroup;
					if  (ilastGroup>2) {
						iGroup = 0;
						ilastGroup = 0;
					}

					if (1 == ilastGroup)
						iFirstDay = iProcessDay;

					break;
				case 17:
					iButtonAction = 0;
					if (strcasecmp(pos, "STANDBY") == 0)
						iButtonAction = 128;
					break;
			}
		}
	}
	
	// Handle standby and wakeup timer
	if (iProcessDay >= 0 && 0 == i_instandby) {
		c_TimerFlag = 1;
		iOffTime = iOnTime = 0;
		GetTime(current_time, poffTimer, &iOffTime);
		// Skip? Yes then plug on time event for message output
		if (c_Skip) {
			// Did we have a on time event before?  If so, plug the time
			if (tOnLastTime)
				iOnTime = 1;
		}
		// No, get next on time event
		else
			GetTime(iOffTime, ponTimer, &iOnTime);

		// Determine shutdown times
		validate_time(ltime);

		/* Destroy the macro timer objects */
		destroyObject(poffTimer);
		destroyObject(ponTimer);
	}
	// Ensure button action is correct if no standby mode
	else
		iButtonAction = 0;
}

/**
************************************************************************
*
*  function    : validate_time()
*
*  description : Determines on and off time messages and updates the
*				 pending time file.
*
*  arguments   : (in)	time_t				= current time
*					  
*  returns     : 		void
************************************************************************
*/
static void validate_time(time_t ltime)
{
	char message[80];
	char twelve = 0;
	time_t tworktime;
	struct tm* decode_time;
	long current_time;
	long offTime = 0;
	long onTime = 0;

	decode_time = localtime(&ltime);
	current_time = (decode_time->tm_hour*60) + decode_time->tm_min;

	/* Time shutdown so check dates, otherwise it is an interval only */
	if (iOffTime < current_time) {
		twelve = 1;
		offTime = ((TWELVEHR + (iOffTime - (current_time - TWELVEHR))) * 60);
	}
	else {
		offTime = ((iOffTime - current_time) * 60);
	}
		
	tworktime = ltime + offTime;
	decode_time = localtime(&tworktime);
	
	sprintf(message, "Standby is set with %02d/%02d %02d:%02d",
		decode_time->tm_mon+1, decode_time->tm_mday, decode_time->tm_hour, decode_time->tm_min);

	// Update the on-time if we have a wake-up event
	if (iOnTime > 0) {
		// are not skipping a current standby event?
		if (!c_Skip) {
			if (iOnTime < current_time) {
				onTime = ((TWELVEHR + (iOnTime - (current_time - TWELVEHR))) * 60);
			}
			else {
				onTime = (iOnTime - current_time) * 60;
				if (twelve) {
					onTime += (TWENTYFOURHR*60);
				}
			}

			// See if a longer sleep period
			if (onTime < offTime) {
				onTime += (TWENTYFOURHR*60);
			}
			
			// Record time
			tOnLastTime = tworktime = ltime + onTime;
		}
		
		decode_time = localtime(&tOnLastTime);

		sprintf(message, "%s-%02d/%02d %02d:%02d", message,
			decode_time->tm_mon+1, decode_time->tm_mday, decode_time->tm_hour, decode_time->tm_min);
	}

	/* Inform standby task of no wakeup */
	else
		tworktime = -1;

	syslog(LOG_INFO, message);

#ifdef TEST		
	printf("%s\n", message);
#endif
	l_TimerEvent = offTime;

	// Update the pending timer system flag if we need too
	if (!c_Skip)
		execute_command2(TIMED_STANDBY, ".", CALL_WAIT, 2, tworktime);
}

/**
************************************************************************
*
*  function    : check_configuration()
*
*  description : Open, read and parse contents of the configuration file.
*				 To limit access, we check to see if the configuration
*				 file has changed since.
*
*  arguments   : (in)	char				= force re-check flag
*					  
*  returns     : 		void
************************************************************************
*/
static void check_configuration(char iForce)
{
	char buff[4096];
	int iRead;
	int errno;
	struct stat filestatus;
	int file;
	int i;

	errno = stat(micro_conf, &filestatus);
	
	/* If exists? */
	if (0 == errno) {

		// Has this file changed?
		if (filestatus.st_mtime != tt_LastMicroAcess || iForce) {
			file = open(micro_conf, O_RDONLY);

			if (file) {
				iRead = read(file, &buff, 4095);

				// Dump the file pointer for others
				close(file);

				if (iRead>0) {
					/* Remove Windows End-of-Line formatting */
					for (i=0;i<iRead;i++)
						if (buff[i] == 0x0D)
							buff[i] = 0x20;
							
					parse_configuration(buff);
				}
			}
		}

		/* Update our lasttimes timer file access */
		tt_LastMicroAcess = filestatus.st_mtime;
	}
}

/**
************************************************************************
*
*  function    : main()
*
*  description : Processes input demands.
*
*  arguments   : (in)	int				= number of commands
*  						char*			= Pointer to supplied tokens
*					  
*  returns     : 		void
*
************************************************************************
*/
int main(int argc, char *argv[])
{
	int iLen;
	int i;
	unsigned long ulMessage;
	char *thisarg;
	char iNotQuiet=1;
	unsigned char* uiDemand = (unsigned char*)&ulMessage;
	unsigned char uiMessage[10] = {0,};
	char* pos = NULL;
	int iSetPriority = -4;

	argc--;
	argv++;

	// Generate unique key.  This will fail with stock so let it be.
	if ((mutex = ftok(micro_conf, 'M')) == (key_t) -1) {
	    printf("IPCS: Error, falling back to 'flock'\n");
		mutex = 0;
	}

	// Parse any options
	while (argc >= 1 && '-' == **argv) {
		thisarg = *argv;
		thisarg++;
		switch (*thisarg) {
#ifdef TEST
		case 't':
			argc--;
			argv++;
			override_time = atoi(*argv);
			break;			
#endif
		case 'p':
			argc--;
			argv++;
			iSetPriority = atoi(*argv);
			break;
		case 'w':
			argc--;
			argv++;
			i_instandby = 1;
			// Up to caller to ensure a sensible time here.
			l_TimerEvent = atoi(*argv);
			c_TimerFlag = 1;
			break;;
		case 'e':
			argc--;
			argv++;
			i_instandby = 1;
			break;;
		case 'c':
			--argc;
			i_debug = 1;
			break;
		case 'v':
			--argc;
			printf("%s %s\n", strVersion, VERSION);
			exit(0);
			break;
		case 'q':
			--argc;
			iNotQuiet = 0;
			break;
		case 's':
			argc--;
			argv++;
			// Grab the mutex, -1 will indicate no server.  Use a local lock flag
			// so we can maintain a lock on the resource whilst processing any
			// batched commands
			if (mutex >0)
				mutexId = semget(mutex, 1, 0666);
			else {
				resourceLock_fd = open(micro_lock, O_WRONLY|O_CREAT, 0700);
			}

			// Allocate device
			open_serial();
			// Loop through batched commands
			pos = strtok(*argv, ",");
			while (pos != 0) {
				// Get command length
				iLen = strlen(pos)/2;
				// Get the HEX command
				ulMessage = strtoul(pos, NULL, 16);
				// Byte rotate please
				for (i=0;i<iLen;i++)
					uiMessage[i] = uiDemand[iLen-i-1];
				// Push it out and return result
				i = writeUART(iLen, uiMessage);
				if (iNotQuiet)
					printf("%d\n", i);
				// Locate anymore commands?
				pos = strtok(NULL, ",");
			};
				
			exit(0);
			break;
		}

		argc--;
		argv++;
	}

	open_serial();
	
	setpriority(PRIO_PROCESS, 0, iSetPriority);
	
	if (!i_debug) {
		// Run in background?
		if(daemon(0, 0) != 0) {
			exit(-1);
		}
		
		/* Set up termination handlers */
		signal(SIGTSTP, SIG_IGN); /* ignore tty signals */
		signal(SIGCHLD, SIG_IGN);
		signal(SIGTERM, termination_handler);
		signal(SIGINT, termination_handler);
	}

	signal(SIGHUP, termination_handler);
	signal(SIGCONT, termination_handler);

	/* make child session leader */
	setsid();

	/* clear file creation mask */
	umask(0);

	// Lock out device resource
	getResourceLock();
	
	// Check configuration and establish the tmp paths
	i_instandby++;
	check_configuration(0);
	i_instandby--;

	// Ensure that our script is copied to RAMDISK first
	execute_command(CP_SCRIPT, 0, CALL_WAIT);

	/* Create pid file */
	execute_command2(CREATE_PID, ".", CALL_WAIT, 0, getpid());

	// Force another update to establish standby timers
	check_configuration(1);
	
	// Go do our thing
	micro_evtd_main();

	return 0;
}

/**
************************************************************************
*
*  function    : destroyObject()
*
*  description : Free the memory and destroy the pointer object,
*
*  arguments   : (in)	TIMER*			= pointer to timer object
*					  
*  returns     : void
*
************************************************************************
*/
static void destroyObject(TIMER* pTimer)
{
	/* Destroy this object by free-ing up the memory we grabbed through calloc */
	TIMER* pObj;

	/* Ensure valid pointer */
	if (pTimer) {
		/* Let's destroy and free our objects */
		for (pObj = pTimer->pointer;NULL != pObj;pObj = pTimer->pointer) {
			if (pObj != NULL) {
				free (pTimer);
				pTimer = NULL;
				pTimer = pObj;
			}
		}

		pTimer = NULL;
	}
}

/**
************************************************************************
*
*  function    : FindNextToday()
*
*  description : Find the next valid time object from the 'timeNow' for
*				 the current day.
*
*  arguments   : (in)	long				= time to scan against
*						TIMER*				= pointer to timer object
*						long*				= pointer to located time
*					  
*  returns     : 		char				= located valid time entry
*											  flag, 0=NO, 1=YES
*
************************************************************************
*/
static char FindNextToday(long timeNow, TIMER* pTimer, long* time)
{
	/* Scan macro objects for a valid event from 'time' today */
	char iLocated = 0;

	while(pTimer != NULL && pTimer->pointer != NULL) {
		if (pTimer->day == last_day && pTimer->time > timeNow) {
			/* See if we have a time specified before this first located time */
			if (iLocated) {
				if (*time > pTimer->time) {
					*time = pTimer->time;
				}
			}
			else {
				/* Next event for today?, at least 1 minute past current */
				iLocated++;
				*time = pTimer->time;
			}
		}

		pTimer = pTimer->pointer;
	}

	return iLocated;
}

/**
************************************************************************
*
*  function    : FindNextDay()
*
*  description : Find the next valid time object from the 'timeNow' from
*				 the current day.
*
*  arguments   : (in)	long				= time to scan against
*						TIMER*				= pointer to timer object
*						long*				= pointer to located time
*						long*				= pointer to day differance (seconds)
*					  
*  returns     : 		char				= located valid time entry
*											  flag, 0=NO, 1=YES
*
************************************************************************
*/
static char FindNextDay(long timeNow, TIMER* pTimer, long* time, long* offset)
{
	/* Locate the next valid event */
	char iLocated = 0;

	while(pTimer != NULL && pTimer->pointer != NULL) {
		/* Next event for tomorrow onwards? */
		if (pTimer->day > last_day) {
			/* Grouped events?, ie only tomorrow */
			if (pTimer->day > last_day) {
				*offset = (pTimer->day - last_day) * TWENTYFOURHR;
			}
			iLocated++;
			*time = pTimer->time;
			break;
		}

		pTimer = pTimer->pointer;
	}
	
	return iLocated;
}

/**
************************************************************************
*
*  function    : GetTime()
*
*  description : Get the next valid time object.
*
*  arguments   : (in)	long				= time to scan against
*						TIMER*				= pointer to timer object
*						long*				= pointer to located time
*					  
*  returns     : 		void
************************************************************************
*/
static void GetTime(long timeNow, TIMER* pTimerLocate, long* time)
{
	/* Get next timed macro event */
	long lOffset=0;
	char onLocated=0;
	TIMER* pTimer;

	/* Ensure that macro timer object is valid */
	if (pTimerLocate && pTimerLocate->pointer != NULL) {
		pTimer = pTimerLocate;
		/* Next event for today */
		onLocated = FindNextToday(timeNow, pTimer, time);

		/* Failed to find a time for today, look for the next power-up time */
		if (0 == onLocated) {
			pTimer = pTimerLocate;
			onLocated = FindNextDay(timeNow, pTimer, time, &lOffset);
		}

		/* Nothing for week-end, look at start */
		if (0 == onLocated) {
			*time = pTimerLocate->time;
			lOffset = ((6 - last_day) + pTimerLocate->day) * TWENTYFOURHR;
			lOffset += TWENTYFOURHR;
		}

		*time += lOffset;
	}
}
