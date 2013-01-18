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

#ifndef FILE_H
#define	FILE_H

FILE * fileOpen(const char *filename, const char *modes, const char *message);
int fileClose(FILE *fp, const char *message);
int fcntlOpen(const char *__file, int __oflag, mode_t __mode);
int fcntlClose(int fd);

int watchFile();

#endif	/* FILE_H */

