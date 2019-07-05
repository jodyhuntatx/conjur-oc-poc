# Main container
FROM alpine:3.9

RUN apk add --no-cache bash \
                       jq \
                       wget

ENV CONJUR_VERSION=5 \
    CONTAINER_MODE=init

COPY authenticator \
     get-seedfile.sh \
     start-follower-docker-master.sh \
     start-follower-oc-master.sh /usr/bin/

RUN chmod +x /usr/bin/get-seedfile.sh \
             /usr/bin/start-follower-docker-master.sh \
             /usr/bin/start-follower-oc-master.sh

CMD ["get-seedfile.sh"]
