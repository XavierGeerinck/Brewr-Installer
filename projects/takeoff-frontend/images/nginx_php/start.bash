# Deamon off since we want Nginx in the foreground (needed for docker)
service php5-fpm start
nginx -g "daemon off;"
