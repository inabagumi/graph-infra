FROM golang:1.13.10-alpine3.10 as build

WORKDIR /go/src/worker
ADD . /go/src/worker

RUN set -ex \
  && go mod download \
  && go build -o /go/bin/worker main.go

FROM gcr.io/distroless/base
COPY --from=build /go/bin/worker /usr/local/bin/worker
CMD ["/usr/local/bin/worker"]
