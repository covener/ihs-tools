#!/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script should be run by the same userid as the webserver. It will clear any queue that was last
# accessed by a PID that is no longer running.

# IHS child processes use message queues in an unusual single-process way. Normally, the queue would be used
# by multiple processes and outlive any of them.

while read line ; do
  ID=$(echo "$line" |  awk "/$USER/{print \$2}")
  LASTPID=$(echo "$line" |  awk "/$USER/{print \$NF}")
  if [ -n "$ID" ]; then
    if ! kill -0 $LASTPID >/dev/null 2>/dev/null; then
      echo "PID $LASTPID not running, reclaim queue $ID"
      ipcrm -q $ID
    fi
  fi
done <<< $(ipcs -qp)



