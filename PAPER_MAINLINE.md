# JRD-HI paper mainline

The active paper comparison is now:

- Direct: `EvolutionaryX_Direct` over partitions (X/\{G_k\}), with grid-exact (T_k,f_k).
- Indirect: the unchanged teacher `AHDE.m`, called through `RunTeacherAHDE`.

Start MATLAB in this directory and run:

```matlab
Setup_JRD;
Test_Paper_Revision;
[E1,out1] = Run_Paper_Experiment1_N10;
```

The four paper runners are:

```matlab
Run_Paper_Experiment1_N10
Run_Paper_Experiment2_DirectPerformance
Run_Paper_Experiment3_StrategyComparison
Run_Paper_Experiment4_Coordination
```

Experiments 2–4 checkpoint after every completed seed. Resume an interrupted directory with the same parameters and `ResumeDir`. The configuration, source manifest and fixed data must match the checkpoint.

Read these first:

- `Docs/PROJECT_STATUS_2026-09-20.md`: current status, design decisions, evidence and risks.
- `Docs/JRD_HI_ZERO_TO_CODE_TUTORIAL.md`: zero-background mathematical and code walkthrough.

Generated paper results are written below `Results_Paper/` and are intentionally ignored by Git. Historical solvers and results are preserved.
