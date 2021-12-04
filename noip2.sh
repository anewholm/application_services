#!/bin/bash

case "$1" in
    start)
        /usr/local/bin/noip2
    ;;
    
    stop)
        killall noip2
    ;;
    
    restart)
        killall noip2
        /usr/local/bin/noip2
    ;;
esac

exit 0
