#!/bin/sh
cd $(dirname $0)

echo "eula=true" >eula.txt
java -Xmx4G -Xms4G -jar server.jar nogui
