#############      builder       #############
FROM golang:1.15.4 AS builder
ARG RELEASE=false
ARG QUALIFIER=dev
WORKDIR /go/src/example
COPY . .
RUN make build "RELEASE=$RELEASE" "QUALIFIER=$QUALIFIER"
#############      image     #############
FROM scratch AS image
COPY --from=builder /go/bin/echo-server /echo-server
ENTRYPOINT [ "/echo-server" ]
