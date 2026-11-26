FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 \
    iputils-ping \
    iputils-tracepath \
    traceroute \
    ethtool \
    tcpdump \
    iperf \
    openssh-server \
    vim \
    lldpd \
    smcroute \
    sudo \
    && rm -rf /var/lib/apt/lists/*
RUN adduser --disabled-password --gecos "" admin && passwd -d admin
RUN sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
RUN echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin && touch /home/admin/.sudo_as_admin_successful
RUN rm -f /etc/machine-id

COPY --chmod=755 entrypoint.sh /usr/local/sbin/container-entrypoint
ENTRYPOINT ["/usr/local/sbin/container-entrypoint"]
