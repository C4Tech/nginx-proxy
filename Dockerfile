FROM nginx:1.13
#All the heavy lifting was done by Jason Wilder mail@jasonwilder.com
# I only modified a few lines
MAINTAINER Jeffrey Brite jeff@c4tech.com

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN echo "deb-src https://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list.d/nginx.list


# Install wget and install/updates certificates
# dpkg and git for nginx ldap
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates apt-transport-https \
    wget dpkg-dev git libldap2-dev

RUN git clone https://github.com/kvspb/nginx-auth-ldap.git
#RUN apt-get source nginx=1.11.6-1~jessie
RUN apt-get source nginx=1.13.9-1~stretch
RUN apt-get build-dep -y -q nginx
#RUN sed -i 's/with-file-aio/& \\\n              \-\-add-module=\/nginx-auth-ldap\//g' ./nginx-1.11.6/debian/rules
RUN sed -i 's/with-file-aio/& \\\n              \-\-add-module=\/nginx-auth-ldap\//g' ./nginx-1.13.9/debian/rules

RUN cd ./nginx-1.13.9/ &&  dpkg-buildpackage -b
RUN dpkg -i ./nginx_1.13.9-1~strech_amd64.deb

RUN apt-get clean \
 && apt-get remove --purge --auto-remove -y apt-transport-https ca-certificates \
 && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list

# Configure Nginx and apply fix for very long server names
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
 && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf
# && sed -i 's/^http {/&\n    server_names_hash_bucket_size 128;/g' /etc/nginx/nginx.conf

# Install Forego
ADD https://github.com/jwilder/forego/releases/download/v0.16.1/forego /usr/local/bin/forego
RUN chmod u+x /usr/local/bin/forego

ENV DOCKER_GEN_VERSION 0.7.3

RUN wget https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && tar -C /usr/local/bin -xvzf docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && rm /docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

COPY network_internal.conf /etc/nginx/

COPY . /app/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs",  "/etc/nginx/dhparam"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
