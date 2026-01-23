# arbiters
### 1. Fixed Priority Arbiter

Simple arbiter which grants access to the highest-priority requester that is active.

Source file: [Fixed Priority Arbiter](arbiter_fx_priority.sv)

### 2. Time Division Multiplexed (TDM) Arbiter

Arbiter which grants access to a requester only in fixed, pre-defined time slots regardless of request activity.

Source file: [Time Division Multiplexed (TDM) Arbiter](arbiter_tdm.sv)

### 3. Round Robin (RR) Arbiter

Arbiters grants active requesters in circular queue order, to provide basic fairness to every requester.

Source file: [Round Robin Arbiter](arbiter_rrobin.sv)

### 4. Weighted Round Robin (WRR) Arbiter

Similar to RR Arbiter, but extends the round robin scheduling by assigning pre-defined weights per-requester, allowing some to receive multiple consecutive grants.

Source file: [Weighted Round Robin Arbiter](arbiter_wghtd_rrobin.sv)

### 5. Interleaved Weighted Round Robin (IWRR) Arbiter

Similar to WRR Arbiter, but interleaves the grants across requesters according to their weights, reducing latency and avoiding long service bursts for any single requester.

Source file: [Interleaved Weighted Round Robin Arbiter](arbiter_intlv_wghtd_rrobin.sv)

### 6. Deficit Round Robin (DRR) Arbiter

Arbiter which uses per-requester deficit counters to fairly schedule variable-sized packets while maintaining proportional bandwidth.

Source file: [Deficit Round Robin Arbiter](arbiter_defct_rrobin.sv)


License
--------
All codes are fully synthesizable and tested. All are open-source codes, free to use, modify and distribute without any conflicts of interest with the original developer.

Developer
---------
Mitu Raj, iammituraj@gmail.com, chip@chipmunklogic.com
