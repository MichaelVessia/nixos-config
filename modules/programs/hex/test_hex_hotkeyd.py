import unittest

from hex_hotkeyd import Action, HotkeyConfig, HotkeyMachine, State

DEV_1 = 1
DEV_2 = 2
TRIGGER = 125
ESC = 1
TAB = 15
KEY_S = 31
KEY_L = 38
KEY_A = 30
LSHIFT = 42
LALT = 56


class HotkeyMachineTest(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = HotkeyConfig(hold_ms=250, double_tap_ms=350, trigger_code=TRIGGER, cancel_code=ESC)
        self.m = HotkeyMachine(self.cfg)

    def test_hold_and_release_starts_and_stops(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 100), [])
        self.assertEqual(self.m.state, State.PENDING_HOLD)
        self.assertEqual(self.m.deadline_ms, 350)

        self.assertEqual(self.m.on_timeout(349), [])
        self.assertEqual(self.m.on_timeout(350), [Action.START])
        self.assertEqual(self.m.state, State.HOLDING)
        self.assertIsNone(self.m.deadline_ms)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 800), [Action.STOP])
        self.assertEqual(self.m.state, State.IDLE)

    def test_stray_tap_times_out_silently(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 100), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 180), [])
        self.assertEqual(self.m.state, State.AWAITING_DOUBLE_TAP)
        self.assertEqual(self.m.deadline_ms, 530)

        self.assertEqual(self.m.on_timeout(529), [])
        self.assertEqual(self.m.on_timeout(530), [])
        self.assertEqual(self.m.state, State.IDLE)
        self.assertIsNone(self.m.deadline_ms)

    def test_double_tap_locks_and_single_tap_stops(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 80), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 200), [])
        self.assertEqual(self.m.state, State.DOUBLE_TAP_DOWN)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 280), [Action.START])
        self.assertEqual(self.m.state, State.LOCKED)
        self.assertIsNone(self.m.deadline_ms)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 2000), [])
        self.assertEqual(self.m.state, State.LOCKED_TRIGGER_DOWN)
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 2090), [Action.STOP])
        self.assertEqual(self.m.state, State.IDLE)

    def test_double_tap_into_hold(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 80), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 150), [])
        self.assertEqual(self.m.state, State.DOUBLE_TAP_DOWN)

        self.assertEqual(self.m.on_timeout(400), [Action.START])
        self.assertEqual(self.m.state, State.HOLDING)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 700), [Action.STOP])
        self.assertEqual(self.m.state, State.IDLE)

    def test_fast_chords_do_not_trigger(self) -> None:
        # Alt+Shift+S
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_1, LSHIFT, 1, 40), [])
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertIsNone(self.m.deadline_ms)
        self.assertEqual(self.m.on_key(DEV_1, KEY_S, 1, 70), [])
        self.assertEqual(self.m.on_key(DEV_1, KEY_S, 0, 120), [])
        self.assertEqual(self.m.on_key(DEV_1, LSHIFT, 0, 140), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 160), [])
        self.assertEqual(self.m.state, State.IDLE)

        # Alt+Tab
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 500), [])
        self.assertEqual(self.m.on_key(DEV_1, TAB, 1, 550), [])
        self.assertEqual(self.m.on_timeout(900), [])
        self.assertEqual(self.m.on_key(DEV_1, TAB, 0, 920), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 950), [])
        self.assertEqual(self.m.state, State.IDLE)

    def test_slow_chord_after_hold_threshold_cancels(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_timeout(250), [Action.START])
        self.assertEqual(self.m.state, State.HOLDING)

        self.assertEqual(self.m.on_key(DEV_1, TAB, 1, 300), [Action.CANCEL])
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, TAB, 0, 350), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 380), [])
        self.assertEqual(self.m.state, State.IDLE)

    def test_chord_when_other_modifier_already_held(self) -> None:
        # Mod+Alt+L (physical Alt held first, then physical Windows, then L)
        self.assertEqual(self.m.on_key(DEV_1, LALT, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 30), [])
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertIsNone(self.m.deadline_ms)
        self.assertEqual(self.m.on_key(DEV_1, KEY_L, 1, 60), [])
        self.assertEqual(self.m.on_timeout(500), [])
        self.assertEqual(self.m.on_key(DEV_1, KEY_L, 0, 520), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 540), [])
        self.assertEqual(self.m.on_key(DEV_1, LALT, 0, 560), [])
        self.assertEqual(self.m.state, State.IDLE)

    def test_stray_tap_followed_by_fast_chord(self) -> None:
        # Other key pressed during double-tap window cancels the window
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 60), [])
        self.assertEqual(self.m.state, State.AWAITING_DOUBLE_TAP)
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 1, 100), [])
        self.assertEqual(self.m.state, State.IDLE)
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 0, 120), [])

        # Second press immediately chorded with another key does not lock
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 200), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 250), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 320), [])
        self.assertEqual(self.m.state, State.DOUBLE_TAP_DOWN)
        self.assertEqual(self.m.on_key(DEV_1, TAB, 1, 350), [])
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, TAB, 0, 390), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 410), [])
        self.assertEqual(self.m.state, State.IDLE)

    def test_escape_cancels_holding_and_locked(self) -> None:
        # Holding + Escape
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_timeout(250), [Action.START])
        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 300), [Action.CANCEL])
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, ESC, 0, 320), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 340), [])
        self.assertEqual(self.m.state, State.IDLE)

        # Locked + Escape
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 500), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 550), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 620), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 670), [Action.START])
        self.assertEqual(self.m.state, State.LOCKED)

        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 800), [Action.CANCEL])
        self.assertEqual(self.m.state, State.IDLE)
        self.assertEqual(self.m.on_key(DEV_1, ESC, 0, 840), [])

        # Locked + trigger down + Escape
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1000), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 1050), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1120), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 1170), [Action.START])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1500), [])
        self.assertEqual(self.m.on_key(DEV_1, ESC, 1, 1550), [Action.CANCEL])
        self.assertEqual(self.m.state, State.CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, ESC, 0, 1580), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 1600), [])
        self.assertEqual(self.m.state, State.IDLE)

    def test_typing_and_chords_while_locked_do_not_stop(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 60), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 130), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 190), [Action.START])
        self.assertEqual(self.m.state, State.LOCKED)

        # Normal typing
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 1, 300), [])
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 0, 340), [])
        self.assertEqual(self.m.state, State.LOCKED)

        # Trigger-first chord (Alt+Tab) stays locked
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 400), [])
        self.assertEqual(self.m.state, State.LOCKED_TRIGGER_DOWN)
        self.assertEqual(self.m.on_key(DEV_1, TAB, 1, 440), [])
        self.assertEqual(self.m.state, State.LOCKED_CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, TAB, 0, 480), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 500), [])
        self.assertEqual(self.m.state, State.LOCKED)

        # Other-modifier-first chord (Mod+Alt+L) stays locked
        self.assertEqual(self.m.on_key(DEV_1, LALT, 1, 600), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 620), [])
        self.assertEqual(self.m.state, State.LOCKED_CHORDED)
        self.assertEqual(self.m.on_key(DEV_1, KEY_L, 1, 640), [])
        self.assertEqual(self.m.on_key(DEV_1, KEY_L, 0, 680), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 700), [])
        self.assertEqual(self.m.on_key(DEV_1, LALT, 0, 720), [])
        self.assertEqual(self.m.state, State.LOCKED)

    def test_recovery_from_externally_stopped_locked_via_hold(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 60), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 130), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 190), [Action.START])
        self.assertEqual(self.m.state, State.LOCKED)

        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 1000), [])
        self.assertEqual(self.m.state, State.LOCKED_TRIGGER_DOWN)
        self.assertEqual(self.m.on_timeout(1250), [Action.START])
        self.assertEqual(self.m.state, State.HOLDING)
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 1600), [Action.STOP])
        self.assertEqual(self.m.state, State.IDLE)

    def test_auto_repeat_is_ignored(self) -> None:
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 2, 100), [])
        self.assertEqual(self.m.state, State.PENDING_HOLD)
        self.assertEqual(self.m.on_timeout(250), [Action.START])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 2, 300), [])
        self.assertEqual(self.m.on_key(DEV_1, KEY_A, 2, 310), [])
        self.assertEqual(self.m.state, State.HOLDING)
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 400), [Action.STOP])

    def test_multi_device_tracking_and_device_removal(self) -> None:
        # Trigger held on two devices; releasing one does not stop holding
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 0), [])
        self.assertEqual(self.m.on_key(DEV_2, TRIGGER, 1, 50), [])
        self.assertEqual(self.m.on_timeout(250), [Action.START])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 300), [])
        self.assertEqual(self.m.state, State.HOLDING)

        # Disconnecting the remaining device releases trigger and emits STOP
        self.assertEqual(self.m.on_device_removed(DEV_2, 350), [Action.STOP])
        self.assertEqual(self.m.state, State.IDLE)

        # Disconnecting a device with a stuck other key clears other_keys
        self.assertEqual(self.m.on_key(DEV_2, LSHIFT, 1, 500), [])
        self.assertEqual(self.m.on_device_removed(DEV_2, 520), [])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 1, 600), [])
        self.assertEqual(self.m.state, State.PENDING_HOLD)
        self.assertEqual(self.m.on_timeout(850), [Action.START])
        self.assertEqual(self.m.on_key(DEV_1, TRIGGER, 0, 900), [Action.STOP])


if __name__ == "__main__":
    unittest.main()
