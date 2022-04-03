#!/usr/bin/env python3

import sys

from components.scheduler import Scheduler
from components.srt_scheduler import SRTScheduler
from components.rr_scheduler import RRScheduler

schedulers = [
    # First-Come-First-Served Scheduler
    Scheduler(sys.argv[1], "First-Come-First-Served",
              lambda e, acc: e.total_wait() > acc,
              lambda e: e.total_wait(),
              0),
    # Shortest Process Next Scheduler
    Scheduler(sys.argv[1], "Shortest Process Next",
              lambda e, acc: e.service_time < acc,
              lambda e: e.service_time,
              sys.maxsize),
    # Highest Response Ratio Next
    Scheduler(sys.argv[1], "Highest Response Ratio Next",
              lambda e, acc: ((e.total_wait() + e.service_time) / e.service_time) > acc,
              lambda e: (e.total_wait() + e.service_time) / e.service_time,
              0),
    # Shortest Remaining Time
    SRTScheduler(sys.argv[1], "Shortest Remaining Time",
                 lambda e, acc: e.remaining_time < acc,
                 lambda e: e.remaining_time,
                 sys.maxsize),
    # Round Robin q = 1
    RRScheduler(sys.argv[1], "Round Robin q = 1",
                sys.maxsize,
                1),
    # Round Robin q = 4
    RRScheduler(sys.argv[1], "Round Robin q = 4",
                sys.maxsize,
                4),
]

for s in schedulers:
    s.run()
    s.dump(sys.argv[2])
    print(s)
