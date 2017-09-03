This is a HTTP Live Streaming (HLS) server based on the nginx-rtmp-module, ffmpeg and the html video element.

[HTTP Live Streaming](https://en.wikipedia.org/wiki/HTTP_Live_Streaming) (HLS) uses the [MPEG-2 Transport Stream](https://en.wikipedia.org/wiki/MPEG_transport_stream) (MP2T) to transport [H.264](https://en.wikipedia.org/wiki/H.264/MPEG-4_AVC) video and [AAC](https://en.wikipedia.org/wiki/Advanced_Audio_Coding)/[MP3](https://en.wikipedia.org/wiki/MP3) audio. On the browser, via JavaScript, MP2T is transmuxed into the [ISO BMFF](https://en.wikipedia.org/wiki/ISO_base_media_file_format) Byte Stream Format and feed to the html video element via [Media Source Extensions](https://en.wikipedia.org/wiki/Media_Source_Extensions) (MSE).

# Usage

Install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Run `vagrant up` to launch with VirtualBox.

Browse to [http://10.0.0.2/](http://10.0.0.2/) to see the examples.

# Reference

* [Setting up HLS live streaming server using NGINX + nginx-rtmp-module on Ubuntu](https://docs.peer5.com/guides/setting-up-hls-live-streaming-server-using-nginx/)
* [FFmpeg and H.264 Encoding Guide](https://trac.ffmpeg.org/wiki/Encode/H.264)
* [Apple HTTP Live Streaming](https://developer.apple.com/streaming/)
* [Apple HLS Authoring Specification: General Authoring Requirements](https://developer.apple.com/library/content/documentation/General/Reference/HLSAuthoringSpec/Requirements.html)
* [Apple HTTP Live Streaming Examples](https://developer.apple.com/streaming/examples/)
* [RFC8216: HTTP Live Streaming](https://tools.ietf.org/html/rfc8216)
