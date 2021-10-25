FROM golang:alpine

COPY . /code

WORKDIR /code

RUN go build

ENTRYPOINT ["/code/cli"]
