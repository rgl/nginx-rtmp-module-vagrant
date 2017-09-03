#!/bin/bash
set -eux

# add the nginx user.
groupadd --system nginx-rtmp
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup nginx-rtmp \
    --home /opt/nginx-rtmp \
    nginx-rtmp
install -d -o root -g root -m 755 /opt/nginx-rtmp
install -d -o root -g root -m 755 /opt/nginx-rtmp/public

# download and install the latest version of ffmpeg.
wget -q https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-64bit-static.tar.xz
tar xf ffmpeg-release-64bit-static.tar.xz
cp ffmpeg-*-static/{ffmpeg,ffprobe} /usr/local/bin
ffmpeg -version

# download the latest version of nginx-rtmp-module.
git clone https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git

# download, build and install nginx+nginx-rtmp-module.
wget -q https://nginx.org/download/nginx-1.13.4.tar.gz
tar xf nginx-1.13.4.tar.gz
pushd nginx-1.13.4
apt-get install -y libpcre3 libpcre3-dev libssl-dev
./configure \
    --prefix=/opt/nginx-rtmp \
    --build=nginx-rtmp \
    --user=nginx-rtmp \
    --group=nginx-rtmp \
    --add-module=../nginx-rtmp-module
make -j 2
make install #DESTDIR=$PWD/DIST
popd

# copy public data.
cp -r /vagrant/public /opt/nginx-rtmp
wget -qO /opt/nginx-rtmp/public/shaka-player.compiled.js https://cdnjs.cloudflare.com/ajax/libs/shaka-player/2.2.0/shaka-player.compiled.js
wget -qO /opt/nginx-rtmp/public/hls.light.js https://github.com/video-dev/hls.js/raw/master/dist/hls.light.js
wget -qO /opt/nginx-rtmp/public/hls.light.min.js https://github.com/video-dev/hls.js/raw/master/dist/hls.light.min.js
wget -q https://github.com/videojs/video.js/releases/download/v6.2.7/video-js-6.2.7.zip
unzip -d video-js-6.2.7 video-js-6.2.7.zip
cp video-js-6.2.7/{video{,.min}.js,video-js{,.min}.css} /opt/nginx-rtmp/public
wget -qO /opt/nginx-rtmp/public/videojs-contrib-hls.js https://github.com/videojs/videojs-contrib-hls/releases/download/v5.10.0/videojs-contrib-hls.js
wget -qO /opt/nginx-rtmp/public/videojs-contrib-hls.min.js https://github.com/videojs/videojs-contrib-hls/releases/download/v5.10.0/videojs-contrib-hls.min.js
cp nginx-rtmp-module/stat.xsl /opt/nginx-rtmp/public

# create a tiny tmpfs for storing the video fragments.
cat >>/etc/fstab <<EOF
tmpfs /opt/nginx-rtmp/fragments tmpfs rw,nodev,nosuid,noexec,noatime,uid=0,gid=$(id -g nginx-rtmp),mode=1770,size=512M 0 0
EOF
mkdir /opt/nginx-rtmp/fragments
mount /opt/nginx-rtmp/fragments

# set the configuration.
# see https://github.com/arut/nginx-rtmp-module/wiki/Directives
cat >/opt/nginx-rtmp/conf/nginx.conf <<'EOF'
#error_log stderr warn;

worker_processes  auto;
events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;
        application hls {
            live on;
            hls on;
            hls_nested on;
            hls_fragment 3s;
            hls_playlist_length 3m;
            hls_path /opt/nginx-rtmp/fragments/hls;
            #allow publish 127.0.0.1;
            #deny publish all;
            #deny play all;
        }
    }
}

http {
    sendfile on;
    tcp_nopush on;
    root /opt/nginx-rtmp/public;

    types {
        text/html html;
        text/css css;
        text/javascript js;
        text/xsl xsl;
        application/dash+xml mpd;
        application/vnd.apple.mpegurl m3u8;
        video/mp2t ts;
    }
    default_type application/octet-stream;

    server {
        listen 80;

        location = /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }

        location /hls/ {
            #add_header Cache-Control no-cache;
            root /opt/nginx-rtmp/fragments;
        }
    }
}
EOF
/opt/nginx-rtmp/sbin/nginx -t

# run as a service.
cat >/etc/systemd/system/nginx-rtmp.service <<'EOF'
[Unit]
Description=nginx-rtmp
After=network.target

[Service]
Type=simple
ExecStart=/opt/nginx-rtmp/sbin/nginx -g 'daemon off;'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# start nginx.
systemctl enable nginx-rtmp
systemctl start nginx-rtmp

# configure log rotation.
cat >/etc/logrotate.d/nginx-rtmp <<'EOF'
/opt/nginx-rtmp/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        systemctl kill --signal=USR1 --kill-who=main nginx-rtmp
    endscript
}
EOF
