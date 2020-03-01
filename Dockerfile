FROM kylemanna/openvpn:latest@sha256:266c52c3df8d257ad348ea1e1ba8f0f371625b898b0eba6e53c785b82f8d897e

LABEL maintainer="Ben Mares <services-vpn-workaround-docker-bridge@tensorial.com>"

# /etc/openvpn is a volume, but we don't want to use it as such.
# Replace it with /etc/openvpn2.

  ENV OPENVPN=/etc/openvpn2
  ENV EASYRSA_PKI=/etc/openvpn2/pki
  ENV EASYRSA_VARS_FILE=/etc/openvpn2/vars
  RUN mkdir /etc/openvpn2

# Generate config for localhost

  RUN ovpn_genconfig -d -N -u udp://127.0.0.1

# Initialize PKI with no password

  RUN echo | ovpn_initpki nopass

# Make client certificates with no password
  RUN easyrsa build-client-full mynet-vpn-client nopass

# Write config file

  RUN ( \
          ovpn_getclient mynet-vpn-client \
       && echo route-nopull \
       && echo route 192.168.88.0 255.255.255.0 \
      ) > /etc/openvpn2/mynet-vpn-client.ovpn
