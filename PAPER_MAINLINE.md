# JRD-HI paper mainline

The active paper comparison is now:

- Direct: `EvolutionaryX_Direct` over partitions (X/\{G_k\}), with grid-exact (T_k,f_k).
- Indirect: the unchanged teacher `AHDE.m`, called through `RunTeacherAHDE`.

Start MATLAB in this directory and run:

```matlab
Setup_JRD;
[audit,auditDir] = Run_Preliminary_Audit_Tests;
```

Experiment 1 is frozen: keep the existing N=10 grid certificate and five-seed
results. Do not rerun it merely to prepare Experiments 2–4.

Authorized 2026-10-01 unattended preliminary: after completed profiling and
passing the final tests, `Start_JRD_Preliminary_Queue.ps1` runs a persistent
background queue. A complete 12-run G100/P4N calibration determines a same-
budget extension to 36/108. The live index is `REPORT.md` / `live_progress.md`
inside its unique `Results_Unattended` directory. Every solver commits MAT/CSV;
source/configuration is frozen; deadlines select stages, never stop solvers.
See `Docs/UNATTENDED_PRELIMINARY_2026-10-01.md`. This is not a final formal budget.

Experiment 2 now compares Evolutionary-X, GA/JADE **partition adapters**, and
structural VND using the same `DirectGridPartitionCost` objective throughout
search and convergence. Historical 2N GA/JADE runs are not those adapters.
`CommonGridTC` is the formal objective; continuous/native costs are auxiliary.
Instances and algorithm seeds are separate axes. `Design='pilot'` is the
default; `Design='paper-reference'` exposes 500 generations / population 10N,
20 independent instances and S factors 0.1–0.5 as a reference, not a validated
final budget. Different algorithms still perform different amounts of work.

Experiment 4 uses the same original AHDE in both frequency modes; the fixed
case changes only `FInf=FSup=1`. `AHDE_FixedF1` is supplementary. All four
outer problems are independently reoptimized. Positive feasible-set violations
are flagged as heuristic search insufficiency, not repaired by hiding results.

The four paper runners are:

```matlab
Run_Paper_Experiment1_N10
Run_Paper_Experiment2_DirectPerformance
Run_Paper_Experiment3_StrategyComparison
Run_Paper_Experiment4_Coordination
```

Experiments 2–4 checkpoint after each completed solver call. Resume an
interrupted directory with the same parameters and `ResumeDir`. A call
interrupted inside the teacher AHDE restarts that call. Configuration, source
manifest, schema and fixed data must match; historical checkpoints stay with
their historical code versions.

`Profile_Paper_Solvers` measures the requested reference budget in real wall
clock time, saving each completed job under a new `Results_Profiling` folder.
It does not launch a formal experiment afterward. Do not run any default large
runner until reviewing those timings and selecting preliminary budgets.

Read these first:

- `Docs/PRE_RUN_AUDIT_2026-10-01.md`: latest audit, verified tests, timings and risks.
- `Docs/EXP3_EXP4_PRELIMINARY_PROTOCOL_2026-10-01.md`: strategy/coordination protocol.
- `Docs/PROJECT_STATUS_2026-09-20.md`: historical status, not latest run readiness.
- `Docs/JRD_HI_ZERO_TO_CODE_TUTORIAL.md`: zero-background mathematical and code walkthrough.

Generated paper results are written below `Results_Paper/` and are intentionally ignored by Git. Historical solvers and results are preserved.
