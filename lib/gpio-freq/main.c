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

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <sched.h>
//#include <pthread.h>

#include <sys/io.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include <sys/inotify.h>

#include "global.h"
#include "gpio_fcntl.h"
//#include "file.h"


/*
 * 
 */

//pthread_mutex_t mutex1 = PTHREAD_MUTEX_INITIALIZER;

/* using clock_nanosleep of librt */
extern int clock_nanosleep(clockid_t __clock_id, int __flags,
        __const struct timespec *__req,
        struct timespec *__rem);

static inline void tsnorm(struct timespec *ts) {
    while (ts->tv_nsec >= NSEC_PER_SEC) {
        ts->tv_nsec -= NSEC_PER_SEC;
        ts->tv_sec++;
    }
}

void setPriority(struct sched_param *param, int __sched_priority) {
    param->sched_priority = __sched_priority;
    // Enable realtime fifo scheduling.
    if (sched_setscheduler(0, SCHED_FIFO, param) == -1) {
        perror("Error: sched_setscheduler failed.");
        exit(-1);
    }
}

//int blink(struct timespec * timer, gpio_t gpio, int interval) {
//    int i;
//    for (i = 0; i < 100; i++) {
////        if (event.mask & IN_MODIFY) {
////            printf("file was modified %s\n", event.name);
////        }
//
//        clock_nanosleep(0, TIMER_ABSTIME, &timer, NULL);
//        gpioSetValue(&gpio, i % 2);
//        timer.tv_nsec += interval;
//        tsnorm(&timer);
//    }
//}

int main(int argc, char** argv) {


    int i;
    clock_t t1, t2;
    gpio_t gpio_led1 = {"GPIO138 led1", 138, "out"};
    pthread_t thread1, thread2;
    int rc1, rc2;

    struct timespec timer;
    struct sched_param param;
    int interval = 5000; // 50000ns = 50us, cycle duration = 100us
    struct inotify_event event;

    setPriority(&param, 99);

    printf("hallo welt\n");
    gpioExport(&gpio_led1);
    gpioDir(&gpio_led1, 1);
    gpioOpenValue(&gpio_led1);

    clock_gettime(0, &timer); // Get current time.
    timer.tv_sec++; // Start after one second.

    t1 = clock();

        t1 = clock();
//    for (i = 0; i < 1000000; i++) {
	while (1) {
	i++;
        clock_nanosleep(0, TIMER_ABSTIME, &timer, NULL);
        gpioSetValue(&gpio_led1, i % 2);
        timer.tv_nsec += interval;
        tsnorm(&timer);
    }
    t2 = clock();
    
    
    t2 = clock();
    printf("needed %f s for %d runs\n", ((float) t2 - (float) t1) / 1000000.0F, i);

    gpioCloseValue(&gpio_led1);
    gpioUnexport(&gpio_led1);
    printf("hallo schwarzes loch\n");

    return 0;
}
