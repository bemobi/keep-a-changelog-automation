FROM alpine:3.9

RUN apk update && apk add --no-cache --upgrade git bash curl make grep jq

COPY pipe Makefile /
COPY scripts /scripts
COPY LICENSE.txt pipe.yml *.md /
RUN wget --no-verbose -P / https://bitbucket.org/bitbucketpipelines/bitbucket-pipes-toolkit-bash/raw/0.6.0/common.sh

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]
