#!/usr/bin/env python

import boto
import boto.ec2

regions = [region.name for region in boto.ec2.regions()]

for region in regions:
    print region
