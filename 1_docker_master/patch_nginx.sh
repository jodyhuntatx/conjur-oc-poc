#!/bin/bash
/bin/sed -i 's/^.*\[\:\:\]\:80\;/  listen 127.0.0.1:80\;/' /etc/nginx/sites-enabled/conjur
/bin/sed -i 's/^.*\[\:\:1\]\:80\;//' /etc/nginx/sites-enabled/conjur
/bin/sed -i 's/^.*\[.*443.*//' /etc/conjur/nginx.d/00_ssl_port.conf
