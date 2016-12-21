#!/bin/bash

source /opt/rh/rh-ruby22/enable
export X_SCLS="`scl enable rh-ruby22 'echo $X_SCLS'`"
export PATH=$PATH:/opt/rh/rh-ruby22/root/usr/local/bin
