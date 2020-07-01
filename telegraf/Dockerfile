FROM golang:1.14.4-stretch as build

RUN go get -u github.com/inabagumi/youtube-telegraf-plugin/cmd/youtube-telegraf-plugin

FROM telegraf:1.14.5

COPY --from=build /go/bin/youtube-telegraf-plugin /usr/local/bin

ENTRYPOINT ["/entrypoint.sh"]
CMD ["telegraf"]
