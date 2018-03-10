FROM golang:latest

ENV GOROOT=/usr/local/go
#ENV GOPATH=/app

WORKDIR /go/src/app
COPY . .

RUN go get -d -v ./...
RUN go install -v ./...
RUN make distall

ADD dist/cacert.pem /etc/ssl/ca-bundle.pem
ADD dist/etcd.Linux.x86_64 /bin/etcd
ADD dist/etcd3-aws.Linux.x86_64 /bin/etcd-aws

ENV PATH=/bin
ENV TMPDIR=/

CMD ["/bin/etcd-aws"]

