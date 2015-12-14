//Copyright 2015 Денис Крыськов
//License: Lesser GNU General Public License (LGPL-3)

#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <string.h>
#include <unistd.h>

// stackoverflow.com/questions/1196418/
//  getting-a-password-in-c-without-using-getpass-3
char *
getpass(const char *prompt) {
    struct termios oflags, nflags;
    static char b[5+PASS_MAX];

    /* disabling echo */
    tcgetattr(fileno(stdin), &oflags);
    nflags = oflags;
    nflags.c_lflag &= ~ECHO;
    nflags.c_lflag |= ECHONL;

    if (tcsetattr(fileno(stdin), TCSANOW, &nflags) != 0) {
        perror("tcsetattr 0");
        return 0;
    }

    printf(prompt);
    fgets(b, 1+PASS_MAX, stdin);
    // Not sure if line below is correct for Unicode-capable terminal
    b[strlen(b) - 1] = 0;

    /* restore terminal */
    if (tcsetattr(fileno(stdin), TCSANOW, &oflags) != 0) {
        perror("tcsetattr 1");
        return 0;
    }

    return b;
}

// if you think this subroutine is buggy, send bug-report 
