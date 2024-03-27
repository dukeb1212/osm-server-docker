#Base Docker image
FROM ubuntu:22.04

#Setting up environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV PG_VERSION 15

#Common setup
RUN apt-get update \
&& apt-get install -y --no-install-recommends \
 ca-certificates gnupg lsb-release locales \
 wget curl \
&& locale-gen $LANG && update-locale LANG=$LANG \
&& sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
&& wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
&& apt-get update && apt-get -y upgrade

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#Getting required packages
RUN apt-get install -y --no-install-recommends \
 dateutils sudo gnupg2\
 fonts-hanazono fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted fonts-unifont \
 gdal-bin liblua5.3-dev lua5.3 mapnik-utils \
 osm2pgsql osmium-tool osmosis \
 postgresql-$PG_VERSION postgresql-$PG_VERSION-postgis-3 postgresql-$PG_VERSION-postgis-3-scripts postgis \
 python-is-python3 python3-mapnik python3-lxml python3-psycopg2 python3-shapely python3-pip \
 renderd apache2\
&& apt-get clean autoclean \
&& apt-get autoremove --yes \
&& rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN pip3 install requests osmium pyyaml

#Configuring Apache2 module(mod_tile)
COPY ./apache2/modules /etc/apache2/conf-available/

RUN a2enconf mod_tile && a2enconf mod_headers

COPY ./apache2/apache.conf /etc/apache2/sites-available/000-default.conf

RUN ln -sf /dev/stdout /var/log/apache2/access.log \
&& ln -sf /dev/stderr /var/log/apache2/error.log

#Using sample template website from Leaflet
COPY leaflet-demo.html /var/www/html/index.html
COPY ./leaflet /var/www/html/

#Configuring PostgreSQL
COPY postgresql.custom.conf.tmpl /etc/postgresql/$PG_VERSION/main/
RUN chown -R postgres:postgres /var/lib/postgresql \
&& chown postgres:postgres /etc/postgresql/$PG_VERSION/main/postgresql.custom.conf.tmpl \
&& echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf \
&& echo "host all all ::/0 scram-sha-256" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf

#Creating required directories and changing users' permissions
RUN mkdir /home/src/

RUN mkdir -p /run/renderd/ \
&&  mkdir -p /data/database/ \
&&  mkdir -p /data/style/ \
&&  chown -R _renderd: /data/  \
&&  chown -R _renderd: /home/src/ \
&&  chown -R _renderd: /run/renderd \
&&  mv /var/lib/postgresql/$PG_VERSION/main/ /data/database/postgres/ \
&&  mv /var/cache/renderd/tiles/ /data/tiles/ \
&&  chown -R  _renderd: /data/tiles \
&&  ln -s  /data/database/postgres /var/lib/postgresql/$PG_VERSION/main \
&&  ln -s  /data/style /home/src/openstreetmap-carto \
&&  ln -s  /data/tiles /var/cache/renderd/tiles \
;

#Configuring renderd package
COPY renderd.conf /etc/renderd.conf

#Using default osm data (Vietnam) and map style
COPY ./data /data/
RUN cd /home/src/ && git clone https://github.com/gravitystorm/openstreetmap-carto.git
COPY ./mapnik.xml /home/src/openstreetmap-carto/

#Run the script and expose connection ports
COPY run.sh /
ENTRYPOINT ["/run.sh"]
CMD []
EXPOSE 80 5432