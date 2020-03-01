# vpn-workaround-docker-bridge
VPN as a workaround for the lack of bridge network on Docker for Windows and Mac

---

## Links

- [vpn-workaround-docker-bridge on GitHub](https://github.com/maresb/vpn-workaround-docker-bridge)
- [vpn-workaround-docker-bridge on Docker Hub](https://hub.docker.com/repository/docker/maresb/vpn-workaround-docker-bridge)

## Introduction

Docker for Windows or Mac is a great way to tinker with microservices. However, if you want to
do anything more serious, you will face endless frustration due to the fact that your Linux
kernel will be running in a virtual machine.  This defeats much of the benefit of Docker (running
processes directly in your OS's kernel instead of a VM), so you would be much better served
switching to Linux.

If however you are unfortunate enough to be stuck on Windows or Mac for whatever reason, one
of the many problems you may encounter is the lack of "Bridge Networking".  Effectively, bridge
networking allows you to connect directly to the IP address assigned to a running container.
Let's illustrate this with an example.

```
docker run --rm -it -p 127.0.0.1:8080:80 nginxdemos/hello
```
(Hit Ctrl+C twice to stop the test server.)

You should be able to connect to this container with a browser by visiting [`127.0.0.1:8080`](http://127.0.0.1:8080) or equivalently
[`localhost:8080`](http://localhost:8080).  If you attempt to visit the address you see for "Server Address:" 
from Linux it will work as expected, but if you are using Docker for Windows or Mac,
you will not be able to connect.  This is the problem which we will resolve.


## Run the VPN in a Docker container

Run the following commands:

```
docker run -d -p 127.0.0.1:1194:1194/udp --cap-add=NET_ADMIN --restart always --name my-docker-vpn maresb/vpn-workaround-docker-bridge

docker cp my-docker-vpn:/etc2/openvpn/vpn-workaround-client.ovpn .
```

The last command creates the client configuration file `vpn-workaround-client.ovpn` in the current directory.

The `--restart always` flag starts the container on boot, unless the container itself has been stopped.

## Shutting down the container

When you wish to stop the container, run the following commands:

```
docker stop my-docker-vpn
docker rm my-docker-vpn
```

Note that `docker rm` doesn't delete the image, it just cleans up the stopped container.

## Client configuration

For Windows, download [OpenVPN Connect for Windows](https://openvpn.net/client-connect-vpn-for-windows/).  This has been tested on version 3.1.2 (572) beta.

Start "OpenVPN Connect" and import the `vpn-workaround-client.ovpn` file, press "Add" and connect.  Press the triple-bars button in the upper-left, select "Settings" and turn on "Reconnect on Reboot."  

Now if the VPN container is running, and you are connected with the client, then you should 
be able to connect directly to other Docker containers via their IP addresses.  On reboot,
the OpenVPN Connect client will automatically try to reestablish the connection.  It should
succeed after Docker for Windows starts.


## Set up a non-default network (optional, but highly recommended)

The default network on Docker works fine, dynamically allocating an IP address for any new
container on the subnet `172.17.0.*`.  Unfortunately, one is not allowed to manually assign an
IP address to a container on this default subnet.  Thus we will launch containers on a new
"docker network" where we can assign IPs.

1. Create a new "docker network" with a specified subnet:
    ```
    docker network create --subnet=192.168.88.0/24 mynet
    ```
    Note: the subnet (in particular the number `88`) is customizable, as is the name `mynet`.

2. Edit `vpn-workaround-client.ovpn`.  Change the last line from
    ```
    route 172.17.0.0 255.255.255.0
    ```
    to 
    ```
    route 192.168.88.0 255.255.255.0
    ```

3. Start the VPN inside this subnet by adding `--network mynet` to the `docker run` command.  
If the container is already running on the default subnet, then we need to stop it:
    ```
    docker stop my-docker-vpn
    docker rm my-docker-vpn
    ```
    Then we start the VPN:
    ```
    docker run -d -p 127.0.0.1:1194:1194/udp --network mynet --cap-add=NET_ADMIN --restart always --name my-docker-vpn maresb/vpn-workaround-docker-bridge
    ```

4. In the VPN Client, delete the current configuration and load the modified `vpn-workaround-client.ovpn` as per the instructions in [Client Configuration](client-configuration).

#### Testing

Now we can start a test container with a manually assigned IP address:
```
docker run --rm -it -p 127.0.0.1:8080:80 --network=mynet --ip=192.168.88.123 nginxdemos/hello
```
(Hit Ctrl+C twice to stop the test server.)

Similar to before, if we visit [`localhost:8080`](http://localhost:8080), we should see "Server address: 192.168.88.123:80".
If the VPN is correctly functioning, [`192.168.88.123:80`](http://192.168.88.123:80) will also be 
accessible.

#### Docker network cleanup

To delete the docker network we created in the last section, stop all containers on that network and run

```
docker network rm mynet
```

## Security

I make [no warranty or guarantee](LICENSE) about the security of this container.  If you find a
vulnerability, please report it to me under "Issues".

This container is intended for internal use on a single-user machine.  Since there is no potential
for eavesdropping, the normal security features of a VPN should not be necessary.  Indeed, the certificates 
being used are generated on Docker Hub and are publicly accessible.

If you run Docker containers which are publicly accessible and they become compromised, having this VPN running
could make it easier for an attacker to compromise the host.
