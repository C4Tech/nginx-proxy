FROM nginx:1.19.7
#All the heavy lifting was done by Jason Wilder mail@jasonwilder.com
# I only modified a few lines
MAINTAINER Jeffrey Brite jeff@c4tech.com

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt update \
 && apt install -y -q --no-install-recommends \
 apt-transport-https gnupg1 ca-certificates \
  wget dpkg-dev git libldap2-dev
RUN NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; 
	
#RUN test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
#  apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/*
RUN  apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/*

RUN echo "deb https://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list \
 && echo "deb-src https://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list


# Install wget and install/updates certificates
# dpkg and git for nginx ldap

RUN git clone https://github.com/kvspb/nginx-auth-ldap.git

RUN apt update \
 && apt-get source nginx=1.19.7-1~buster
RUN apt-get build-dep -y -q nginx
RUN sed -i 's/with-file-aio/& \\\n              \-\-add-module=\/nginx-auth-ldap\//g' ./nginx-1.19.7/debian/rules

RUN cd ./nginx-1.19.7/ &&  dpkg-buildpackage -b
RUN dpkg -i ./nginx_1.19.7-1~buster_amd64.deb

# Configure Nginx and apply fix for very long server names
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
 && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf
# && sed -i 's/^http {/&\n    server_names_hash_bucket_size 128;/g' /etc/nginx/nginx.conf

# Install Forego
ADD https://github.com/jwilder/forego/releases/download/v0.16.1/forego /usr/local/bin/forego
RUN chmod u+x /usr/local/bin/forego

#ENV DOCKER_GEN_VERSION 0.7.4

#RUN wget https://github.com/jwilder/docker-gen/releases/download/0.7.3/docker-gen-linux-amd64-0.7.4.tar.gz \
# && tar -C /usr/local/bin -xvzf docker-gen-linux-amd64-0.7.4.tar.gz \
# && rm /docker-gen-linux-amd64-0.7.4.tar.gz

RUN wget https://github.com/jwilder/docker-gen/releases/download/0.7.3/docker-gen-linux-amd64-0.7.4.tar.gz
RUN tar -C /usr/local/bin -xvzf docker-gen-linux-amd64-0.7.4.tar.gz
RUN rm /docker-gen-linux-amd64-0.7.4.tar.gz


#COPY network_internal.conf /etc/nginx/

COPY . /app/
WORKDIR /app/

RUN apt-get clean \
 && apt-get remove --purge --auto-remove -y apt-transport-https ca-certificates wget dpkg-dev git \
 && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list


ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs",  "/etc/nginx/dhparam"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
