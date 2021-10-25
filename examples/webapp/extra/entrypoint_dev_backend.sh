#!/bin/bash
ls backend.go | entr -r go run backend.go
