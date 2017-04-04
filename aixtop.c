/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <libperfstat.h>
#include <stdio.h>
#include <stdlib.h>

/* Based on https://www.ibm.com/developerworks/community/wikis/home?lang=en#/wiki/Power%20Systems/page/Programming%20CPU%20Utilization 
 * This is a hybrid of ps and topas to give instataneous/recent CPU usage rather than process lifetime / CPU seconds of ps.  
 */

void main (int argc, char *argv[])
{
    perfstat_process_t *ppts;
    perfstat_process_t *oldppts;
    perfstat_process_t util;
    perfstat_id_t *ids;
    int interval = 0;
    int count = 0;
    int i = 0;

    if (argc < 4) { 
        fprintf(stderr, "%s: interval count pid1 [pid 2... pidN]\n", argv[0]);
        exit(1);
    }

    interval = atoi(argv[1]);
    count = atoi(argv[2]);

    if (interval <= 0 || count <= 0) { 
        fprintf(stderr, "%s: interval and count must be >0\n", argv[0]);
        exit(1);
    }

    /* over-allocated to match indeces */
    ppts = calloc(argc+1, sizeof(perfstat_process_t));
    oldppts = calloc(argc+1, sizeof(perfstat_process_t));
    ids = calloc(argc+1, sizeof(perfstat_id_t));

    for (i = 3; i < argc; i++) { 
        strcpy(ids[i].name, argv[i]);
        perfstat_process(&ids[i], &oldppts[i], sizeof(perfstat_process_t),1);
    } 

    /* Print the headers */
    printf ("Pid        Cmd    SizeKB    Priority    User%%      Kernel%% \n");

    for (; count > 0; count--) { 
        sleep(interval);
        for (i = 3; i < argc; i++) { 
            perfstat_rawdata_t buf;
            perfstat_process(&ids[i], &ppts[i], sizeof(perfstat_process_t),1);
            bzero(&buf, sizeof(perfstat_rawdata_t));
            buf.type = UTIL_PROCESS;
            buf.curstat = &ppts[i];
            buf.prevstat = &oldppts[i];
            buf.sizeof_data = sizeof(perfstat_process_t);
            buf.cur_elems = 1;
            buf.prev_elems = 1;
            perfstat_process_util(&buf,&util,sizeof(perfstat_process_t),1);
            printf("%8lld %6s %9lld  %9d   %10.2f %10.2f \n",util.pid, util.proc_name, util.proc_size, util.proc_priority, (double)util.ucpu_time, (double)util.scpu_time);
            memcpy(oldppts[i], ppts[i], sizeof(perfstat_process_t));
        }
        printf("\n");
    }
}
