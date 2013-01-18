/*
* Copyright (C) 2012/2013  Imran Shamshad <sid@projekt-turm.de>
* 
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* any later version.
* 
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <sys/inotify.h>
#include <fcntl.h>
#include <errno.h>

#include "global.h"
#include "file.h"

/*
 * ###########################################################################
 * stdio.h file implementation
 * ###########################################################################
 */
FILE * fileOpen(const char *filename, const char *modes, const char *message) {
    static FILE *fp;
#ifdef DEBUGFILE
    printf("\ttry to open:\t%s\n", filename);
#endif
    if (((fp = fopen(filename, modes)) == NULL)) {
        printf("\t\tPANIC: Could not open file %s\n", message);
#ifndef DEBUGGPIO
        exit(-1);
    }
#endif
#ifdef DEBUGFILE
    printf("\t\topen successful\n");
#endif
    return fp;
}

int fileClose(FILE *fp, const char *message) {
    if (fclose(fp) == EOF) {
        printf("\t\tWARNING: Could not close:\t%s\n", message);
    }
    return 0;
}

/*
 * ###########################################################################
 * fcntl.h file implementation
 * ###########################################################################
 */

int fcntlOpen(const char *__file, int __oflag, mode_t __mode) {
    static int fd;
    if ((fd = open(__file, __oflag, __mode)) == -1) {
        printf("ERROR: fcntlOpen: could not open %s@%d\n", __file, fd);
        exit(-1);
    } else if ((errno = !NULL)) {
        printf("WARNING: fcntlOpen: %s\terrno: %d\n", __file, errno);
        printf("\tshould be fixed!\n");
    }
    return fd;
}

int fcntlClose(int fd) {
    if (close(fd) == -1) {
        printf("ERROR: fcntlClose: could close: errno: %d\n", errno);
        exit(-1);
    }
    return 0;
}

/*
 * ###########################################################################
 * sys/inotify.h file watch implementation
 * ###########################################################################
 */
int watchFile(struct inotify_event *event) {
    static int fd;
    
    if ((fd = inotify_init()) <0) {
        printf("ERROR: watchfile: errno: %d\n", errno);
    }
    printf("\tfd: %d\n", fd);
    event->wd = inotify_add_watch(fd, "/sys/class/gpio/gpio138/value", IN_MODIFY);
    printf("\twd: %d\n", event->wd);
}
