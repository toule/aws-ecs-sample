FROM nginx:latest
MAINTAINER Ray.H.Li <lhs6395@gscdn.com>

COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
