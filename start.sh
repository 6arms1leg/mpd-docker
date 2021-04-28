#!/bin/sh

PROG=/usr/bin/mpd
PUSR=mpd
PHOME=/${PUSR}
PCONFIG=${PHOME}/mpd.conf

# Minimum UID/GID allowed
ID_MIN_ALLOWED=1000

# Print UID and GID for confirmation
echo "PUID:${PUID}"
echo "PGID:${PGID}"

# Sanity check on UID/GID
if [ "${PUID}" -lt "${ID_MIN_ALLOWED}" ]; then
    echo "PUID cannot be \< ${ID_MIN_ALLOWED}"
    exit 1 # Fail
fi

if [ "${PGID}" -lt "${ID_MIN_ALLOWED}" ]; then
    echo "PGID cannot be \< ${ID_MIN_ALLOWED}"
    exit 1 # Fail
fi

# The installation of the `MPD` package already adds an `mpd` user.  It must be
# removed in order to recreate the `audio` group and the `mpd` user.
# (See next steps.)
deluser ${PUSR}

# Detect and use `audio` GID from `/dev/snd/timer`
AGID=$(stat -c %g /dev/snd/timer)
delgroup audio
addgroup -g ${AGID} audio

# Create user with provided UID:GID
addgroup -g ${PGID} ${PUSR}
adduser -D -h ${PHOME}/ -G ${PUSR} -u ${PUID} ${PUSR}
adduser ${PUSR} audio
chown ${PUSR}:${PUSR} ${PHOME}/

# Start the service
exec su -l ${PUSR} -s /bin/sh -c "${PROG} --stdout --no-daemon ${PCONFIG}"
