#!/bin/sh

# Import Joplin configuration from JSON, if present in /secrets volume
# readonly JOPLIN_CONFIG_JSON="/secrets/joplin-config.json"
if [ -f $JOPLIN_CONFIG_JSON ]; then
    echo "Importing Joplin configuration from $JOPLIN_CONFIG_JSON"
    echo "  ... after forcing api.port=41184"
    jq '."api.port" = 41184' <$JOPLIN_CONFIG_JSON | gosu node joplin config --import || exit
else
    echo "$JOPLIN_CONFIG_JSON does not exist; using default Joplin config"
fi

# https://joplinapp.org/terminal/#synchronisation
JOPLIN_SYNC_LOG="/var/log/joplin-sync.log"
cat > /etc/cron.d/joplin-sync <<EOF
PATH=$PATH
*/5 * * * * node joplin sync >> $JOPLIN_SYNC_LOG 2>&1
EOF
touch $JOPLIN_SYNC_LOG
chown node:node $JOPLIN_SYNC_LOG
echo "Periodic \"joplin sync\" cron job logs to $JOPLIN_SYNC_LOG"

# Forward external port 80 to Joplin server on 127.0.0.1:41184
SOCAT_LOG="/var/log/socat.log"
socat -d -d -lf $SOCAT_LOG TCP-LISTEN:80,fork TCP:127.0.0.1:41184 &
cat <<EOF
Forwarding 0.0.0.0:80 => localhost:41184 (Joplin Clipper server) via socat
  ... logging to $SOCAT_LOG
EOF

# Set up log rotation for both joplin and socat
cat > /etc/logrotate.d/joplin <<EOF
$JOPLIN_SYNC_LOG
$SOCAT_LOG
{
    weekly
    rotate 8
    size 10M
    compress
    delaycompress
    notifempty
}
EOF

# Start cron
service cron start

exec gosu node "$@"
