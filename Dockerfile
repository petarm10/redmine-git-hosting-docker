# Based Official Dockerfile
# https://github.com/docker-library/redmine/blob/282e53760ea23d3415bb1e45d2a0d930f47575c3/4.2/alpine/Dockerfile

FROM ruby:3.1.4-alpine3.17
LABEL title="redmine-git-hosting"

ENV RAILS_ENV production
ENV REDMINE_HOME /opt/redmine
ENV REDMINE_VERSION 5.0.5
ENV REDMINE_DOWNLOAD_SHA256 a89ad1c4bb9bf025e6527c77ab18c8faf7749c94a975caf2cfdbba00eb12a481
ENV BUNDLE_FORCE_RUBY_PLATFORM 1

ENV DB_HOST=192.168.31.149
ENV DB_PORT=5432
ENV DB_DATABASE=redminedb
ENV DB_USER=redmine
ENV DB_PASSWORD=redmine

RUN apk add --no-cache \
	sudo bash su-exec supervisor ca-certificates tini tzdata wget git libgit2 openssh imagemagick libpq shadow perl gitolite libssh2 libssh2-dev

# Redmine Install
RUN cd /opt \
	&& wget -O redmine.tar.gz "https://www.redmine.org/releases/redmine-${REDMINE_VERSION}.tar.gz" \
	&& echo "$REDMINE_DOWNLOAD_SHA256 *redmine.tar.gz" | sha256sum -c - \
	&& tar -zvxf redmine.tar.gz \
	&& ln -s redmine-${REDMINE_VERSION} redmine \
	&& rm redmine.tar.gz redmine/files/delete.me redmine/log/delete.me \
	&& cd redmine \
	&& mkdir -p log public/plugin_assets sqlite tmp/pdf tmp/pids \
	# log to STDOUT (https://github.com/docker-library/redmine/issues/108)
	&& echo 'config.logger = Logger.new(STDOUT)' > config/additional_environment.rb \
	# DB Config Setting
	&& echo "production:" > config/database.yml \
	&& echo "  adapter: postgresql" >> config/database.yml \
	# Redmine Git Hosting Plugin Install
	# build for musl-libc, not glibc (see https://github.com/sparklemotion/nokogiri/issues/2075, https://github.com/rubygems/rubygems/issues/3174)
	&& apk add --no-cache --virtual .build-deps \
		coreutils freetds-dev gcc make cmake musl-dev patch postgresql-dev ttf2ufm zlib-dev shadow libpq openssl-dev \
	&& cd plugins \
	# Wysiwyg Editor
	&& git clone https://github.com/taqueci/redmine_wysiwyg_editor.git \
	# Redmine Git Hosting Plugin Install
	&& git clone https://github.com/AlphaNodes/additionals.git \
	&& git clone https://github.com/redmine-git-hosting/redmine_git_hosting.git \
	&& cd redmine_git_hosting/ \
	&& cd /opt/redmine \
	&& bundle config --local without 'development test' \
	&& bundle install \
	&& apk del --no-cache .build-deps \
    && mkdir /opt/ssh_keys \
	&& ssh-keygen -m PEM -N '' -f /opt/ssh_keys/redmine_gitolite_admin_id_rsa \
	&& ssh-keygen -A \
	# Theme Install
	&& cd /opt/redmine/public/themes \
	&& git clone https://github.com/mrliptontea/PurpleMine2.git redmine-theme-purplemine2

VOLUME /opt/redmine/files
VOLUME /var/lib/git

WORKDIR /opt/redmine
COPY supervisord.conf /etc/
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 22
EXPOSE 3000
CMD ["supervisord","-n","-c","/etc/supervisord.conf"]