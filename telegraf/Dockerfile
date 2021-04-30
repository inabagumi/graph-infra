FROM telegraf:1.18.2

ENV TWITTER_TELEGRAF_PLUGIN_VERSION 0.1.0
ENV TWITTER_TELEGRAF_PLUGIN_SHA256 f7a45e092bb9ae1a1d128662a0b94adb871ff33959819f16e0221e9e73a2aa4b

ENV YOUTUBE_TELEGRAF_PLUGIN_VERSION 0.1.0
ENV YOUTUBE_TELEGRAF_PLUGIN_SHA256 c9591a42122f38bcad1257c3a5e1655139e56efbdc65ab8902f65a8ccad2d271

RUN set -x \
	\
	&& wget \
		-O twitter-telegraf-plugin.tar.gz \
		https://github.com/inabagumi/twitter-telegraf-plugin/releases/download/v${TWITTER_TELEGRAF_PLUGIN_VERSION}/twitter-telegraf-plugin-${TWITTER_TELEGRAF_PLUGIN_VERSION}_linux_amd64.tar.gz \
	&& echo "$TWITTER_TELEGRAF_PLUGIN_SHA256 *twitter-telegraf-plugin.tar.gz" | sha256sum -c \
	&& mkdir -p /usr/src/twitter-telegraf-plugin \
	&& tar -xzf twitter-telegraf-plugin.tar.gz -C /usr/src/twitter-telegraf-plugin \
	&& rm twitter-telegraf-plugin.tar.gz \
	&& mv /usr/src/twitter-telegraf-plugin/twitter-telegraf-plugin /usr/local/bin \
	&& rm -rf /usr/src/twitter-telegraf-plugin \
	\
	&& wget \
		-O youtube-telegraf-plugin.tar.gz \
		https://github.com/inabagumi/youtube-telegraf-plugin/releases/download/v${YOUTUBE_TELEGRAF_PLUGIN_VERSION}/youtube-telegraf-plugin-${YOUTUBE_TELEGRAF_PLUGIN_VERSION}_linux_amd64.tar.gz \
	&& echo "$YOUTUBE_TELEGRAF_PLUGIN_SHA256 *youtube-telegraf-plugin.tar.gz" | sha256sum -c \
	&& mkdir -p /usr/src/youtube-telegraf-plugin \
	&& tar -xzf youtube-telegraf-plugin.tar.gz -C /usr/src/youtube-telegraf-plugin \
	&& rm youtube-telegraf-plugin.tar.gz \
	&& mv /usr/src/youtube-telegraf-plugin/youtube-telegraf-plugin /usr/local/bin \
	&& rm -rf /usr/src/youtube-telegraf-plugin

EXPOSE 8125/udp 8092/udp 8094
ENTRYPOINT ["/entrypoint.sh"]
CMD ["telegraf"]
