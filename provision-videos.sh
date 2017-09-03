
apt-get install -y fonts-dejavu-core

wget -q -O /usr/local/bin/youtube-dl https://yt-dl.org/downloads/latest/youtube-dl
chmod +x /usr/local/bin/youtube-dl

wget -q -O /usr/local/bin/iframe-probe.py https://gist.githubusercontent.com/use-sparingly/7041ee993adb5c911f90/raw/d6cfe6a51c990ff5ae5242cb5711d2a68651f573/iframe-probe.py
chmod +x /usr/local/bin/iframe-probe.py

mkdir videos
cd videos

convert_video() {
    input=$1; shift
    output=$1; shift
    max_video_height=$1; shift
    fragment_length_seconds=$1; shift
    fps=$1; shift
    gop=$(expr $fragment_length_seconds \* $fps)   

    echo "Transcoding $input into $output (${max_video_height}p)..."
    # transcode (and scale) the original file to be directly consumed by the
    # nginx-rtmp-module.
    # NB the players are quite fragile, so its safer to use a constant GOP
    #    length, no scene detection (bc it causes the keyframe interval to
    #    vary) and closed GOPs.
    # see https://trac.ffmpeg.org/wiki/Scaling%20(resizing)%20with%20ffmpeg
    # see https://trac.ffmpeg.org/wiki/Encode/H.264
    # see https://kvssoft.wordpress.com/2015/01/28/mpeg-dash-gop/
    # see http://caniuse.com/#feat=mpeg4
    extra_filter_v="drawtext=text='%{pts\\:hms} #%{n}':x=-5:y=3:fontsize=13:fontcolor=white:box=1:boxborderw=3:boxcolor=black:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
    ffmpeg \
        -loglevel info \
        -y \
        -i $input \
        -r $fps \
        -codec:v libx264 \
        -preset medium \
        -profile:v high -level 4.2 \
        -crf 23 \
        -g $gop \
        -keyint_min $gop \
        -sc_threshold 0 \
        -flags +cgop \
        -movflags +faststart \
        -filter:v "scale=w=-2:h=$max_video_height,$extra_filter_v" \
        -codec:a aac \
        -q:a 4 \
        -f flv \
        -vstats_file ${output}_${max_video_height}p_stats.txt \
        ${output}_${max_video_height}p.flv \
        2>&1 \
            | grep -vEe 'Past duration [0-9.]+ too large' \
            | grep -vEe ' dropping frame '

    echo "Dumping GOPs..."
    # NB this calls ffprobe -show_frames -print_format json costa_rica_${max_video_height}p.flv
    iframe-probe.py ${output}_${max_video_height}p.flv >${output}_${max_video_height}p_gops.txt
    printf "   GOPs size\ttype\n"; awk '{print $3 "\t" $4}' ${output}_${max_video_height}p_gops.txt | sort | uniq -c

    echo "Converting to static hls at /opt/nginx-rtmp/public/vod/hls/${output}/index.m3u8..."
    rm -rf /opt/nginx-rtmp/public/vod/hls/${output}
    mkdir -p /opt/nginx-rtmp/public/vod/hls/${output}
    ffmpeg \
        -loglevel info \
        -i ${output}_${max_video_height}p.flv \
        -codec:v copy \
        -codec:a copy \
        -hls_time $fragment_length_seconds \
        -hls_list_size 0 \
        -f hls \
        /opt/nginx-rtmp/public/vod/hls/${output}/index.m3u8
}

echo 'Downloading the Costa Rica video....'
youtube-dl -o costa_rica_720p.webm -f 'best[height=720]' 'https://www.youtube.com/watch?v=iNJdPyoqt8U'
convert_video costa_rica_720p.webm costa_rica 240 3 24

echo 'Downloading the Kung Fu Mantis vs Jumping Spider video....'
youtube-dl -o kung_fu_mantis_vs_jumping_spider_720p.webm -f 'best[height=720]' 'https://www.youtube.com/watch?v=7wKu13wmHog'
convert_video kung_fu_mantis_vs_jumping_spider_720p.webm kung_fu_mantis_vs_jumping_spider 240 3 24

echo 'Downloading the Planet Earth II Continues video....'
youtube-dl -o planet_earth_ii_continues_trailer_720p.webm -f 'best[height=720]' 'https://www.youtube.com/watch?v=h8yo_Sp-rGY'
convert_video planet_earth_ii_continues_trailer_720p.webm planet_earth_ii_continues_trailer 240 3 24

echo 'Downloading the Tears of Steel video....'
wget -q http://ftp.nluug.nl/pub/graphics/blender/demo/movies/ToS/tears_of_steel_720p.mov
convert_video tears_of_steel_720p.mov tears_of_steel 240 3 24

# continually stream the videos to nginx-rtmp in a background service.
cat >stream-from-files.sh <<'EOF'
#!/bin/bash
set -eux
while true; do
    for n in *_240p.flv; do
        ffmpeg \
            -loglevel info \
            -re \
            -i $n \
            -codec:v copy \
            -codec:a copy \
            -f flv \
            rtmp://localhost:1935/hls/live
        sleep 1
    done
done
EOF
chmod +x stream-from-files.sh
cat >/etc/systemd/system/stream-from-files.service <<EOF
[Unit]
Description=stream-from-files
After=network.target

[Service]
Type=simple
WorkingDirectory=$PWD
ExecStart=$PWD/stream-from-files.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable stream-from-files
systemctl start stream-from-files
