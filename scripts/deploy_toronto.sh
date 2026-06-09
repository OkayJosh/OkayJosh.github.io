#!/bin/bash

set -euo pipefail

BRANCH=${1:-staging-main}
APP_TO_MIGRATE=${2:-}

SSH_KEY="/home/okayjosh/.ssh/expedier"
SERVER="okayjosh2@34.19.179.228"

ssh -i "$SSH_KEY" "$SERVER" "bash -s" -- "$BRANCH" "$APP_TO_MIGRATE" << 'EOF'

set -euo pipefail

BRANCH=${1:-staging-main}
APP_TO_MIGRATE=${2:-}

echo "[$(date)] Starting deployment to Mobile Server"
echo "Target branch: $BRANCH"

cd /expedier/toronto

echo "Fetching and checking out branch..."
sudo git fetch --all
sudo git reset --hard HEAD
sudo git checkout "$BRANCH"
sudo git reset --hard "origin/$BRANCH"

if [ -n "$APP_TO_MIGRATE" ]; then
    echo "Running migrations for app: $APP_TO_MIGRATE..."
    source /expedier/env/bin/activate
    python manage.py migrate "$APP_TO_MIGRATE"
else
    echo "No app specified for migration. Skipping migrations."
fi

echo "Restarting gunicorn..."
sudo systemctl restart gunicorn

echo "Fixing Celery directories..."
sudo mkdir -p /var/run/celery /var/log/celery
sudo chown -R okayjosh2:okayjosh2 /var/run/celery /var/log/celery

echo "Restarting celery services..."
sudo ./scripts/celery_deamon_setup.sh restart

echo "Verifying services..."

sudo systemctl is-active gunicorn
sudo systemctl is-active celery
sudo systemctl is-active celerybeat

echo "[$(date)] Deployment completed successfully"

EOF
