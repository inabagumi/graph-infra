FROM golang:1.13.6-alpine3.10 as build

WORKDIR /go/src/app

COPY . .

RUN set -ex \
  && go mod download \
  && go build -o worker main.go

FROM alpine:3.11

COPY --from=build /go/src/app/worker /usr/local/bin/worker

RUN set -ex \
  && apk --update-cache add ca-certificates

CMD ["/usr/local/bin/worker"]
