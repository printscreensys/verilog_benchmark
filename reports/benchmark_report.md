# Benchmark Report

`null` indicates that the metric was unavailable in the source result.

## gpt-5.4

| task     | syntax_correct | functionally_correct | lint_clean | synth_check_passed | timing_constraints_met |
|----------|----------------|----------------------|------------|--------------------|------------------------|
| task_01  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_06  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_11  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_12  | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_24  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_34  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_40  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_41  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_50  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_51  | ✅              | ❌                    | ✅          | ❌                  | null                   |
| task_52  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_53  | ✅              | ✅                    | ❌          | ❌                  | null                   |
| task_60  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_61  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_62  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_63  | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_70  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_71  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_72  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_73  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_80  | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_90  | ✅              | ✅                    | ✅          | ✅                  | ✅                      |
| task_100 | ✅              | ❌                    | ❌          | ❌                  | null                   |
| task_101 | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_110 | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_111 | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_121 | null           | null                 | null       | null               | null                   |

## mistral-medium-latest

| task     | syntax_correct | functionally_correct | lint_clean | synth_check_passed | timing_constraints_met |
|----------|----------------|----------------------|------------|--------------------|------------------------|
| task_01  | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_06  | ❌              | ❌                    | ✅          | ✅                  | null                   |
| task_11  | ❌              | ❌                    | ✅          | ❌                  | null                   |
| task_12  | ✅              | ❌                    | ❌          | ❌                  | null                   |
| task_24  | ✅              | ✅                    | ✅          | ❌                  | null                   |
| task_34  | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_40  | ❌              | ❌                    | ✅          | ❌                  | null                   |
| task_41  | ❌              | ❌                    | ✅          | ✅                  | null                   |
| task_50  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_51  | ✅              | ❌                    | ✅          | ❌                  | null                   |
| task_52  | ❌              | ❌                    | ❌          | ❌                  | null                   |
| task_53  | ❌              | ❌                    | ❌          | ❌                  | null                   |
| task_60  | ✅              | ✅                    | ✅          | ✅                  | null                   |
| task_61  | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_62  | ✅              | ❌                    | ❌          | ✅                  | null                   |
| task_63  | ✅              | ❌                    | ❌          | ✅                  | null                   |
| task_70  | ❌              | ❌                    | ❌          | ✅                  | null                   |
| task_71  | ❌              | ❌                    | ❌          | ✅                  | null                   |
| task_72  | ✅              | ❌                    | ❌          | ❌                  | null                   |
| task_73  | ✅              | ❌                    | ❌          | ❌                  | null                   |
| task_80  | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_90  | ✅              | ❌                    | ✅          | ✅                  | ❌                      |
| task_100 | ❌              | ❌                    | ❌          | ❌                  | null                   |
| task_101 | ✅              | ✅                    | ❌          | ❌                  | null                   |
| task_110 | ✅              | ❌                    | ❌          | ✅                  | null                   |
| task_111 | ✅              | ❌                    | ✅          | ✅                  | null                   |
| task_121 | null           | ❌                    | null       | null               | null                   |
