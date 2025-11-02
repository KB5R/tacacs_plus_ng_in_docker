FROM alt:sisyphus

LABEL maintainer="Maintainer Popkov MK"
LABEL description="TACACS+ NG Server in Docker and rsunc script sync volume files"

RUN apt-get update && apt-get install -y \
    libpcre2-devel \
    gcc \
    make \
    libpcre-devel \
    perl-ldap \
    bison \
    flex \
    tar \
    bzip2 \
    openssl-devel \
    pam-devel \
    sed \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

COPY files/DEVEL.202310061820.tar.bz2 /tmp/

RUN tar xvfj DEVEL.202310061820.tar.bz2 && \
    cd PROJECTS/ && \
    ./configure --prefix=/opt/tac_plus-ng --with-pcre2 tac_plus-ng && \
    sed -i -e's/\$(LIB_CRYPT)/-lcrypt/g' tac_plus-ng/Makefile.obj && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/*

RUN mkdir -p /var/log/tac_plus-ng/authz \
             /var/log/tac_plus-ng/authc \
             /var/log/tac_plus-ng/acct

RUN useradd -r -s /bin/false tacacs 2>/dev/null || true

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN chown -R tacacs:tacacs /opt/tac_plus-ng /var/log/tac_plus-ng

EXPOSE 49

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
    CMD netstat -tuln | grep ':49 ' || exit 1

VOLUME ["/opt/tac_plus-ng/etc", "/var/log/tac_plus-ng"]

# RUN вместо systemd
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"] 