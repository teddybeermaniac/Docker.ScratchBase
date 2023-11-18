# Docker.StaticHTTPD
A tiny, scratch-based base Docker image for my other tiny images.

## Usage
Add files that you need to the image and use `CMD` to specify a command to be run using [tini].
The command will be run as `nobody:nobody` via [su-exec].

[su-exec]: https://github.com/ncopa/su-exec
[tini]: https://github.com/krallin/tini
