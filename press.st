TYPE
  PressState : (
    IDLE,
    CLAMP,
    RETRACT,
    PRESS,
    LOCKOUT
  );
END_TYPE

(*
This program emulates the control logic for a hydraulic press.
*)

(*
Bugs introduced:
Sequencing bug: after END_CASE, the StallTimer sets State:=LOCKOUT, but never clears Ram_Down, Ram_Up, and Clamp_CMD. This means the empty lockout case will never clear them on later scans, so the press is stuck
in lockout with the ram still operating until ETop_OK or Enable ends.

Wrong sensor: RETRACT will exit on At_bottom instead of At_Top. At_Bottom will still be true on entry from PRESS state, so press goes PRESS->RETRACT->IDLE on sequential scans with the ram at the bottom & the part unclamped.
*)




FUNCTION_BLOCK FB_Press
VAR_INPUT
  Enable          : BOOL;
  EStop_OK        : BOOL;
  Start           : BOOL;
  Clamped         : BOOL;
  At_Bottom       : BOOL;
  At_Top          : BOOL;
END_VAR

VAR_OUTPUT
  Clamp_CMD       : BOOL;
  Ram_Down        : BOOL;
  Ram_Up          : BOOL;
  State_Out       : PressState;
  Fault           : BOOL;
END_VAR

VAR
  State           : PressState := IDLE;
  DwellTimer      : TON;
  StallTimer      : TON;
END_VAR

VAR CONSTANT
  PRESS_DWELL     : TIME := T#2S;
  STALL_TIMEOUT   : TIME := T#10S;
END_VAR

IF NOT EStop_OK OR NOT Enable THEN
  State     := LOCKOUT;
  Clamp_CMD := FALSE;
  Ram_Down  := FALSE;
  Ram_Up    := FALSE;
  Fault     := TRUE;
  State_Out := State;
  RETURN;
END_IF

Fault := FALSE;

CASE State OF

  IDLE:
    Clamp_CMD := FALSE;
    Ram_Down  := FALSE;
    Ram_Up    := FALSE;
    IF Start THEN
      State := CLAMP;
    END_IF

  CLAMP:
    Clamp_CMD := TRUE;
    Ram_Down  := FALSE;
    Ram_Up    := FALSE;
    IF Clamped THEN
      State := PRESS;
    END_IF

  RETRACT:
    Ram_Down := FALSE;
    Ram_Up   := TRUE;
    IF At_Bottom THEN
      Ram_Up    := FALSE;
      Clamp_CMD := FALSE;
      State     := IDLE;
    END_IF

  PRESS:
    Clamp_CMD := TRUE;
    Ram_Down  := TRUE;
    Ram_Up    := FALSE;
    DwellTimer(IN := At_Bottom, PT := PRESS_DWELL);
    IF DwellTimer.Q THEN
      Ram_Down := FALSE;
      DwellTimer(IN := FALSE);
      State := RETRACT;
    END_IF

  LOCKOUT:
    ;

END_CASE

StallTimer(
  IN := (Ram_Down OR Ram_Up),
  PT := STALL_TIMEOUT
);
IF StallTimer.Q THEN
  Fault := TRUE;
  State := LOCKOUT;
END_IF

State_Out := State;

END_FUNCTION_BLOCK
