FROM alpine:3.16 AS download-deps

ENV TWITCH_TELEGRAF_PLUGIN_VERSION 1.0.0
ENV TWITCH_TELEGRAF_PLUGIN_SHA256 7976a8809c89f6ab7cee570a0a0f4b9e114de5e421ddd55ed7b76bf1d165420c

ENV TWITTER_TELEGRAF_PLUGIN_VERSION 1.0.0
ENV TWITTER_TELEGRAF_PLUGIN_SHA256 ef13d11feeb13ebe0946fdca4b5225af10bee3feb32d57fc8fc948c2a25e8fbc

ENV YOUTUBE_TELEGRAF_PLUGIN_VERSION 1.1.1
ENV YOUTUBE_TELEGRAF_PLUGIN_SHA256 70d614897ac86b86748708941058205bf66c4d2dac3a109de25d3f9c3ca5b088

RUN set -x \
	\
	&& wget \
		-O twitch-telegraf-plugin.tar.gz \
		https://github.com/inabagumi/twitch-telegraf-plugin/releases/download/v${TWITCH_TELEGRAF_PLUGIN_VERSION}/twitch-telegraf-plugin-${TWITCH_TELEGRAF_PLUGIN_VERSION}_linux_amd64.tar.gz \
	&& echo "$TWITCH_TELEGRAF_PLUGIN_SHA256 *twitch-telegraf-plugin.tar.gz" | sha256sum -c \
	&& mkdir -p /usr/src/twitch-telegraf-plugin \
	&& tar -xzf twitch-telegraf-plugin.tar.gz -C /usr/src/twitch-telegraf-plugin \
	&& rm twitch-telegraf-plugin.tar.gz \
	\
	\
	&& wget \
		-O twitter-telegraf-plugin.tar.gz \
		https://github.com/inabagumi/twitter-telegraf-plugin/releases/download/v${TWITTER_TELEGRAF_PLUGIN_VERSION}/twitter-telegraf-plugin-${TWITTER_TELEGRAF_PLUGIN_VERSION}_linux_amd64.tar.gz \
	&& echo "$TWITTER_TELEGRAF_PLUGIN_SHA256 *twitter-telegraf-plugin.tar.gz" | sha256sum -c \
	&& mkdir -p /usr/src/twitter-telegraf-plugin \
	&& tar -xzf twitter-telegraf-plugin.tar.gz -C /usr/src/twitter-telegraf-plugin \
	&& rm twitter-telegraf-plugin.tar.gz \
	\
	&& wget \
		-O youtube-telegraf-plugin.tar.gz \
		https://github.com/inabagumi/youtube-telegraf-plugin/releases/download/v${YOUTUBE_TELEGRAF_PLUGIN_VERSION}/youtube-telegraf-plugin-${YOUTUBE_TELEGRAF_PLUGIN_VERSION}_linux_amd64.tar.gz \
	&& echo "$YOUTUBE_TELEGRAF_PLUGIN_SHA256 *youtube-telegraf-plugin.tar.gz" | sha256sum -c \
	&& mkdir -p /usr/src/youtube-telegraf-plugin \
	&& tar -xzf youtube-telegraf-plugin.tar.gz -C /usr/src/youtube-telegraf-plugin \
	&& rm youtube-telegraf-plugin.tar.gz

FROM telegraf:1.23.1-alpine

COPY --from=download-deps /usr/src/twitch-telegraf-plugin/twitch-telegraf-plugin /usr/local/bin/
COPY --from=download-deps /usr/src/twitter-telegraf-plugin/twitter-telegraf-plugin /usr/local/bin/
COPY --from=download-deps /usr/src/youtube-telegraf-plugin/youtube-telegraf-plugin /usr/local/bin/

EXPOSE 8125/udp 8092/udp 8094

ENTRYPOINT ["/entrypoint.sh"]

CMD ["telegraf"]
