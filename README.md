Based on https://github.com/rocker-org/rocker.

Code shared under GPL-2.0.

https://hub.docker.com/r/sainathadapa/ds-docker/

docker run -it -p 8787:8787 -p 8888:8888 sainathadapa/ds-docker /usr/bin/fish

jupyter notebook --ip=0.0.0.0 --port=8888 --allow-root
