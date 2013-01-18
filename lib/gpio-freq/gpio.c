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
#include "global.h"
#include "gpio.h"

int testprint() {
    printf("XXXXXXXXXXXXXXXXXXXXXXXXXXX\n");
    return 1;
}

int gpioOpenValue(gpio_t *gpio) {
    snprintf(gpio->path, DIMCHAR, "%sgpio%d/value", PATH, gpio->id);
    gpio->fp = fileopen(gpio->path, "w", "value");
    return 1;
}

int gpioCloseValue(gpio_t * gpio) {
    fileclose(gpio->fp, "value");
    gpio->fp=NULL;
    return 1;
}

int gpioExport(gpio_t *gpio) {
    snprintf(gpio->path, DIMCHAR, "%sexport", PATH);
    gpio->fp = fileopen(gpio->path, "w", "export");
    fprintf(gpio->fp, "%d", gpio->id);
    fileclose(gpio->fp, "export");
    gpio->fp=NULL;
    return 1;
}

int gpioDir(gpio_t *gpio) {
    snprintf(gpio->path, DIMCHAR, "%sgpio%d/direction", PATH, gpio->id);
    gpio->fp = fileopen(gpio->path, "w", "direction");
    fprintf(gpio->fp, "out");
    fileclose(gpio->fp, "direction");
    gpio->fp=NULL;
    return 1;
}

int gpioSetValue(gpio_t *gpio, unsigned short int value) {
    fprintf(gpio->fp, "%d", value);
    return 1;
}

int gpioUnexport(gpio_t *gpio) {
    snprintf(gpio->path, DIMCHAR, "%sunexport", PATH);
    gpio->fp = fileopen(gpio->path, "w", "unexport");
    fprintf(gpio->fp, "%d", gpio->id);
    fileclose(gpio->fp, "unexport");
    gpio->fp=NULL;
    return 1;
}

gpioSwapValue(gpio_t *gpio) {
    static int tmp;
    snprintf(gpio->path, DIMCHAR, "%sgpio%d/value", PATH, gpio->id);
    gpio->fp = fileopen(gpio->path, "w", "value");
    fscanf(gpio->fp, "%d", &tmp);
    //fread((void *)tmp, sizeof(int), 1, gpio->fp);
    printf("%d\n", tmp);
    //fprintf(gpio->fp, "%d", tmp%2);
    fileclose(gpio->fp, "value");
    return 1;
}
