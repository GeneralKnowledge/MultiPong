# Pong tests

Machine-readable behavioural tests for canonical Pong.

| ID | File | Focus |
| --- | --- | --- |
| `BALL_MOVES_HORIZONTAL` | [BALL_MOVES_HORIZONTAL.json](BALL_MOVES_HORIZONTAL.json) | Integration |
| `TOP_WALL_COLLISION` | [TOP_WALL_COLLISION.json](TOP_WALL_COLLISION.json) | Wall reflect |
| `BOTTOM_WALL_COLLISION` | [BOTTOM_WALL_COLLISION.json](BOTTOM_WALL_COLLISION.json) | Wall reflect |
| `CENTRE_PADDLE_HIT_P1` | [CENTRE_PADDLE_HIT_P1.json](CENTRE_PADDLE_HIT_P1.json) | Paddle bounce |
| `ANGLED_PADDLE_HIT_P1` | [ANGLED_PADDLE_HIT_P1.json](ANGLED_PADDLE_HIT_P1.json) | Deflection angle |
| `PADDLE_MOVE_UP` | [PADDLE_MOVE_UP.json](PADDLE_MOVE_UP.json) | Movement + clamp |
| `PADDLE_CLAMP_BOTTOM` | [PADDLE_CLAMP_BOTTOM.json](PADDLE_CLAMP_BOTTOM.json) | Clamp |
| `SCORE_RIGHT_GOAL` | [SCORE_RIGHT_GOAL.json](SCORE_RIGHT_GOAL.json) | Scoring |
| `SCORE_LEFT_GOAL` | [SCORE_LEFT_GOAL.json](SCORE_LEFT_GOAL.json) | Scoring |
| `GAME_OVER_AT_ELEVEN` | [GAME_OVER_AT_ELEVEN.json](GAME_OVER_AT_ELEVEN.json) | Win condition |
| `PAUSE_FREEZES_TICK` | [PAUSE_FREEZES_TICK.json](PAUSE_FREEZES_TICK.json) | Pause |
| `MENU_CONFIRM_STARTS` | [MENU_CONFIRM_STARTS.json](MENU_CONFIRM_STARTS.json) | Mode transition |
| `POINT_PAUSE_RESUMES` | [POINT_PAUSE_RESUMES.json](POINT_PAUSE_RESUMES.json) | Point pause |
| `OPPOSING_INPUTS_CANCEL` | [OPPOSING_INPUTS_CANCEL.json](OPPOSING_INPUTS_CANCEL.json) | Input |

Schema: [../test.schema.json](../test.schema.json)  
Methodology: [../../../TESTING.md](../../../TESTING.md)

Implementations MUST pass all tests in this directory before claiming faithfulness.
