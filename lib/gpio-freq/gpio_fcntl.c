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

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#include "global.h"
#include "gpio_fcntl.h"
#include "file.h"

char buffer[DIMCHAR];

/*
 * ###########################################################################
 * export gpio
 * ###########################################################################
 */
int gpioExport(gpio_t *gpio) {
    snprintf(buffer, DIMCHAR, "%d", gpio->id);
    gpio->fd = fcntlOpen(EXPORT, O_WRONLY | O_NDELAY, 0);
    write(gpio->fd, buffer, strlen(buffer));
    fcntlClose(gpio->fd);
    snprintf(gpio->path, DIMCHAR, "%sgpio%d/", PATH, gpio->id);

    return errno;
}

/*
 * ###########################################################################
 * unexport gpio
 * ###########################################################################
 */
int gpioUnexport(gpio_t *gpio) {
    snprintf(buffer, DIMCHAR, "%d", gpio->id);
    gpio->fd = fcntlOpen(UNEXPORT, O_WRONLY | O_NDELAY, 0);
    write(gpio->fd, buffer, strlen(buffer));
    fcntlClose(gpio->fd);
    snprintf(gpio->path, DIMCHAR, "\0");

    return errno;
}

/*
 * ###########################################################################
 * set gpio direction in/out
 * ###########################################################################
 */
int gpioDir(gpio_t *gpio, int dir) {
    snprintf(buffer, DIMCHAR, "%sdirection", gpio->path);
    gpio->fd = fcntlOpen(buffer, O_WRONLY | O_NDELAY, 0);

    if (dir >= 0) {
        snprintf(buffer, DIMCHAR, "%s", "out");
    } else {
        snprintf(buffer, DIMCHAR, "%s", "in");
    }
    write(gpio->fd, buffer, strlen(buffer));
    fcntlClose(gpio->fd);

    return errno;
}

/*
 * ###########################################################################
 * write 1/0
 * ###########################################################################
 */
int gpioSetValue(gpio_t *gpio, unsigned short int value) {
    snprintf(buffer, DIMCHAR, "%d", value);
    write(gpio->fd, buffer, strlen(buffer));

    return errno;
}

int gpioSwapValue(gpio_t *gpio) {
    return errno;
}

int gpioOpenValue(gpio_t *gpio) {
    snprintf(buffer, DIMCHAR, "%svalue", gpio->path);
    gpio->fd = fcntlOpen(buffer, O_WRONLY | O_NDELAY, 0);

    return errno;
}

int gpioCloseValue(gpio_t *gpio) {
    fcntlClose(gpio->fd);
    return errno;
}

int testprint() {
    return 1;
}
