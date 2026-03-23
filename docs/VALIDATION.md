# Validation Notes

This repo is strongest when it is framed as a real physical mechatronics project with modest but measurable behavior.

## First Measurements To Publish

| Area | Metric | How to collect |
|---|---|---|
| Drawing accuracy | cell placement error | distance from intended cell center to actual mark center |
| Repeatability | repeated move deviation | run the same move 10 times and measure spread |
| Calibration stability | drift over session | compare first and last few marks in the same session |
| Runtime | move duration | command issue to finished mark |

## Minimal Trial Matrix

| Test | Trials |
|---|---:|
| center cell mark | 10 |
| corner cell mark | 10 |
| repeated X pattern | 10 |
| repeated O pattern | 10 |

## Evidence To Capture

- top-down photo of the board after repeated marks
- side photo of the arm and pen linkage
- short demo video of one full turn
- one paragraph on calibration procedure and failure modes

## Honest Limits To Mention

- paper slip or board movement
- servo backlash
- pen pressure variability
- calibration drift over long sessions
