FROM alpine:edge

LABEL maintainer="sixarms1leg"
LABEL name="mpd"
LABEL description="MPD with UID/GID + audio GID handling"

RUN apk add --no-cache \
        mpc \
        mpd \
        sqlite-libs

WORKDIR /mpd/

COPY ./start.sh /
COPY ./mpd.conf.template ./mpd.conf
RUN chmod u+x /start.sh

EXPOSE 6600

# `/mpd/mpd.conf` and `/mpd/music/` should also be mounted as volumes later
# when running the Docker container
VOLUME ["/mpd/.mpd/"]

# Set working directory to MPD’s music directory root, so
# `mpc update <RELATIVE_PATH>` (run interactively inside the Docker container)
# has autocompletion for selective path database updates
WORKDIR /mpd/music/

# If health check fails, `exit 1` (fail)
HEALTHCHECK CMD su -l mpd -s /bin/sh -c \
        "mpc status -q > /dev/null 2>&1 || exit 1"

CMD ["sh", "/start.sh"]
