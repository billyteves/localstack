FROM maven:alpine

LABEL authors="Waldemar Hummer (whummer@atlassian.com), Gianluca Bortoli (giallogiallo93@gmail.com)"

# install general packages
RUN apk update && \
    apk add --update autoconf automake build-base ca-certificates git libffi-dev libtool make nodejs openssl openssl-dev python python-dev py-pip supervisor zip && \
    update-ca-certificates

# set workdir
RUN mkdir -p /opt/code/localstack
WORKDIR /opt/code/localstack/

# init environment and cache some dependencies
ADD requirements.txt .
RUN wget -O /tmp/localstack.es.zip https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.3.0.zip && \
    (pip install --upgrade pip) && \
    (test `which virtualenv` || \
        pip install virtualenv || \
        sudo pip install virtualenv) && \
    (virtualenv .testvenv && \
        source .testvenv/bin/activate && \
        pip install -r requirements.txt && \
        rm -rf .testvenv)

# add files required to run "make install-web"
ADD Makefile .
ADD localstack/dashboard/web/package.json localstack/dashboard/web/package.json

# install web dashboard dependencies
RUN make install-web

# add files required to run "make install"
RUN mkdir -p localstack/utils/kinesis/ && touch localstack/__init__.py localstack/utils/__init__.py localstack/utils/kinesis/__init__.py
ADD localstack/utils/kinesis/ localstack/utils/kinesis/
ADD localstack/utils/common.py localstack/utils/common.py
ADD localstack/constants.py localstack/constants.py

# install dependencies
# TODO: temporary change to fix error "Cannot find module 'semver'" when running npm
RUN make install && \
    rm -rf /usr/lib/node_modules && apk del nodejs && apk add --update nodejs && npm install npm@latest -g

# add files required to run "make init"
ADD localstack/mock/__init__.py localstack/mock/__init__.py
ADD localstack/mock/install.py localstack/mock/install.py

# initialize installation (downloads remaining dependencies)
RUN make init

# add rest of the code
ADD localstack/ localstack/

# fix some permissions
RUN mkdir -p /.npm && \
    mkdir -p localstack/infra/elasticsearch/data && \
    chmod 777 . && \
    chmod 755 /root && \
    chmod -R 777 /.npm && \
    chmod -R 777 localstack/infra/elasticsearch/data && \
    chmod -R 777 localstack/infra/elasticsearch/logs

# install supervisor daemon & copy config file
ADD supervisord.conf /etc/supervisord.conf

# add files for web dashboard
ADD bin/localstack bin/localstack

# expose default environment (required for aws-cli to work)
ENV AWS_ACCESS_KEY_ID=foobar \
    AWS_SECRET_ACCESS_KEY=foobar \
    AWS_DEFAULT_REGION=us-east-1 \
    MAVEN_CONFIG=/opt/code/localstack \
    USER=docker

# assign random user id
USER 24624336

# run tests (to verify the build before pushing the image)
ADD tests/ tests/
RUN make test

# expose service & web dashboard ports
EXPOSE 4567-4578 8080

# define command at startup
ENTRYPOINT ["/usr/bin/supervisord"]
