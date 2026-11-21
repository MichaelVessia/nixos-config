from __future__ import annotations

import argparse
from dataclasses import dataclass
from enum import Enum
import os
import queue
import selectors
import signal
import subprocess
import sys
import threading
import time
from typing import Any


class State(Enum):
    IDLE = "idle"
    PENDING_HOLD = "pending_hold"
    HOLDING = "holding"
    AWAITING_DOUBLE_TAP = "awaiting_double_tap"
    DOUBLE_TAP_DOWN = "double_tap_down"
    LOCKED = "locked"
    LOCKED_TRIGGER_DOWN = "locked_trigger_down"
    CHORDED = "chorded"
    LOCKED_CHORDED = "locked_chorded"


class Action(Enum):
    START = "start"
    STOP = "stop"
    CANCEL = "cancel"


@dataclass(frozen=True)
class HotkeyConfig:
    hold_ms: int = 250
    double_tap_ms: int = 350
    trigger_code: int = 125
    cancel_code: int = 1


@dataclass(frozen=True)
class StepResult:
    actions: tuple[Action, ...] = ()
    emits: tuple[tuple[int, int], ...] = ()


VIRTUAL_DEVICE_NAME = "hex-hotkeyd virtual keyboard"


class HotkeyMachine:
    def __init__(self, config: HotkeyConfig | None = None) -> None:
        self.config = config or HotkeyConfig()
        self.state: State = State.IDLE
        self.deadline_ms: int | None = None
        self.other_keys: set[tuple[int, int]] = set()
        self.trigger_devices: set[int] = set()
        self.trigger_emitted: bool = False
        self.swallowed_keys: set[tuple[int, int]] = set()

    def on_key(self, device_id: int, code: int, value: int, now_ms: int) -> StepResult:
        if value not in (0, 1, 2):
            return StepResult()

        if value == 2:
            if (
                code != self.config.trigger_code
                and (device_id, code) not in self.swallowed_keys
            ):
                return StepResult(emits=((code, 2),))
            return StepResult()

        timeout = self.on_timeout(now_ms)
        actions = list(timeout.actions)
        emits: list[tuple[int, int]] = []

        if code == self.config.trigger_code:
            if value == 1:
                was_empty = not self.trigger_devices
                self.trigger_devices.add(device_id)
                if was_empty:
                    step = self._on_trigger_down(now_ms)
                    actions.extend(step.actions)
                    emits.extend(step.emits)
            else:
                if device_id in self.trigger_devices:
                    self.trigger_devices.remove(device_id)
                    if not self.trigger_devices:
                        step = self._on_trigger_up(now_ms)
                        actions.extend(step.actions)
                        emits.extend(step.emits)
            return StepResult(actions=tuple(actions), emits=tuple(emits))

        if value == 1:
            self.other_keys.add((device_id, code))
            step = self._on_other_key_down(device_id, code)
            actions.extend(step.actions)
            emits.extend(step.emits)
        else:
            self.other_keys.discard((device_id, code))
            key = (device_id, code)
            if key in self.swallowed_keys:
                self.swallowed_keys.remove(key)
            else:
                emits.append((code, 0))
        return StepResult(actions=tuple(actions), emits=tuple(emits))

    def on_timeout(self, now_ms: int) -> StepResult:
        if self.deadline_ms is None or now_ms < self.deadline_ms:
            return StepResult()

        self.deadline_ms = None
        if self.state in (
            State.PENDING_HOLD,
            State.DOUBLE_TAP_DOWN,
            State.LOCKED_TRIGGER_DOWN,
        ):
            self.state = State.HOLDING
            return StepResult(actions=(Action.START,))
        if self.state == State.AWAITING_DOUBLE_TAP:
            self.state = State.IDLE
            return StepResult()
        return StepResult()

    def on_device_removed(self, device_id: int, now_ms: int) -> StepResult:
        timeout = self.on_timeout(now_ms)
        actions = list(timeout.actions)
        emits: list[tuple[int, int]] = []

        removed_codes = sorted(code for dev, code in self.other_keys if dev == device_id)
        if removed_codes:
            self.other_keys = {k for k in self.other_keys if k[0] != device_id}
            remaining_codes = {code for _, code in self.other_keys}
            for code in removed_codes:
                key = (device_id, code)
                if key in self.swallowed_keys:
                    self.swallowed_keys.remove(key)
                elif code not in remaining_codes:
                    emits.append((code, 0))
        self.swallowed_keys = {k for k in self.swallowed_keys if k[0] != device_id}

        if device_id in self.trigger_devices:
            self.trigger_devices.remove(device_id)
            if not self.trigger_devices:
                step = self._on_trigger_up(now_ms)
                actions.extend(step.actions)
                emits.extend(step.emits)
        return StepResult(actions=tuple(actions), emits=tuple(emits))

    def _on_trigger_down(self, now_ms: int) -> StepResult:
        if self.other_keys:
            self.deadline_ms = None
            if self.state == State.LOCKED:
                self.state = State.LOCKED_CHORDED
            else:
                self.state = State.CHORDED
            self.trigger_emitted = True
            return StepResult(emits=((self.config.trigger_code, 1),))

        if self.state == State.IDLE:
            self.state = State.PENDING_HOLD
            self.deadline_ms = now_ms + self.config.hold_ms
        elif self.state == State.AWAITING_DOUBLE_TAP:
            self.state = State.DOUBLE_TAP_DOWN
            self.deadline_ms = now_ms + self.config.hold_ms
        elif self.state == State.LOCKED:
            self.state = State.LOCKED_TRIGGER_DOWN
            self.deadline_ms = now_ms + self.config.hold_ms
        return StepResult()

    def _on_trigger_up(self, now_ms: int) -> StepResult:
        emits: tuple[tuple[int, int], ...] = ()
        if self.trigger_emitted:
            self.trigger_emitted = False
            emits = ((self.config.trigger_code, 0),)

        if self.state == State.PENDING_HOLD:
            self.state = State.AWAITING_DOUBLE_TAP
            self.deadline_ms = now_ms + self.config.double_tap_ms
            return StepResult(emits=emits)

        self.deadline_ms = None
        if self.state == State.HOLDING:
            self.state = State.IDLE
            return StepResult(actions=(Action.STOP,), emits=emits)
        if self.state == State.DOUBLE_TAP_DOWN:
            self.state = State.LOCKED
            return StepResult(actions=(Action.START,), emits=emits)
        if self.state == State.LOCKED_TRIGGER_DOWN:
            self.state = State.IDLE
            return StepResult(actions=(Action.STOP,), emits=emits)
        if self.state == State.CHORDED:
            self.state = State.IDLE
            return StepResult(emits=emits)
        if self.state == State.LOCKED_CHORDED:
            self.state = State.LOCKED
            return StepResult(emits=emits)
        return StepResult(emits=emits)

    def _on_other_key_down(self, device_id: int, code: int) -> StepResult:
        if code == self.config.cancel_code and self.state in (
            State.HOLDING,
            State.LOCKED,
            State.LOCKED_TRIGGER_DOWN,
        ):
            self.swallowed_keys.add((device_id, code))
            self.deadline_ms = None
            if self.state == State.LOCKED:
                self.state = State.IDLE
            else:
                self.state = State.CHORDED
            return StepResult(actions=(Action.CANCEL,))

        self.swallowed_keys.discard((device_id, code))

        actions: tuple[Action, ...] = ()
        if self.state == State.HOLDING:
            self.state = State.CHORDED
            self.deadline_ms = None
            actions = (Action.CANCEL,)
        elif self.state in (State.PENDING_HOLD, State.DOUBLE_TAP_DOWN):
            self.state = State.CHORDED
            self.deadline_ms = None
        elif self.state == State.LOCKED_TRIGGER_DOWN:
            self.state = State.LOCKED_CHORDED
            self.deadline_ms = None
        elif self.state == State.AWAITING_DOUBLE_TAP:
            self.state = State.IDLE
            self.deadline_ms = None

        emits: list[tuple[int, int]] = []
        if self.trigger_devices and not self.trigger_emitted:
            self.trigger_emitted = True
            emits.append((self.config.trigger_code, 1))
        emits.append((code, 1))
        return StepResult(actions=actions, emits=tuple(emits))


class HexCommandRunner:
    def __init__(self, hex_bin: str = "hex", timeout_s: float = 5.0) -> None:
        self._hex_bin = hex_bin
        self._timeout_s = timeout_s
        self._queue: queue.Queue[Action | None] = queue.Queue()
        self._thread = threading.Thread(
            target=self._worker,
            name="hex-command-runner",
            daemon=True,
        )
        self._thread.start()

    def submit(self, action: Action) -> None:
        self._queue.put(action)

    def close(self, timeout_s: float = 2.0) -> None:
        self._queue.put(None)
        self._thread.join(timeout=timeout_s)

    def _worker(self) -> None:
        while True:
            action = self._queue.get()
            if action is None:
                return
            cmd = [self._hex_bin, "dictation", action.value]
            try:
                result = subprocess.run(
                    cmd,
                    timeout=self._timeout_s,
                    check=False,
                    capture_output=True,
                    text=True,
                )
            except (OSError, subprocess.SubprocessError) as exc:
                print(f"hex-hotkeyd: failed to run {cmd}: {exc}", file=sys.stderr, flush=True)
                continue
            if result.returncode != 0:
                detail = result.stderr.strip() or result.stdout.strip()
                msg = f"hex-hotkeyd: {cmd} exited with {result.returncode}"
                if detail:
                    msg = f"{msg}: {detail}"
                print(msg, file=sys.stderr, flush=True)


def _now_ms() -> int:
    return time.monotonic_ns() // 1_000_000


def run_evdev_loop(
    config: HotkeyConfig,
    runner: HexCommandRunner,
    rescan_ms: int = 2000,
    grab: bool = True,
) -> int:
    import evdev

    ev_key = evdev.ecodes.EV_KEY
    key_a = 30
    retry_delay_ms = min(100, rescan_ms)

    machine = HotkeyMachine(config)
    selector = selectors.DefaultSelector()
    devices: dict[str, tuple[int, Any]] = {}
    next_device_id = 1
    stop = False
    uinput: Any = None

    def handle_signal(_signum: int, _frame: Any) -> None:
        nonlocal stop
        stop = True

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    def emit_keys(emits: tuple[tuple[int, int], ...]) -> None:
        if uinput is None or not emits:
            return
        for code, value in emits:
            uinput.write(ev_key, code, value)
            uinput.syn()

    def dispatch(result: StepResult) -> None:
        emit_keys(result.emits)
        for action in result.actions:
            runner.submit(action)

    def is_keyboard(dev: Any) -> bool:
        if dev.name == VIRTUAL_DEVICE_NAME:
            return False
        caps = dev.capabilities(verbose=False)
        keys = set(caps.get(ev_key, ()))
        return config.trigger_code in keys and key_a in keys

    def rescan() -> bool:
        nonlocal next_device_id
        retry_soon = False
        for path in evdev.list_devices():
            if path in devices:
                continue
            try:
                dev = evdev.InputDevice(path)
            except OSError:
                continue
            try:
                if not is_keyboard(dev):
                    dev.close()
                    continue
                if uinput is not None:
                    if dev.active_keys():
                        dev.close()
                        retry_soon = True
                        continue
                    dev.grab()
                os.set_blocking(dev.fd, False)
                dev_id = next_device_id
                next_device_id += 1
                selector.register(dev.fd, selectors.EVENT_READ, (path, dev_id, dev))
                devices[path] = (dev_id, dev)
                mode = "grabbing" if uinput is not None else "watching"
                print(
                    f"hex-hotkeyd: {mode} {path} ({dev.name})",
                    file=sys.stderr,
                    flush=True,
                )
            except OSError:
                try:
                    dev.close()
                except OSError:
                    pass
        return retry_soon

    def remove_device(path: str, ts_ms: int) -> None:
        entry = devices.pop(path, None)
        if entry is None:
            return
        dev_id, dev = entry
        try:
            selector.unregister(dev.fd)
        except (KeyError, ValueError, OSError):
            pass
        if uinput is not None:
            try:
                dev.ungrab()
            except OSError:
                pass
        try:
            dev.close()
        except OSError:
            pass
        print(f"hex-hotkeyd: removed {path}", file=sys.stderr, flush=True)
        dispatch(machine.on_device_removed(dev_id, ts_ms))

    try:
        if grab:
            key_codes = sorted(
                c
                for c in evdev.ecodes.KEY
                if isinstance(c, int) and 0 < c < evdev.ecodes.KEY_MAX
            )
            try:
                uinput = evdev.UInput({ev_key: key_codes}, name=VIRTUAL_DEVICE_NAME)
            except OSError as exc:
                print(
                    f"hex-hotkeyd: uinput unavailable ({exc}); falling back to passive mode",
                    file=sys.stderr,
                    flush=True,
                )

        retry_soon = rescan()
        next_rescan_ms = _now_ms() + (retry_delay_ms if retry_soon else rescan_ms)

        while not stop:
            now = _now_ms()
            dispatch(machine.on_timeout(now))

            if now >= next_rescan_ms:
                retry_soon = rescan()
                next_rescan_ms = now + (retry_delay_ms if retry_soon else rescan_ms)

            next_wakeup_ms = next_rescan_ms
            if machine.deadline_ms is not None and machine.deadline_ms < next_wakeup_ms:
                next_wakeup_ms = machine.deadline_ms

            timeout_s = max(0.0, (next_wakeup_ms - _now_ms()) / 1000.0)
            try:
                ready = selector.select(timeout=timeout_s)
            except InterruptedError:
                continue

            now = _now_ms()
            for key, _ in ready:
                path, dev_id, dev = key.data
                try:
                    for event in dev.read():
                        if event.type == ev_key:
                            dispatch(machine.on_key(dev_id, event.code, event.value, now))
                except BlockingIOError:
                    continue
                except OSError:
                    remove_device(path, now)
    finally:
        for _, dev in list(devices.values()):
            try:
                selector.unregister(dev.fd)
            except (KeyError, ValueError, OSError):
                pass
            if uinput is not None:
                try:
                    dev.ungrab()
                except OSError:
                    pass
            try:
                dev.close()
            except OSError:
                pass
        devices.clear()
        selector.close()
        if uinput is not None:
            try:
                uinput.close()
            except OSError:
                pass
        runner.close()

    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Hex evdev hold and double-tap hotkey daemon")
    parser.add_argument("--hex-bin", default="hex")
    parser.add_argument("--hold-ms", type=int, default=250)
    parser.add_argument("--double-tap-ms", type=int, default=350)
    parser.add_argument("--trigger-code", type=int, default=125)
    parser.add_argument("--cancel-code", type=int, default=1)
    parser.add_argument("--rescan-ms", type=int, default=2000)
    parser.add_argument("--no-grab", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    config = HotkeyConfig(
        hold_ms=args.hold_ms,
        double_tap_ms=args.double_tap_ms,
        trigger_code=args.trigger_code,
        cancel_code=args.cancel_code,
    )
    runner = HexCommandRunner(hex_bin=args.hex_bin)
    return run_evdev_loop(
        config,
        runner,
        rescan_ms=args.rescan_ms,
        grab=not args.no_grab,
    )


if __name__ == "__main__":
    raise SystemExit(main())
