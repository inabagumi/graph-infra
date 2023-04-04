FROM alpine:3.17 AS download-deps

ENV TWITCH_TELEGRAF_PLUGIN_REPOSITORY inabagumi/twitch-telegraf-plugin
ENV TWITCH_TELEGRAF_PLUGIN_VERSION 1.1.0
ENV TWITCH_TELEGRAF_PLUGIN_SHA256 74633f20ee7df3c1ed6f1c13b4a4c9809dcb6d13a669da38fff8fa42c3c8f7ff

ENV TWITTER_TELEGRAF_PLUGIN_REPOSITORY inabagumi/twitter-telegraf-plugin
ENV TWITTER_TELEGRAF_PLUGIN_VERSION 1.1.0
ENV TWITTER_TELEGRAF_PLUGIN_SHA256 b62e7fab9952ef29b3d5e617ce399e2dccd70939b6dfaad95d4136204d92e151

ENV YOUTUBE_TELEGRAF_PLUGIN_REPOSITORY inabagumi/youtube-telegraf-plugin
ENV YOUTUBE_TELEGRAF_PLUGIN_VERSION 2.0.0
ENV YOUTUBE_TELEGRAF_PLUGIN_SHA256 8fffe964a3e4cedb31c304db23d813e8c5e9a635ea194574cfc040101e4f0c38

RUN set -x \
	\
	&& wget \
		-O twitch-telegraf-plugin.tar.gz \
		https://github.com/${TWITCH_TELEGRAF_PLUGIN_REPOSITORY}/releases/download/v${TWITCH_TELEGRAF_PLUGIN_VERSION}/twitch-telegraf-plugin-${TWITCH_TELEGRAF_PLUGIN_VERSION}_linux_amd64.tar.gz \
	&& echo "$TWITCH_TELEGRAF_PLUGIN_SHA256 *twitch-telegraf-plugin.tar.gz" | sha256sum -c \
	&& mkdir -p /usr/src/twitch-telegraf-plugin \
	&& tar -xzf twitch-telegraf-plugin.tar.gz -C /usr/src/twitch-telegraf-plugin \
	\
	&& wget \
		-O twitter-telegraf-plugin.tar.gz \
		https://github.com/${TWITTER_TELEGRAF_PLUGIN_REPOSITORY}/releases/download/v${TWITTER_TELEGRAF_PLUGIN_VERSION}/twitter-telegraf-plugin-${TWITTER_TELEGRAF_PLUGIN_VERSION}_linux_amd64.tar.gz \
	&& echo "$TWITTER_TELEGRAF_PLUGIN_SHA256 *twitter-telegraf-plugin.tar.gz" | sha256sum -c \
	&& mkdir -p /usr/src/twitter-telegraf-plugin \
	&& tar -xzf twitter-telegraf-plugin.tar.gz -C /usr/src/twitter-telegraf-plugin \
	\
	&& wget \
		-O youtube-telegraf-plugin.tar.gz \
		https://github.com/${YOUTUBE_TELEGRAF_PLUGIN_REPOSITORY}/releases/download/v${YOUTUBE_TELEGRAF_PLUGIN_VERSION}/youtube-telegraf-plugin-${YOUTUBE_TELEGRAF_PLUGIN_VERSION}_linux_amd64.tar.gz \
	&& echo "$YOUTUBE_TELEGRAF_PLUGIN_SHA256 *youtube-telegraf-plugin.tar.gz" | sha256sum -c \
	&& mkdir -p /usr/src/youtube-telegraf-plugin \
	&& tar -xzf youtube-telegraf-plugin.tar.gz -C /usr/src/youtube-telegraf-plugin

FROM telegraf:1.26.1-alpine

COPY --from=download-deps /usr/src/twitch-telegraf-plugin/twitch-telegraf-plugin /usr/local/bin/
COPY --from=download-deps /usr/src/twitter-telegraf-plugin/twitter-telegraf-plugin /usr/local/bin/
COPY --from=download-deps /usr/src/youtube-telegraf-plugin/youtube-telegraf-plugin /usr/local/bin/

EXPOSE 8125/udp 8092/udp 8094

ENTRYPOINT ["/entrypoint.sh"]

CMD ["telegraf"]
