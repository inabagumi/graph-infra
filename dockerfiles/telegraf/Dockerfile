FROM alpine:3.16 AS download-deps

ENV TWITCH_TELEGRAF_PLUGIN_REPOSITORY inabagumi/twitch-telegraf-plugin
ENV TWITCH_TELEGRAF_PLUGIN_VERSION 1.0.1
ENV TWITCH_TELEGRAF_PLUGIN_SHA256 10fb34ef069f83a487a35e1be8c69b28a80ff15da5abf04d30788169b87c30cc

ENV TWITTER_TELEGRAF_PLUGIN_REPOSITORY inabagumi/twitter-telegraf-plugin
ENV TWITTER_TELEGRAF_PLUGIN_VERSION 1.0.1
ENV TWITTER_TELEGRAF_PLUGIN_SHA256 8369d241e7f22a33c5947a7ba4297043af6d560bbee933aa090f74b2b7131494

ENV YOUTUBE_TELEGRAF_PLUGIN_REPOSITORY inabagumi/youtube-telegraf-plugin
ENV YOUTUBE_TELEGRAF_PLUGIN_VERSION 1.1.2
ENV YOUTUBE_TELEGRAF_PLUGIN_SHA256 973b6ce20120ae7da4a684aa17c0b4e4b7d036447ee015094998c9244b2ecfbf

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

FROM telegraf:1.24.1-alpine

COPY --from=download-deps /usr/src/twitch-telegraf-plugin/twitch-telegraf-plugin /usr/local/bin/
COPY --from=download-deps /usr/src/twitter-telegraf-plugin/twitter-telegraf-plugin /usr/local/bin/
COPY --from=download-deps /usr/src/youtube-telegraf-plugin/youtube-telegraf-plugin /usr/local/bin/

EXPOSE 8125/udp 8092/udp 8094

ENTRYPOINT ["/entrypoint.sh"]

CMD ["telegraf"]
