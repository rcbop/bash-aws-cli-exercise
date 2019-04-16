FROM nginx:latest
WORKDIR /www/data/
RUN apt-get update -y && apt-get upgrade -y
COPY index.html index.html
COPY nginx/app/*.conf /etc/nginx/conf.d/
COPY nginx/nginx.conf /etc/nginx/nginx.conf