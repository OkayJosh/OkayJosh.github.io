#!/bin/bash

# Default to tailing all relevant services
SERVICE="all"

if [ "$1" != "" ]; then
    SERVICE=$1
fi

echo "Connecting to 34.19.179.228 to tail logs for: $SERVICE..."

case $SERVICE in
    "gunicorn")
        ssh -t -i "/home/okayjosh/.ssh/expedier" okayjosh2@34.19.179.228 "sudo journalctl -u gunicorn -f"
        ;;
    "celery")
        ssh -t -i "/home/okayjosh/.ssh/expedier" okayjosh2@34.19.179.228 "sudo tail -f /var/log/celery/w1*.log /var/log/celery/beat.log"
        # Or using journalctl: "sudo journalctl -u celery -u celerybeat -f"
        ;;
    "all"|*)
        # Tails gunicorn and celery services via journalctl
        ssh -t -i "/home/okayjosh/.ssh/expedier" okayjosh2@34.19.179.228 "sudo journalctl -u gunicorn -u celery -u celerybeat -f"
        ;;
esac
