Docker image:

- Based on https://github.com/rocker-org/rocker
- Code shared under GPL-2.0
- Ubuntu 18.04 as the base image
- Has R and RStudio installed, with selected packages installed as well
- Jupyter, pandas, sklearn, are also installed

https://hub.docker.com/r/sainathadapa/ds-docker/

docker run -it -p 8787:8787 -p 8888:8888 sainathadapa/ds-docker /usr/bin/fish

jupyter notebook --ip=0.0.0.0 --port=8888 --allow-root
