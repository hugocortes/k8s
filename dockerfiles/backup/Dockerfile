FROM alpine:3.9.6

RUN apk update
RUN apk add curl
RUN apk add mongodb-tools
RUN apk add mysql-client
RUN apk add postgresql

ENV IS_ISTIO="false"
ENV MONGODB_ENABLED="false"
ENV MYSQL_ENABLED="false"
ENV PGENABLED="false"

WORKDIR /root
COPY backup.sh .

ENTRYPOINT [ "/bin/sh" ]
CMD [ "./backup.sh" ]
