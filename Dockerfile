FROM debian:testing

MAINTAINER Guillaume Simonneau <simonneaug@gmail.com>
LABEL Descritpion="mongodb roccksdb mongo mongod mongos mongotools bsondump mongodump mongorestore mongoimport mongoexport mongostat mongofiles mongooplog mongotop"

COPY ./src/setup/ /run/setup/
RUN chmod +x -R /run

RUN sh /run/setup/install_mongoserver.sh 
RUN sh /run/setup/install_mongotools.sh

COPY ./src /run
RUN chmod +x -R /run \
&&  mkdir -p /config


# configuration and startup
ENV AUTH="n" \
    ADMIN_USER="admin" \
    ADMIN_PWD="changeme" \
    DATA_PATH="/data/db" \
    DB_NAME="" \
    DB_USER="user" \
    DB_PWD="changeme" \
    OPLOG_SIZE=50 \
    RS_NAME="" \
    STORAGE_ENGINE="wiredTiger" \
    MASTER=$HOSTNAME \
    SLAVES="" \
    ARBITRERS="" \
    SLAVE_OK="y" \
    SHARD_SVR="n" \
    CONFIG_SVR="n" \
    CONFIG_SERVERS="" \
    SHARDS=""
    
ENTRYPOINT ["/run/entrypoint.sh"]
