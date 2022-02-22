#!/bin/bash
runclj-auto-start frontend.cljs &
ls frontend.cljs | entr -r runclj frontend.cljs
