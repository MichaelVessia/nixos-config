import unittest

from hex_hotkeyd import Action, HotkeyConfig, HotkeyMachine, State, StepResult, parse_args

DEV_1 = 1
DEV_2 = 2
TRIGGER = 125
ESC = 1
TAB = 15
KEY_S = 31
KEY_V = 47
KEY_L = 38
KEY_A = 30
LSHIFT = 42
LALT = 56


class HotkeyMachineTest(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = HotkeyConfig(hold_ms=250, double_tap_ms=350, trigger_code=TRIGGER, cancel_code=ESC)
        self.m = HotkeyMachine(self.cfg)

    def test_hold_and_release_starts_and_stops_without_emitting_keys(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 100), StepResult())
        self.assertEqual(self.m.state, State.PENDING_HOLD)
        self.assertEqual(self.m.deadline_ms, 350)

        self.assertEqual(self.m.on_timeout(349), StepResult())
        self.assertEqual(self.m.on_timeout(350), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.state, State.HOLDING)
        self.assertIsNone(self.m.deadline_ms)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 800), StepResult(actions=(Action.STOP,)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_stray_tap_times_out_silently_without_emitting_keys(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 100), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 180), StepResult())
        self.assertEqual(self.m.state, State.AWAITING_DOUBLE_TAP)
        self.assertEqual(self.m.deadline_ms, 530)

        self.assertEqual(self.m.on_timeout(529), StepResult())
        self.assertEqual(self.m.on_timeout(530), StepResult())
        self.assertEqual(self.m.state, State.IDLE)
        self.assertIsNone(self.m.deadline_ms)

    def test_double_tap_locks_and_single_tap_stops_without_emitting_keys(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 80), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 200), StepResult())
        self.assertEqual(self.m.state, State.DOUBLE_TAP_DOWN)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 280), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.state, State.LOCKED)
        self.assertIsNone(self.m.deadline_ms)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 2000), StepResult())
        self.assertEqual(self.m.state, State.LOCKED_TRIGGER_DOWN)
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 2090), StepResult(actions=(Action.STOP,)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_double_tap_into_hold_emits_no_keys(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 80), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 150), StepResult())
        self.assertEqual(self.m.state, State.DOUBLE_TAP_DOWN)

        self.assertEqual(self.m.on_timeout(400), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.state, State.HOLDING)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 700), StepResult(actions=(Action.STOP,)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_fast_chords_flush_trigger_and_do_not_trigger_dictation(self) -> None:
        # Alt+Shift+S
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(
            self.m.on_key(DEV_1, LSHIFT, 1, 40),
            StepResult(emits=((TRIGGER, 1), (LSHIFT, 1))),
        )
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertIsNone(self.m.deadline_ms)
        self.assertEqual(self.m.on_key(DEV_1, KEY_S, 1, 70), StepResult(emits=((KEY_S, 1),)))
        self.assertEqual(self.m.on_key(DEV_1, KEY_S, 0, 120), StepResult(emits=((KEY_S, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, LSHIFT, 0, 140), StepResult(emits=((LSHIFT, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 160), StepResult(emits=((TRIGGER, 0),)))
        self.assertEqual(self.m.state, State.IDLE)

        # Alt+Shift+V
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 300), StepResult())
        self.assertEqual(
            self.m.on_key(DEV_1, LSHIFT, 1, 330),
            StepResult(emits=((TRIGGER, 1), (LSHIFT, 1))),
        )
        self.assertEqual(self.m.on_key(DEV_1, KEY_V, 1, 360), StepResult(emits=((KEY_V, 1),)))
        self.assertEqual(self.m.on_key(DEV_1, KEY_V, 0, 400), StepResult(emits=((KEY_V, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, LSHIFT, 0, 420), StepResult(emits=((LSHIFT, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 440), StepResult(emits=((TRIGGER, 0),)))
        self.assertEqual(self.m.state, State.IDLE)

        # Alt+Tab
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 500), StepResult())
        self.assertEqual(
            self.m.on_key(DEV_1, TAB, 1, 550),
            StepResult(emits=((TRIGGER, 1), (TAB, 1))),
        )
        self.assertEqual(self.m.on_timeout(900), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TAB, 0, 920), StepResult(emits=((TAB, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 950), StepResult(emits=((TRIGGER, 0),)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_slow_chord_after_hold_threshold_cancels_and_flushes_trigger(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(self.m.on_timeout(250), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.state, State.HOLDING)

        self.assertEqual(
            self.m.on_key(DEV_1, TAB, 1, 300),
            StepResult(actions=(Action.CANCEL,), emits=((TRIGGER, 1), (TAB, 1))),
        )
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, TAB, 0, 350), StepResult(emits=((TAB, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 380), StepResult(emits=((TRIGGER, 0),)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_chord_when_other_modifier_already_held_emits_trigger_immediately(self) -> None:
        # Mod+Alt+L (physical Alt held first, then physical Windows, then L)
        self.assertEqual(self.m.on_key(DEV_1, LALT, 1, 0), StepResult(emits=((LALT, 1),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 30), StepResult(emits=((TRIGGER, 1),)))
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertIsNone(self.m.deadline_ms)
        self.assertEqual(self.m.on_key(DEV_1, KEY_L, 1, 60), StepResult(emits=((KEY_L, 1),)))
        self.assertEqual(self.m.on_timeout(500), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, KEY_L, 0, 520), StepResult(emits=((KEY_L, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 540), StepResult(emits=((TRIGGER, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, LALT, 0, 560), StepResult(emits=((LALT, 0),)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_stray_tap_followed_by_fast_chord(self) -> None:
        # Other key pressed during double-tap window cancels the window and passes through
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 60), StepResult())
        self.assertEqual(self.m.state, State.AWAITING_DOUBLE_TAP)
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 1, 100), StepResult(emits=((KEY_A, 1),)))
        self.assertEqual(self.m.state, State.IDLE)
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 0, 120), StepResult(emits=((KEY_A, 0),)))

        # Second press immediately chorded with another key does not lock and flushes trigger
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 200), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 250), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 320), StepResult())
        self.assertEqual(self.m.state, State.DOUBLE_TAP_DOWN)
        self.assertEqual(
            self.m.on_key(DEV_1, TAB, 1, 350),
            StepResult(emits=((TRIGGER, 1), (TAB, 1))),
        )
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, TAB, 0, 390), StepResult(emits=((TAB, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 410), StepResult(emits=((TRIGGER, 0),)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_escape_cancels_and_swallows_during_holding_and_locked(self) -> None:
        # Holding + Escape swallows Escape down and up and emits no trigger
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(self.m.on_timeout(250), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 300), StepResult(actions=(Action.CANCEL,)))
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, ESC, 0, 320), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 340), StepResult())
        self.assertEqual(self.m.state, State.IDLE)

        # Locked + Escape swallows Escape down and up
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 500), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 550), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 620), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 670), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.state, State.LOCKED)

        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 800), StepResult(actions=(Action.CANCEL,)))
        self.assertEqual(self.m.state, State.IDLE)
        self.assertEqual(self.m.on_key(DEV_1, ESC, 0, 840), StepResult())

        # Locked + trigger down + Escape swallows Escape down and up and emits no trigger
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1000), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 1050), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1120), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 1170), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1500), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 1550), StepResult(actions=(Action.CANCEL,)))
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, ESC, 0, 1580), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 1600), StepResult())
        self.assertEqual(self.m.state, State.IDLE)

    def test_escape_during_idle_passes_through(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 100), StepResult(emits=((ESC, 1),)))
        self.assertEqual(self.m.state, State.IDLE)
        self.assertEqual(self.m.on_key(DEV_1, ESC, 0, 150), StepResult(emits=((ESC, 0),)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_typing_and_chords_while_locked_pass_through_and_do_not_stop(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 60), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 130), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 190), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.state, State.LOCKED)

        # Normal typing
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 1, 300), StepResult(emits=((KEY_A, 1),)))
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 0, 340), StepResult(emits=((KEY_A, 0),)))
        self.assertEqual(self.m.state, State.LOCKED)

        # Trigger-first chord (Alt+Tab) flushes trigger and stays locked
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 400), StepResult())
        self.assertEqual(self.m.state, State.LOCKED_TRIGGER_DOWN)
        self.assertEqual(
            self.m.on_key(DEV_1, TAB, 1, 440),
            StepResult(emits=((TRIGGER, 1), (TAB, 1))),
        )
        self.assertEqual(self.m.state, State.LOCKED_CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, TAB, 0, 480), StepResult(emits=((TAB, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 500), StepResult(emits=((TRIGGER, 0),)))
        self.assertEqual(self.m.state, State.LOCKED)

        # Other-modifier-first chord (Mod+Alt+L) emits trigger immediately and stays locked
        self.assertEqual(self.m.on_key(DEV_1, LALT, 1, 600), StepResult(emits=((LALT, 1),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 620), StepResult(emits=((TRIGGER, 1),)))
        self.assertEqual(self.m.state, State.LOCKED_CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, KEY_L, 1, 640), StepResult(emits=((KEY_L, 1),)))
        self.assertEqual(self.m.on_key(DEV_1, KEY_L, 0, 680), StepResult(emits=((KEY_L, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 700), StepResult(emits=((TRIGGER, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, LALT, 0, 720), StepResult(emits=((LALT, 0),)))
        self.assertEqual(self.m.state, State.LOCKED)

    def test_recovery_from_externally_stopped_locked_via_hold(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 60), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 130), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 190), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.state, State.LOCKED)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1000), StepResult())
        self.assertEqual(self.m.state, State.LOCKED_TRIGGER_DOWN)
        self.assertEqual(self.m.on_timeout(1250), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.state, State.HOLDING)
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 1600), StepResult(actions=(Action.STOP,)))
        self.assertEqual(self.m.state, State.IDLE)

    def test_auto_repeat_passthrough_and_suppression(self) -> None:
        # Unswallowed non-trigger key repeats pass through without changing state
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 1, 0), StepResult(emits=((KEY_A, 1),)))
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 2, 50), StepResult(emits=((KEY_A, 2),)))
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 0, 80), StepResult(emits=((KEY_A, 0),)))

        # Trigger repeats are suppressed and do not change state
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 100), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 2, 200), StepResult())
        self.assertEqual(self.m.state, State.PENDING_HOLD)
        self.assertEqual(self.m.on_timeout(350), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 2, 400), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 2, 410), StepResult(emits=((KEY_A, 2),)))
        self.assertEqual(self.m.state, State.HOLDING)

        # Swallowed Escape repeats are suppressed
        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 450), StepResult(actions=(Action.CANCEL,)))
        self.assertEqual(self.m.on_key(DEV_1, ESC, 2, 500), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, ESC, 0, 520), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 550), StepResult())
        self.assertEqual(self.m.state, State.IDLE)

        # Invalid event values are ignored
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 3, 600), StepResult())

    def test_multi_device_tracking_and_device_removal(self) -> None:
        # Trigger held on two devices; releasing one does not stop holding
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), StepResult())
        self.assertEqual(self.m.on_key(DEV_2, TRIGGER, 1, 50), StepResult())
        self.assertEqual(self.m.on_timeout(250), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 300), StepResult())
        self.assertEqual(self.m.state, State.HOLDING)

        # Disconnecting the remaining device releases trigger and emits STOP without emitting trigger
        self.assertEqual(self.m.on_device_removed(DEV_2, 350), StepResult(actions=(Action.STOP,)))
        self.assertEqual(self.m.state, State.IDLE)

        # Disconnecting a device with an emitted held key releases that key and clears other_keys
        self.assertEqual(self.m.on_key(DEV_2, LSHIFT, 1, 500), StepResult(emits=((LSHIFT, 1),)))
        self.assertEqual(self.m.on_device_removed(DEV_2, 520), StepResult(emits=((LSHIFT, 0),)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 600), StepResult())
        self.assertEqual(self.m.state, State.PENDING_HOLD)
        self.assertEqual(self.m.on_timeout(850), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 900), StepResult(actions=(Action.STOP,)))

        # Disconnecting a device holding an emitted chord releases both key and trigger
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1000), StepResult())
        self.assertEqual(
            self.m.on_key(DEV_1, TAB, 1, 1030),
            StepResult(emits=((TRIGGER, 1), (TAB, 1))),
        )
        self.assertEqual(
            self.m.on_device_removed(DEV_1, 1060),
            StepResult(emits=((TAB, 0), (TRIGGER, 0))),
        )
        self.assertEqual(self.m.state, State.IDLE)
        self.assertFalse(self.m.trigger_emitted)

        # Disconnecting a device holding a key also held on another device does not release it early
        self.assertEqual(self.m.on_key(DEV_1, LSHIFT, 1, 1200), StepResult(emits=((LSHIFT, 1),)))
        self.assertEqual(self.m.on_key(DEV_2, LSHIFT, 1, 1210), StepResult(emits=((LSHIFT, 1),)))
        self.assertEqual(self.m.on_device_removed(DEV_2, 1220), StepResult())
        self.assertEqual(self.m.on_key(DEV_1, LSHIFT, 0, 1250), StepResult(emits=((LSHIFT, 0),)))

        # Disconnecting a device holding a swallowed Escape does not emit Escape up
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1400), StepResult())
        self.assertEqual(self.m.on_timeout(1650), StepResult(actions=(Action.START,)))
        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 1700), StepResult(actions=(Action.CANCEL,)))
        self.assertEqual(self.m.on_device_removed(DEV_1, 1720), StepResult())
        self.assertEqual(self.m.state, State.IDLE)

    def test_parse_args_no_grab_flag(self) -> None:
        self.assertFalse(parse_args([]).no_grab)
        self.assertTrue(parse_args(["--no-grab"]).no_grab)


if __name__ == "__main__":
    unittest.main()
