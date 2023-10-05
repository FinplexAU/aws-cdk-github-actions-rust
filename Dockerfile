FROM alpine
RUN apk --update --no-cache add nodejs npm python3 py3-pip jq curl bash git docker zig && \
	ln -sf /usr/bin/python3 /usr/bin/python

RUN apkArch=$(apk --print-arch) && curl -L https://ziglang.org/download/$ZIG_VERSION/zig-linux-$apkArch-$ZIG_VERSION.tar.xz | tar -J -x -C /usr/local \
   && ln -s /usr/local/zig-linux-$apkArch-$ZIG_VERSION/zig /usr/local/bin/zig ;

RUN curl https://sh.rustup.rs -sSf | sh -s -- --profile minimal -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
RUN cargo binstall cargo-lambda -y
RUN cargo lambda --version

COPY --from=golang:alpine /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
