#!/bin/bash
ls test.py | entr -r xvfb-run -d python3 test.py
