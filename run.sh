#!/usr/bin/env bash

set -e

SSHD=sshd
JMETER=jmeter

#Replace server port
sed -i "s|#server.rmi.localport=.*|server.rmi.localport=${JMETER_PORT}|g" /opt/jmeter/bin/jmeter.properties

#Generate hostkeys
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating host keys"
    ssh-keygen -A
fi

#Set authorized keys if needed
if [ ! -f ${HOME}/.ssh/authorized_keys ]; then
    mkdir -p "${HOME}/.ssh" && chmod 600 "${HOME}/.ssh"
    if [ -z "$JMETER_PUBLIC_KEY" ]; then 
        echo "Generating keypair..."; 
        ssh-keygen -t rsa -N "" -f "${HOME}/.ssh/id_rsa"
	echo "Generated private key: "
	cat "${HOME}/.ssh/id_rsa"
    else 
        echo "Added ${JMETER_PUBLIC_KEY} to authorized keys"
        echo "${JMETER_PUBLIC_KEY}\n" >> "${HOME}/.ssh/authorized_keys"
    fi
fi

stop() {
    echo "Received SIGINT or SIGTERM. Shutting down script..."

    sshd_pid=$(cat /var/run/$SSHD/$SSHD.pid)
    kill -SIGTERM "${sshd_pid}"
    rm -r /var/run/$SSHD

    jmeter_pid=$(cat /var/run/$JMETER/$JMETER.pid)
    kill -SIGTERM "${jmeter_pid}"
    rm -r /var/run/$JMETER

    wait ${sshd_pid} ${jmeter_pid}
    echo "Done."
}

trap stop SIGINT SIGTERM

#Spin up sshd
echo "Running sshd"
/usr/sbin/sshd -D &
sshd_pid="$!"
mkdir -p /var/run/$SSHD && echo "${sshd_pid}" > /var/run/$SSHD/$SSHD.pid

#Spin up jmeter
echo "Running jmeter"
java -server -XX:+HeapDumpOnOutOfMemoryError -Xms512m -Xmx512m -XX:MaxTenuringThreshold=2 -XX:+CMSClassUnloadingEnabled -jar /opt/jmeter/bin/ApacheJMeter.jar -Dserver_port=${RMI_PORT} -s -j /var/log/jmeter-server.log -Djava.rmi.server.hostname=localhost &
jmeter_pid="$!"
mkdir -p /var/run/$JMETER && echo "${jmeter_pid}" > /var/run/$JMETER/$JMETER.pid

wait ${sshd_pid} ${jmeter_pid} && exit $?
