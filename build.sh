#!/bin/bash

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o server
cd client
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o client
